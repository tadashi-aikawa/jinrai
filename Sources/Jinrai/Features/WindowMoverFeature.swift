import AppKit
import Carbon.HIToolbox
import JinraiCore
import JinraiPlatform

/// ウィンドウ移動(元 window_mover.lua)。
/// ホットキーによる直接移動・サイクル・最大空き領域・エリア選択画面。
@MainActor
final class WindowMoverFeature {
    private let config: WindowMoverConfig
    private var hotkeys: [Hotkey] = []
    private var cycleState = CycleState()
    private let eventTap = EventTap()

    // エリア選択画面の状態
    private var chooserOverlays: [OverlayWindow] = []
    private var chooserInput = ""
    private var chooserLabelLayers: [String: [CATextLayer]] = [:]  // キー → ラベル
    private var chooserCandidates: [(key: String, areaName: String, frame: CGRect)] = []
    private(set) var isChooserVisible = false

    /// エリア選択画面から Window Hints へ遷移するコールバック(相互結線)
    var onOpenWindowHints: (() -> Void)?

    init(config: WindowMoverConfig) {
        self.config = config

        for (command, binding) in config.commandHotkeys {
            let hotkey = Hotkey(modifiers: binding.modifiers, key: binding.key) {
                [weak self] in
                self?.run(command: command)
            }
            if let hotkey {
                hotkeys.append(hotkey)
            } else {
                NSLog("[jinrai.window_mover] ホットキーの登録に失敗: %@", binding.key)
            }
        }

        eventTap.onKeyDown = { [weak self] event in
            self?.handleChooserKey(event) ?? false
        }
        eventTap.onLeftMouseDown = { [weak self] _ in
            self?.closeChooser()
            return false
        }
    }

    // MARK: - コマンド実行

    func run(command: String) {
        switch command {
        case "moveToNextDisplay":
            moveToNextDisplay()
        case "moveToActiveDisplayFreeArea":
            moveToFreeArea()
        case "moveToSelectedArea":
            openAreaChooser()
        case "moveToSelectedAreaInJinraiMode":
            openAreaChooser()  // JinraiMode はフェーズ2
        case "minimizeWindow":
            WindowEnumerator.focusedWindow()?.minimize()
        case "maximizeWindow":
            withFocusedWindow { win, screen in
                self.apply(frame: ScreenUtil.visibleFrame(of: screen), to: win)
            }
        default:
            if let cycle = CycleCommand(rawValue: command) {
                runCycle(cycle)
            } else if AreaSpec.kind(of: command) != nil {
                withFocusedWindow { win, screen in
                    let screenFrame = ScreenUtil.visibleFrame(of: screen)
                    if let target = AreaSpec.frame(for: command, screenFrame: screenFrame) {
                        self.apply(frame: target, to: win)
                    }
                }
            }
        }
    }

    private func withFocusedWindow(_ body: (AXWindow, NSScreen) -> Void) {
        guard let win = WindowEnumerator.focusedWindow(),
            let frame = win.frame,
            let screen = ScreenUtil.screenContaining(frame)
        else { return }
        body(win, screen)
    }

    private func apply(frame: CGRect, to window: AXWindow) {
        window.setFrame(frame)
        if config.cursorAfterMove {
            Mouse.moveToCenter(of: window.frame ?? frame)
        }
    }

    private func moveToNextDisplay() {
        withFocusedWindow { win, screen in
            guard let next = ScreenUtil.nextScreen(after: screen), next != screen else {
                return
            }
            self.apply(frame: ScreenUtil.visibleFrame(of: next), to: win)
        }
    }

    private func runCycle(_ command: CycleCommand) {
        withFocusedWindow { win, screen in
            guard let current = win.frame else { return }
            let ratios = (command.isHorizontal
                ? config.horizontalRatios : config.verticalRatios
            ).map { CGFloat($0) }
            guard !ratios.isEmpty else { return }
            let screenFrame = ScreenUtil.visibleFrame(of: screen)
            let index = cycleState.nextIndex(
                command: command, currentFrame: current, ratioCount: ratios.count)
            let target = CycleState.targetFrame(
                command: command, ratio: ratios[index], screenFrame: screenFrame)
            self.apply(frame: target, to: win)
            // setFrame 後の実 frame を記録(アプリ側の丸め・最小サイズ対応)
            cycleState.recordApplied(
                command: command, index: index, actualFrame: win.frame ?? target)
        }
    }

