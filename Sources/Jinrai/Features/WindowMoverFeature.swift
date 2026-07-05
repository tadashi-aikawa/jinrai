import AppKit
import Carbon.HIToolbox
import JinraiCore
import JinraiPlatform

/// ウィンドウ移動(元 window_mover.lua)。
/// ホットキーによる直接移動・サイクル・最大空き領域と、
/// Area Hints(エリア選択画面)の表示・キー処理を担う。
@MainActor
final class WindowMoverFeature {
    private let config: WindowMoverConfig
    private let areaHints: AreaHintsConfig
    private var hotkeys: [Hotkey] = []
    private var cycleState = CycleState()
    private let eventTap = EventTap()

    // エリア選択画面の状態
    private var chooserOverlays: [OverlayWindow] = []
    private var chooserInput = ""
    private var chooserCandidates: [(key: String, areaName: String, frame: CGRect)] = []
    private(set) var isChooserVisible = false

    /// ラベルボックス1個分のレイヤー参照(入力に応じた再スタイル用)
    private struct AreaLabelRefs {
        let key: String
        let styleKind: String
        let detailText: String?
        let container: CALayer
        let border: CAShapeLayer
        let keyLayer: CATextLayer
        let iconFills: [CALayer]
        let iconOutline: CAShapeLayer
        let detailLayer: CATextLayer?
    }
    private var areaLabels: [AreaLabelRefs] = []

    /// エリア選択画面から Window Hints へ遷移するコールバック(相互結線)
    var onOpenWindowHints: (() -> Void)?
    /// JinraiMode: 開始(mode 演出の起動)/ 適用後(combo+1 して Hints へ)/ キャンセル
    var onJinraiModeStart: (() -> Void)?
    var onJinraiModeApply: (() -> Void)?
    var onJinraiModeCancel: (() -> Void)?
    /// エリア選択画面が JinraiMode 文脈で開かれているか
    private var chooserJinraiMode = false
    /// エリア選択の対象ウィンドウ(直前に選択されたウィンドウ。
    /// focusedWindow は frontmostApplication ベースで focus 直後は古いため明示する)
    private var chooserTarget: (windowID: UInt32, pid: pid_t)?

    init(config: WindowMoverConfig, areaHints: AreaHintsConfig) {
        self.config = config
        self.areaHints = areaHints

        for (command, binding) in config.commandHotkeys {
            let hotkey = Hotkey(modifiers: binding.modifiers, key: binding.key) {
                [weak self] in
                self?.run(command: command)
            }
            if let hotkey {
                hotkeys.append(hotkey)
            } else {
                NSLog("[jinrai.windowMover] ホットキーの登録に失敗: %@", binding.key)
            }
        }

        // Area Hints のホットキー(通常起動 / JinraiMode 起動)
        if let binding = areaHints.hotkey {
            registerAreaHintsHotkey(binding) { [weak self] in
                self?.openAreaChooser()
            }
        }
        if let binding = areaHints.jinraiModeHotkey {
            registerAreaHintsHotkey(binding) { [weak self] in
                self?.onJinraiModeStart?()
                self?.openAreaChooser(jinraiMode: true)
            }
        }

        eventTap.onKeyDown = { [weak self] event in
            self?.handleChooserKey(event) ?? false
        }
        eventTap.onLeftMouseDown = { [weak self] _ in
            guard let self else { return false }
            let wasJinrai = self.chooserJinraiMode
            self.closeChooser()
            if wasJinrai {
                self.onJinraiModeCancel?()
            }
            return false
        }
    }

    private func registerAreaHintsHotkey(
        _ binding: AreaHintsConfig.HotkeyBinding, handler: @escaping () -> Void
    ) {
        if let hotkey = Hotkey(modifiers: binding.modifiers, key: binding.key, handler: handler)
        {
            hotkeys.append(hotkey)
        } else {
            NSLog("[jinrai.areaHints] ホットキーの登録に失敗: %@", binding.key)
        }
    }

    // MARK: - コマンド実行