    // MARK: - freeArea

    /// アクティブディスプレイの最大空き領域を計算して移動
    private func moveToFreeArea() {
        withFocusedWindow { win, screen in
            let screenFrame = ScreenUtil.visibleFrame(of: screen)
            if let free = self.computeFreeArea(
                screen: screen, screenFrame: screenFrame, excluding: win.windowID)
            {
                self.apply(frame: free, to: win)
            }
        }
    }

    /// 前面ウィンドウに一定以上隠れた背面ウィンドウを障害物から除外して空き領域を探す
    private func computeFreeArea(
        screen: NSScreen, screenFrame: CGRect, excluding activeWindowID: CGWindowID?
    ) -> CGRect? {
        let ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        let standard = WindowEnumerator.standardWindows(from: ordered)

        var frontFrames: [CGRect] = []
        var occupied: [CGRect] = []
        for win in standard {
            guard let intersection = Geometry.intersect(win.frame, screenFrame) else {
                continue
            }
            let isActive = win.id == activeWindowID
            let hidden = Geometry.isHiddenByFrontFrames(
                intersection, frontFrames: frontFrames,
                threshold: CGFloat(config.hiddenWindowThreshold))
            // アクティブウィンドウ自身と隠れた背面ウィンドウは障害物にしない
            if !isActive && !hidden {
                occupied.append(intersection)
            }
            frontFrames.append(intersection)
        }

        let activeFrame = ordered.first { $0.id == activeWindowID }?.frame
        return FreeArea.bestFreeFrame(
            screenFrame: screenFrame, occupiedFrames: occupied, currentFrame: activeFrame)
    }

    // MARK: - エリア選択画面

    func openAreaChooser() {
        guard !isChooserVisible else { return }
        chooserCandidates = []
        chooserLabelLayers = [:]
        chooserInput = ""

        var hasAnyMapping = false
        for screen in NSScreen.screens {
            let uuid = ScreenUtil.uuid(of: screen)
            let mapping =
                uuid.flatMap { config.selectedArea.screens[$0] }
                ?? config.selectedArea.defaultScreen
            let screenFrame = ScreenUtil.visibleFrame(of: screen)
            let overlay = OverlayWindow(frame: screenFrame)
            guard let root = overlay.rootLayer else { continue }

            if let mapping, !mapping.isEmpty {
                hasAnyMapping = true
                drawAreas(
                    mapping: mapping, screen: screen, screenFrame: screenFrame, root: root)
            } else {
                drawScreenInfo(uuid: uuid, screenFrame: screenFrame, root: root)
            }
            overlay.orderFrontRegardless()
            chooserOverlays.append(overlay)
        }

        guard eventTap.start() else {
            NSLog("[jinrai.window_mover] キー捕捉を開始できません")
            closeChooser()
            return
        }
        isChooserVisible = true
        if !hasAnyMapping {
            NSLog("[jinrai.window_mover] selectedArea.screens が未設定です(画面に UUID を表示中)")
        }
    }

    func closeChooser() {
        guard isChooserVisible || !chooserOverlays.isEmpty else { return }
        isChooserVisible = false
        eventTap.stop()
        for overlay in chooserOverlays {
            overlay.orderOut(nil)
        }
        chooserOverlays = []
        chooserCandidates = []
        chooserLabelLayers = [:]
        chooserInput = ""
    }