    func run(command: String) {
        switch command {
        case "moveToNextDisplay":
            moveToNextDisplay()
        case "moveToActiveDisplayFreeArea":
            moveToFreeArea()
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

    /// 設定に応じて隠れた背面ウィンドウを障害物から除外し、空き領域を探す
    private func computeFreeArea(
        screen: NSScreen, screenFrame: CGRect, excluding activeWindowID: CGWindowID?
    ) -> CGRect? {
        let ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        let standard = WindowEnumerator.standardWindows(from: ordered)

        let occupied = FreeArea.occupiedFrames(
            screenFrame: screenFrame,
            standardWindows: standard,
            activeWindowID: activeWindowID,
            hiddenWindowThreshold: CGFloat(config.hiddenWindowThreshold),
            excludeHiddenWindows: config.excludeHiddenWindows)

        let activeFrame = ordered.first { $0.id == activeWindowID }?.frame
        return FreeArea.bestFreeFrame(
            screenFrame: screenFrame, occupiedFrames: occupied, currentFrame: activeFrame)
    }

    // MARK: - エリア選択画面

    /// fadeSpotlight: Window Hints からの受け渡しでは false にして瞬間表示し、
    /// 暗幕の連続性を保つ(クロスフェードによる画面全体のフラッシュを防ぐ)
    func openAreaChooser(
        jinraiMode: Bool = false, target: (windowID: UInt32, pid: pid_t)? = nil,
        fadeSpotlight: Bool = true
    ) {
        guard !isChooserVisible else { return }
        chooserJinraiMode = jinraiMode
        chooserTarget = target
        chooserCandidates = []
        areaLabels = []
        chooserInput = ""

        let focusedWindowFrame = chooserTargetWindow()?.frame
        var hasAnyMapping = false
        let displayCount = NSScreen.screens.count
        for screen in NSScreen.screens {
            let uuid = ScreenUtil.uuid(of: screen)
            let mapping =
                uuid.flatMap { areaHints.screens[$0]?.resolve(displayCount: displayCount) }
                ?? areaHints.defaultScreen?.resolve(displayCount: displayCount)
            let screenFrame = ScreenUtil.visibleFrame(of: screen)
            let overlay = OverlayWindow(frame: screenFrame, level: .hints)
            guard let root = overlay.rootLayer else { continue }

            if let focusedWindowFrame {
                root.addSublayer(
                    ActiveWindowOverlayLayers.spotlightLayer(
                        windowFrame: focusedWindowFrame,
                        screenFrame: screenFrame,
                        overlayHeight: screenFrame.height,
                        alpha: CGFloat(areaHints.activeWindowSpotlightAlpha),
                        fadeIn: fadeSpotlight))
                if screenFrame.intersects(focusedWindowFrame) {
                    root.addSublayer(
                        ActiveWindowOverlayLayers.highlightLayer(
                            windowFrame: focusedWindowFrame,
                            screenFrame: screenFrame,
                            overlayHeight: screenFrame.height,
                            borderColor: areaHints.activeWindowHighlightColor,
                            borderWidth: CGFloat(
                                areaHints.activeWindowHighlightWidth),
                            cornerRadius: CGFloat(
                                areaHints.activeWindowHighlightCornerRadius)))
                }
            }

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
            NSLog("[jinrai.windowMover] キー捕捉を開始できません")
            closeChooser()
            return
        }
        isChooserVisible = true
        if !hasAnyMapping {
            NSLog("[jinrai.areaHints] screens が未設定です(画面に UUID を表示中)")
        }
    }

    /// エリア選択の対象ウィンドウ(target 指定時は AX で最新解決、なければ focusedWindow)
    private func chooserTargetWindow() -> AXWindow? {
        if let chooserTarget,
            let ax = AXWindow.resolve(
                windowID: chooserTarget.windowID, pid: chooserTarget.pid)
        {
            return ax
        }
        return WindowEnumerator.focusedWindow()
    }

    func closeChooser() {
        guard isChooserVisible || !chooserOverlays.isEmpty else { return }
        isChooserVisible = false
        chooserJinraiMode = false
        chooserTarget = nil
        eventTap.stop()
        for overlay in chooserOverlays {
            overlay.orderOut(nil)
        }
        chooserOverlays = []
        chooserCandidates = []
        areaLabels = []
        chooserInput = ""
    }

    /// エリア選択画面の描画。元実装同様、エリア矩形は描かず
    /// ラベルボックス(bg + 枠線 + キー + ミニアイコン + detail)だけを配置する
    private func drawAreas(
        mapping: [String: String], screen: NSScreen, screenFrame: CGRect, root: CALayer
    ) {
        var labelCandidates: [AreaLabelLayout.Candidate] = []
        var candidateAreaFrames: [CGRect] = []

        for (areaName, key) in mapping.sorted(by: { $0.value < $1.value }) {
            let isFreeArea = AreaSpec.kind(of: areaName) == .freeArea
            let areaFrame: CGRect?
            if isFreeArea {
                areaFrame = computeFreeArea(
                    screen: screen, screenFrame: screenFrame,
                    excluding: chooserTargetWindow()?.windowID)
            } else {
                areaFrame = AreaSpec.frame(for: areaName, screenFrame: screenFrame)
            }
            guard let areaFrame else { continue }
            chooserCandidates.append((key: key, areaName: areaName, frame: areaFrame))

            guard areaHints.showLabels else { continue }
            let detail = AreaLabelLayout.detailLabel(for: areaName)
            let keyWidth = AreaLabelLayout.keyBoxWidth(
                measuredTextWidth: measureText(
                    key, fontSize: AreaLabelLayout.keyFontSize).width)
            labelCandidates.append(
                AreaLabelLayout.Candidate(
                    key: key,
                    areaName: areaName,
                    // ラベル配置は freeArea なら画面全体基準(右上固定)
                    areaFrame: isFreeArea ? screenFrame : areaFrame,
                    labelSize: AreaLabelLayout.labelSize(
                        keyBoxWidth: keyWidth, detailLabel: detail),
                    fixedTopRight: isFreeArea
                ))
            candidateAreaFrames.append(areaFrame)
        }

        guard areaHints.showLabels, !labelCandidates.isEmpty else { return }

        let labelFrames = AreaLabelLayout.resolveLabelFrames(
            candidates: labelCandidates, screenFrame: screenFrame)

        for (index, candidate) in labelCandidates.enumerated() {
            let globalFrame = labelFrames[index]
            let local = CGRect(
                x: globalFrame.minX - screenFrame.minX,
                y: screenFrame.height - (globalFrame.minY - screenFrame.minY)
                    - globalFrame.height,
                width: globalFrame.width, height: globalFrame.height)
            let refs = buildAreaLabel(
                candidate: candidate, scale: screen.backingScaleFactor)
            refs.container.frame = local
            root.addSublayer(refs.container)
            areaLabels.append(refs)
        }
        applyChooserStyles()
    }

    private func measureText(_ text: String, fontSize: CGFloat) -> CGSize {
        NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: fontSize)]
        ).size()
    }

    /// ラベルボックス1個を組み立てる(色は applyChooserStyles で設定)
    private func buildAreaLabel(
        candidate: AreaLabelLayout.Candidate, scale: CGFloat
    ) -> AreaLabelRefs {
        let size = candidate.labelSize
        let height = size.height
        let detail = AreaLabelLayout.detailLabel(for: candidate.areaName)
        let keyWidth = size.width - 9 - 5 - AreaLabelLayout.iconWidth - 10
        let styleKind = AreaSpec.kind(of: candidate.areaName).map(styleKey) ?? "free"

        // 元実装は top-left 座標で要素を置くため、AppKit レイヤー座標へ反転するヘルパー
        func flip(_ rect: CGRect) -> CGRect {
            CGRect(
                x: rect.minX, y: height - rect.maxY,
                width: rect.width, height: rect.height)
        }

        let container = CALayer()
        container.bounds = CGRect(origin: .zero, size: size)
        container.cornerRadius = 6

        let border = CAShapeLayer()
        border.path = CGPath(
            roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1),
            cornerWidth: 6, cornerHeight: 6, transform: nil)
        border.fillColor = nil
        border.lineWidth = 2
        container.addSublayer(border)

        // キー文字(size 26、x=9。top-left 基準で y=9, h=43)
        let keyLayer = CATextLayer()
        keyLayer.string = candidate.key
        keyLayer.font = NSFont.systemFont(ofSize: AreaLabelLayout.keyFontSize)
        keyLayer.fontSize = AreaLabelLayout.keyFontSize
        keyLayer.alignmentMode = .center
        keyLayer.contentsScale = scale
        keyLayer.frame = flip(CGRect(x: 9, y: 9, width: keyWidth, height: 43))
        container.addSublayer(keyLayer)

        // ミニアイコン(38x30、外枠 + 該当スロットの塗り)
        let iconX = 9 + keyWidth + 5
        let outlineRect = CGRect(
            x: iconX, y: 11,
            width: AreaLabelLayout.iconWidth, height: AreaLabelLayout.iconHeight)
        let iconOutline = CAShapeLayer()
        iconOutline.path = CGPath(
            roundedRect: flip(outlineRect).insetBy(dx: 1, dy: 1),
            cornerWidth: 3, cornerHeight: 3, transform: nil)
        iconOutline.fillColor = nil
        iconOutline.lineWidth = 2
        container.addSublayer(iconOutline)

        var iconFills: [CALayer] = []
        for fillRect in iconFillRects(
            spec: AreaLabelLayout.iconSpec(for: candidate.areaName),
            outline: outlineRect)
        {
            let fill = CALayer()
            fill.frame = flip(fillRect)
            fill.cornerRadius = 1
            container.addSublayer(fill)
            iconFills.append(fill)
        }

        // detail テキスト(size 13、下部中央)
        var detailLayer: CATextLayer?
        if let detail {
            let layer = CATextLayer()
            layer.string = detail
            layer.font = NSFont.systemFont(ofSize: AreaLabelLayout.detailFontSize)
            layer.fontSize = AreaLabelLayout.detailFontSize
            layer.alignmentMode = .center
            layer.contentsScale = scale
            let width = AreaLabelLayout.detailTextWidth(detail)
            layer.frame = flip(
                CGRect(x: (size.width - width) / 2, y: 47, width: width, height: 16))
            container.addSublayer(layer)
            detailLayer = layer
        }

        return AreaLabelRefs(
            key: candidate.key,
            styleKind: styleKind,
            detailText: detail,
            container: container,
            border: border,
            keyLayer: keyLayer,
            iconFills: iconFills,
            iconOutline: iconOutline,
            detailLayer: detailLayer
        )
    }

    /// ミニアイコンの塗り矩形(top-left 座標、外枠から 5px インセット、スロット間 gap 2)
    private func iconFillRects(
        spec: AreaLabelLayout.IconSpec?, outline: CGRect
    ) -> [CGRect] {
        let inner = outline.insetBy(dx: 5, dy: 5)
        let gap: CGFloat = 2
        let dot: CGFloat = 5
        switch spec {
        case .slot(let slots, let index, let span, let vertical):
            if vertical {
                let slotHeight = (inner.height - gap * CGFloat(slots - 1)) / CGFloat(slots)
                let y = inner.minY + CGFloat(index - 1) * (slotHeight + gap)
                let bandHeight = slotHeight * CGFloat(span) + gap * CGFloat(span - 1)
                return [CGRect(x: inner.minX, y: y, width: inner.width, height: bandHeight)]
            }
            let slotWidth = (inner.width - gap * CGFloat(slots - 1)) / CGFloat(slots)
            let x = inner.minX + CGFloat(index - 1) * (slotWidth + gap)
            let bandWidth = slotWidth * CGFloat(span) + gap * CGFloat(span - 1)
            return [CGRect(x: x, y: inner.minY, width: bandWidth, height: inner.height)]
        case .grid(let cols, let rows, let col, let row):
            let cellWidth = (inner.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let cellHeight = (inner.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            return [
                CGRect(
                    x: inner.minX + CGFloat(col - 1) * (cellWidth + gap),
                    y: inner.minY + CGFloat(row - 1) * (cellHeight + gap),
                    width: cellWidth, height: cellHeight)
            ]
        case .centeredRatio(let ratio):
            let width = inner.width * ratio
            let height = inner.height * ratio
            return [
                CGRect(
                    x: inner.midX - width / 2, y: inner.midY - height / 2,
                    width: width, height: height)
            ]
        case .free, .fixedSizeCenter:
            var rects = [
                CGRect(x: inner.minX, y: inner.minY, width: dot, height: dot),
                CGRect(x: inner.maxX - dot, y: inner.minY, width: dot, height: dot),
                CGRect(x: inner.minX, y: inner.maxY - dot, width: dot, height: dot),
                CGRect(x: inner.maxX - dot, y: inner.maxY - dot, width: dot, height: dot),
            ]
            if case .fixedSizeCenter = spec {
                rects.append(
                    CGRect(
                        x: inner.midX - dot / 2, y: inner.midY - dot / 2,
                        width: dot, height: dot))
            }
            return rects
        case nil:
            return []
        }
    }

    private func drawScreenInfo(uuid: String?, screenFrame: CGRect, root: CALayer) {
        let label = CATextLayer()
        label.string = """
            Jinrai Area Hints: このディスプレイのエリアが未設定です
            areaHints.screens["\(uuid ?? "不明")"] にエリアとキーを設定してください
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

    /// キー名の正規化("return" "space" 等の特殊キー対応、JinraiMode トリガ比較用)
    private func chooserKeyName(of event: EventTap.KeyEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space: return "space"
        case kVK_Return: return "return"
        case kVK_Tab: return "tab"
        default: return event.character?.lowercased()
        }
    }

    private func handleChooserKey(_ event: EventTap.KeyEvent) -> Bool {
        guard isChooserVisible else { return false }

        if event.keyCode == UInt32(kVK_Escape) {
            let wasJinrai = chooserJinraiMode
            closeChooser()
            if wasJinrai {
                onJinraiModeCancel?()
            }
            return true
        }
        if event.keyCode == UInt32(kVK_Delete) {
            chooserInput = String(chooserInput.dropLast())
            updateChooserHighlight()
            return true
        }

        // JinraiMode 開始(triggers.areaHints.key。選択画面は開いたまま)
        if let name = chooserKeyName(of: event),
            ConfigKeyDescriptor.matches(
                configuredKeyName: areaHints.jinraiModeKey,
                inputKeyName: name)
        {
            if !chooserJinraiMode {
                chooserJinraiMode = true
                onJinraiModeStart?()
            }
            return true
        }

        // 特殊キー名を含む Window Hints への遷移
        if let name = chooserKeyName(of: event),
            ConfigKeyDescriptor.matches(
                configuredKeyName: areaHints.windowHintsKey,
                inputKeyName: name)
        {
            transitionToWindowHints()
            return true
        }

        guard let character = event.character?.uppercased(), !character.isEmpty,
            character.rangeOfCharacter(from: .alphanumerics) != nil
                || character.rangeOfCharacter(from: .punctuationCharacters) != nil
        else { return true }

        let input = chooserInput + character

        // Window Hints への遷移
        if let hintsKey = areaHints.windowHintsKey, input == hintsKey {
            transitionToWindowHints()
            return true
        }
        // アクション(対象は closeChooser でクリアされる前に解決しておく)
        if let action = areaHints.actions.first(where: { $0.value == input }) {
            let wasJinrai = chooserJinraiMode
            let win = chooserTargetWindow()
            closeChooser()
            runAction(action.key, window: win, jinraiMode: wasJinrai)
            return true
        }
        // エリア
        if let candidate = chooserCandidates.first(where: { $0.key == input }) {
            let frame = candidate.frame
            let wasJinrai = chooserJinraiMode
            let win = chooserTargetWindow()
            closeChooser()
            if let win {
                apply(frame: frame, to: win)
            }
            if wasJinrai {
                onJinraiModeApply?()
            }
            return true
        }
        // 接頭辞一致があれば入力継続
        let allKeys =
            chooserCandidates.map(\.key) + areaHints.actions.values
            + (areaHints.windowHintsKey.flatMap {
                ConfigKeyDescriptor.typedSequence(forKeyName: $0)
            }
                .map { [$0] } ?? [])
        if allKeys.contains(where: { $0.hasPrefix(input) }) {
            chooserInput = input
            updateChooserHighlight()
        } else {
            chooserInput = ""
            updateChooserHighlight()
        }
        return true
    }

    /// Window Hints への遷移(JinraiMode 中は combo+1 して Hints を mode 維持で再表示)
    private func transitionToWindowHints() {
        let wasJinrai = chooserJinraiMode
        closeChooser()
        if wasJinrai {
            onJinraiModeApply?()
        } else {
            onOpenWindowHints?()
        }
    }

    private func updateChooserHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyChooserStyles()
        CATransaction.commit()
    }

    /// 入力状態に応じて各ラベルボックスの色を適用する(元 updateAreaCandidateCanvas)
    private func applyChooserStyles() {
        let selected = areaHints
        for refs in areaLabels {
            let active = chooserInput.isEmpty || refs.key.hasPrefix(chooserInput)
            let styleColor =
                (active
                    ? selected.styleColors[refs.styleKind]
                    : selected.styleDimmedColors[refs.styleKind])
                ?? ConfigColor(red: 0.58, green: 0.64, blue: 0.70, alpha: 0.95)
            let bgColor = active ? selected.normalBgColor : selected.dimmedBgColor
            let textColor = active ? selected.normalTextColor : selected.dimmedTextColor

            refs.container.backgroundColor = cgColor(bgColor)
            refs.border.strokeColor = cgColor(styleColor)
            refs.iconOutline.strokeColor = cgColor(styleColor)
            for fill in refs.iconFills {
                fill.backgroundColor = cgColor(styleColor)
            }

            // 入力済みプレフィックスを薄く、残りを通常色で描き分け
            if active, !chooserInput.isEmpty, refs.key.hasPrefix(chooserInput) {
                let prefixLength = min(chooserInput.count, refs.key.count)
                let attributed = NSMutableAttributedString()
                attributed.append(
                    NSAttributedString(
                        string: String(refs.key.prefix(prefixLength)),
                        attributes: [
                            .font: NSFont.systemFont(ofSize: AreaLabelLayout.keyFontSize),
                            .foregroundColor: nsColor(selected.typedTextColor),
                        ]))
                attributed.append(
                    NSAttributedString(
                        string: String(refs.key.dropFirst(prefixLength)),
                        attributes: [
                            .font: NSFont.systemFont(ofSize: AreaLabelLayout.keyFontSize),
                            .foregroundColor: nsColor(textColor),
                        ]))
                refs.keyLayer.string = attributed
            } else {
                refs.keyLayer.string = refs.key
                refs.keyLayer.foregroundColor = cgColor(textColor)
            }
            refs.detailLayer?.foregroundColor = cgColor(textColor)
        }
    }

    private func cgColor(_ color: ConfigColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func nsColor(_ color: ConfigColor) -> NSColor {
        NSColor(
            red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func runAction(
        _ name: String, window: AXWindow? = nil, jinraiMode: Bool = false
    ) {
        guard let win = window ?? WindowEnumerator.focusedWindow() else {
            if jinraiMode { onJinraiModeCancel?() }
            return
        }
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
            // JinraiMode 中は Hints に戻らず、分離されたウィンドウを続けて配置できるよう
            // 選択画面を再表示する(元 reopenWindowActionChooserAfterDetach)
            if jinraiMode {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(0.3))
                    self?.openAreaChooser(jinraiMode: true)
                }
            }
            return
        default:
            break
        }
        if jinraiMode {
            onJinraiModeApply?()
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
        NSLog("[jinrai.windowMover] Chrome のタブ分離メニューが見つかりません")
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