    private func drawAreas(
        mapping: [String: String], screen: NSScreen, screenFrame: CGRect, root: CALayer
    ) {
        if config.selectedArea.showHints {
            root.backgroundColor = CGColor(gray: 0, alpha: 0.25)
        }
        for (areaName, key) in mapping.sorted(by: { $0.value < $1.value }) {
            let areaFrame: CGRect?
            if AreaSpec.kind(of: areaName) == .freeArea {
                areaFrame = computeFreeArea(
                    screen: screen, screenFrame: screenFrame,
                    excluding: WindowEnumerator.focusedWindow()?.windowID)
            } else {
                areaFrame = AreaSpec.frame(for: areaName, screenFrame: screenFrame)
            }
            guard let areaFrame else { continue }
            chooserCandidates.append((key: key, areaName: areaName, frame: areaFrame))

            guard config.selectedArea.showHints else { continue }
            let kindName = AreaSpec.kind(of: areaName).map(styleKey) ?? "free"
            let color = config.selectedArea.styleColors[kindName]
                ?? ConfigColor(red: 0.58, green: 0.64, blue: 0.70, alpha: 0.95)

            // overlay ローカル座標(bottom-left)へ
            let local = CGRect(
                x: areaFrame.minX - screenFrame.minX,
                y: screenFrame.height - (areaFrame.minY - screenFrame.minY)
                    - areaFrame.height,
                width: areaFrame.width, height: areaFrame.height)

            let border = CAShapeLayer()
            border.path = CGPath(rect: local.insetBy(dx: 2, dy: 2), transform: nil)
            border.fillColor = nil
            border.lineWidth = 2
            border.strokeColor = CGColor(
                red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            root.addSublayer(border)

            let label = CATextLayer()
            label.string = key
            label.font = NSFont.boldSystemFont(ofSize: 28)
            label.fontSize = 28
            label.foregroundColor = CGColor(
                red: color.red, green: color.green, blue: color.blue, alpha: 1)
            label.backgroundColor = CGColor(
                red: 0.03, green: 0.03, blue: 0.04, alpha: 0.88)
            label.cornerRadius = 6
            label.alignmentMode = .center
            label.contentsScale = screen.backingScaleFactor
            let size = label.preferredFrameSize()
            label.frame = CGRect(
                x: local.midX - (size.width + 20) / 2,
                y: local.midY - (size.height + 10) / 2,
                width: size.width + 20, height: size.height + 10)
            root.addSublayer(label)
            chooserLabelLayers[key, default: []].append(label)
        }
    }

    private func drawScreenInfo(uuid: String?, screenFrame: CGRect, root: CALayer) {
        let label = CATextLayer()
        label.string = """
            Jinrai Window Mover: このディスプレイのエリアが未設定です
            selectedArea.screens["\(uuid ?? "不明")"] にエリアとキーを設定してください
            """
        label.font = NSFont.systemFont(ofSize: 18)
        label.fontSize = 18
        label.foregroundColor = CGColor(gray: 1, alpha: 0.95)
        label.backgroundColor = CGColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.88)
        label.cornerRadius = 8
        label.alignmentMode = .center
        label.isWrapped = true
        label.contentsScale = 2
        label.frame = CGRect(
            x: screenFrame.width / 2 - 360, y: screenFrame.height / 2 - 40,
            width: 720, height: 80)
        root.addSublayer(label)
    }

    private func styleKey(_ kind: AreaSpec.Kind) -> String {
        switch kind {
        case .freeArea: return "free"
        case .fixedSizeCenter: return "fixedSizeCenter"
        default: return kind.rawValue
        }
    }

    // MARK: - エリア選択のキー入力

    private func handleChooserKey(_ event: EventTap.KeyEvent) -> Bool {
        guard isChooserVisible else { return false }

        if event.keyCode == UInt32(kVK_Escape) {
            closeChooser()
            return true
        }
        if event.keyCode == UInt32(kVK_Delete) {
            chooserInput = String(chooserInput.dropLast())
            updateChooserHighlight()
            return true
        }

        // "space" 等の特殊キーは Window Hints への遷移キーとしてのみ扱う
        if event.keyCode == UInt32(kVK_Space),
            config.selectedArea.windowHintsKey == "SPACE"
        {
            closeChooser()
            onOpenWindowHints?()
            return true
        }

        guard let character = event.character?.uppercased(), !character.isEmpty,
            character.rangeOfCharacter(from: .alphanumerics) != nil
                || character.rangeOfCharacter(from: .punctuationCharacters) != nil
        else { return true }

        let input = chooserInput + character

        // Window Hints への遷移
        if let hintsKey = config.selectedArea.windowHintsKey, input == hintsKey {
            closeChooser()
            onOpenWindowHints?()
            return true
        }
        // アクション
        if let action = config.selectedArea.actions.first(where: { $0.value == input }) {
            closeChooser()
            runAction(action.key)
            return true
        }
        // エリア
        if let candidate = chooserCandidates.first(where: { $0.key == input }) {
            let frame = candidate.frame
            closeChooser()
            if let win = WindowEnumerator.focusedWindow() {
                apply(frame: frame, to: win)
            }
            return true
        }
        // 接頭辞一致があれば入力継続
        let allKeys =
            chooserCandidates.map(\.key) + config.selectedArea.actions.values
            + (config.selectedArea.windowHintsKey.map { [$0] } ?? [])
        if allKeys.contains(where: { $0.hasPrefix(input) }) {
            chooserInput = input
            updateChooserHighlight()
        } else {
            chooserInput = ""
            updateChooserHighlight()
        }
        return true
    }

    private func updateChooserHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (key, labels) in chooserLabelLayers {
            let matches = chooserInput.isEmpty || key.hasPrefix(chooserInput)
            for label in labels {
                label.opacity = matches ? 1.0 : 0.25
            }
        }
        CATransaction.commit()
    }

    private func runAction(_ name: String) {
        guard let win = WindowEnumerator.focusedWindow() else { return }
        switch name {
        case "closeWindow":
            win.close()
        case "minimizeWindow":
            win.minimize()
        case "maximizeWindow":
            if let frame = win.frame, let screen = ScreenUtil.screenContaining(frame) {
                apply(frame: ScreenUtil.visibleFrame(of: screen), to: win)
            }
        case "quitApplication":
            NSRunningApplication(processIdentifier: win.pid)?.terminate()
        case "detachChromeTabToNewWindow":
            detachChromeTab(win)
        default:
            break
        }
    }

    /// Chrome のメニュー「タブを新しいウィンドウに移動」を AX メニュー操作で実行
    private func detachChromeTab(_ window: AXWindow) {
        let menuTitles = [
            ["Tab", "Move Tab to New Window"],
            ["タブ", "タブを新しいウィンドウに移動"],
        ]
        let app = AXUIElementCreateApplication(window.pid)
        for path in menuTitles {
            if selectMenuItem(app: app, path: path) { return }
        }
        NSLog("[jinrai.window_mover] Chrome のタブ分離メニューが見つかりません")
    }

    private func selectMenuItem(app: AXUIElement, path: [String]) -> Bool {
        var current: AXUIElement = app
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(current, kAXMenuBarAttribute as CFString, &value)
                == .success, let menuBar = value
        else { return false }
        current = menuBar as! AXUIElement

        for (depth, title) in path.enumerated() {
            guard let children = menuChildren(of: current) else { return false }
            var found: AXUIElement?
            for child in children {
                var titleValue: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)
                if titleValue as? String == title {
                    found = child
                    break
                }
                // メニュー項目は AXMenu を1段挟むことがある
                if let grandchildren = menuChildren(of: child) {
                    for grandchild in grandchildren {
                        var gcTitle: CFTypeRef?
                        AXUIElementCopyAttributeValue(
                            grandchild, kAXTitleAttribute as CFString, &gcTitle)
                        if gcTitle as? String == title {
                            found = grandchild
                            break
                        }
                    }
                }
                if found != nil { break }
            }
            guard let found else { return false }
            if depth == path.count - 1 {
                return AXUIElementPerformAction(found, kAXPressAction as CFString) == .success
            }
            current = found
        }
        return false
    }

    private func menuChildren(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
                == .success
        else { return nil }
        return value as? [AXUIElement]
    }

    func teardown() {
        closeChooser()
        for hotkey in hotkeys {
            hotkey.unregister()
        }
        hotkeys = []
    }
}
