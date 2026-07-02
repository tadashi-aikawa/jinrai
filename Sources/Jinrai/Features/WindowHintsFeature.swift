import AppKit
import Carbon.HIToolbox
import JinraiCore
import JinraiPlatform

/// ウィンドウヒント(元 window_hints.lua の中核)。
/// ホットキーで全ウィンドウにアイコン+キーを重ね、逐次キー入力でフォーカス切替。
@MainActor
final class WindowHintsFeature {
    private let config: WindowHintsConfig
    private let focusHistory: FocusHistoryFeature?
    private var hotkey: Hotkey?
    private let eventTap = EventTap()

    private var overlays: [OverlayWindow] = []
    private var hints: [HintKeyAssignment.Hint] = []
    private var hintContainers: [String: CALayer] = [:]
    private var hintFrames: [String: CGRect] = [:]  // top-left 座標(外クリック判定用)
    private var currentInput = ""
    private var occludedWindowIDs: Set<UInt32> = []
    private var offSpaceWindowIDs: Set<UInt32> = []
    private let macosNativeTabsApps: Set<String>
    private var didRequestScreenCapture = false
    private(set) var isVisible = false

    /// Window Mover のエリア選択画面へ遷移するコールバック(相互結線)
    var onOpenWindowMover: (() -> Void)?

    init(
        config: WindowHintsConfig,
        focusHistory: FocusHistoryFeature?,
        macosNativeTabs: MacosNativeTabsConfig = .default
    ) {
        self.config = config
        self.focusHistory = focusHistory
        self.macosNativeTabsApps = Set(macosNativeTabs.apps)

        if let key = config.hotkeyKey {
            hotkey = Hotkey(modifiers: config.hotkeyModifiers, key: key) { [weak self] in
                self?.toggle()
            }
            if hotkey == nil {
                NSLog("[jinrai.window_hints] ホットキーの登録に失敗: %@", key)
            }
        }

        eventTap.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        eventTap.onLeftMouseDown = { [weak self] location in
            self?.handleMouseDown(location) ?? false
        }
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }

    // MARK: - 表示

    func show() {
        guard !isVisible else { return }

        let entries = collectEntries()
        guard !entries.isEmpty else { return }

        hints = HintKeyAssignment.assign(
            entries: entries,
            hintChars: config.hintChars,
            overrides: config.prefixOverrides,
            reservedChars: reservedChars()
        )
        guard !hints.isEmpty else { return }

        guard eventTap.start() else {
            NSLog("[jinrai.window_hints] キー捕捉を開始できません(権限またはセキュア入力)")
            return
        }

        // プレビューが有効なら画面収録権限を一度だけ要求(未許可時はプレビューなしで続行)
        if config.previewEnabled, hints.contains(where: isDockHint),
            !WindowCapture.hasPermission, !didRequestScreenCapture
        {
            didRequestScreenCapture = true
            WindowCapture.requestPermission()
        }

        currentInput = ""
        buildOverlays()
        isVisible = true

        if config.cursorOnStart,
            let active = hints.first(where: { $0.entry.window.isFocused })
        {
            Mouse.moveToCenter(of: active.entry.window.frame)
        }
    }

    func close() {
        guard isVisible else { return }
        isVisible = false
        eventTap.stop()
        for overlay in overlays {
            overlay.orderOut(nil)
        }
        overlays = []
        hintContainers = [:]
        hintFrames = [:]
        hints = []
        currentInput = ""
    }

    /// 候補収集(現Space の可視標準ウィンドウ。完全に隠れたものは occluded 扱い)
    private func collectEntries() -> [HintKeyAssignment.Entry] {
        let ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        let standard = WindowEnumerator.standardWindows(from: ordered)
        occludedWindowIDs = Set(
            standard.filter {
                DirectionScoring.isFullyOccludedWindow(
                    $0, orderedWindows: ordered, config: config.directionScoring)
            }.map(\.id))
        var entries = standard.map { win in
            HintKeyAssignment.Entry(
                window: win,
                appKey: win.bundleID ?? win.appName,
                appTitle: win.appName,
                title: win.title
            )
        }
        if !config.includeActiveWindow {
            entries.removeAll { $0.window.isFocused }
        }

        // 別 Space の候補(元 collectCandidateWindows の includeOtherSpaces)
        offSpaceWindowIDs = []
        if config.includeOtherSpaces {
            let onScreenIDs = Set(ordered.map(\.id))
            let activeSpaces = Spaces.activeSpaceIDs()
            let spaceNumbers = Spaces.spaceNumbersByID()
            let others = WindowEnumerator.allSpacesWindows()
                .filter {
                    $0.pid != ProcessInfo.processInfo.processIdentifier
                        && !onScreenIDs.contains($0.id)
                }
            for var win in WindowEnumerator.standardWindows(from: others) {
                guard let spaceID = Spaces.spaceID(of: win.id) else {
                    continue
                }
                // 現Space にあるのに画面にない(最小化等)ものは対象外
                guard !activeSpaces.contains(spaceID) else { continue }
                win.spaceNumber = spaceNumbers[spaceID]
                // ネイティブタブアプリで Space 不明な候補は幽霊タブの可能性があるため除外
                let appKey = win.bundleID ?? win.appName
                if macosNativeTabsApps.contains(appKey), win.spaceNumber == nil {
                    continue
                }
                offSpaceWindowIDs.insert(win.id)
                entries.append(
                    HintKeyAssignment.Entry(
                        window: win,
                        appKey: appKey,
                        appTitle: win.appName,
                        title: win.title
                    ))
            }
        }
        // 表示順: アプリ名 → タイトル → x → y(元 collectEntries のソート)
        entries.sort { a, b in
            if a.appTitle != b.appTitle { return a.appTitle < b.appTitle }
            if a.title != b.title { return a.title < b.title }
            if a.window.frame.minX != b.window.frame.minX {
                return a.window.frame.minX < b.window.frame.minX
            }
            return a.window.frame.minY < b.window.frame.minY
        }
        return entries
    }

    /// ナビゲーションキーに予約された文字(ヒントキーから除外)
    private func reservedChars() -> Set<String> {
        var reserved = Set<String>()
        if let key = config.navigationFocusBackKey { reserved.insert(key.uppercased()) }
        if let key = config.windowMoverKey { reserved.insert(key.uppercased()) }
        for key in config.directionHintKeys.keys { reserved.insert(key.uppercased()) }
        if let key = config.prevSpaceKey { reserved.insert(key.uppercased()) }
        if let key = config.nextSpaceKey { reserved.insert(key.uppercased()) }
        return reserved
    }

    // MARK: - 描画

    /// ドック行き(別Space または完全に隠れた)ヒントか
    private func isDockHint(_ hint: HintKeyAssignment.Hint) -> Bool {
        offSpaceWindowIDs.contains(hint.entry.window.id)
            || occludedWindowIDs.contains(hint.entry.window.id)
    }

    private func buildOverlays() {
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        for screen in NSScreen.screens {
            let screenFrame = ScreenUtil.frame(of: screen)
            let overlay = OverlayWindow(frame: screenFrame)
            guard let root = overlay.rootLayer else { continue }

            // ドック(画面下部に別Space・隠れウィンドウの候補を並べる)はメイン画面のみ
            if screen == mainScreen {
                buildDock(root: root, screenFrame: screenFrame)
            }

            for hint in hints where !isDockHint(hint) {
                let winFrame = hint.entry.window.frame
                guard screenFrame.intersects(winFrame) else { continue }

                // フォーカス中ウィンドウのハイライト枠
                if hint.entry.window.isFocused {
                    root.addSublayer(
                        highlightLayer(
                            windowFrame: winFrame, screenFrame: screenFrame,
                            overlayHeight: screenFrame.height))
                }

                let container = hintContainer(for: hint)
                let size = container.bounds.size
                var center = CGPoint(x: winFrame.midX, y: winFrame.midY)
                // 画面内に収める
                center.x = min(
                    max(center.x, screenFrame.minX + size.width / 2),
                    screenFrame.maxX - size.width / 2)
                center.y = min(
                    max(center.y, screenFrame.minY + size.height / 2),
                    screenFrame.maxY - size.height / 2)

                // overlay 内ローカル座標(AppKit: bottom-left 原点)へ変換
                let localX = center.x - screenFrame.minX - size.width / 2
                let localTopY = center.y - screenFrame.minY - size.height / 2
                let localY = screenFrame.height - localTopY - size.height
                container.frame = CGRect(origin: CGPoint(x: localX, y: localY), size: size)
                root.addSublayer(container)

                hintContainers[hint.key] = container
                hintFrames[hint.key] = CGRect(
                    x: center.x - size.width / 2, y: center.y - size.height / 2,
                    width: size.width, height: size.height)
            }

            overlay.orderFrontRegardless()
            overlays.append(overlay)
        }
    }

    /// 別Space・完全に隠れた候補を画面下部に並べる(元 occluded dock の簡易版)
    private func buildDock(root: CALayer, screenFrame: CGRect) {
        let dockHints = hints.filter(isDockHint)
        guard !dockHints.isEmpty else { return }

        let gap = CGFloat(config.dockItemGap)
        let containers = dockHints.map { ($0, hintContainer(for: $0)) }
        let maxRowWidth = screenFrame.width - 48

        // 幅に収まるよう行分割
        var rows: [[(HintKeyAssignment.Hint, CALayer)]] = [[]]
        var rowWidth: CGFloat = 0
        for item in containers {
            let width = item.1.bounds.width
            if rowWidth > 0, rowWidth + gap + width > maxRowWidth {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(item)
            rowWidth += (rowWidth > 0 ? gap : 0) + width
        }

        var rowBottom = CGFloat(config.dockBottomMargin)  // AppKit座標: 下からの距離
        for row in rows.reversed() {
            let totalWidth =
                row.reduce(0) { $0 + $1.1.bounds.width } + gap * CGFloat(row.count - 1)
            let rowHeight = row.map(\.1.bounds.height).max() ?? 0
            var x = (screenFrame.width - totalWidth) / 2
            for (hint, container) in row {
                container.frame = CGRect(
                    origin: CGPoint(x: x, y: rowBottom), size: container.bounds.size)
                root.addSublayer(container)
                hintContainers[hint.key] = container
                // 外クリック判定用に top-left グローバル座標も記録
                let globalTopY =
                    screenFrame.minY + screenFrame.height - rowBottom
                    - container.bounds.height
                hintFrames[hint.key] = CGRect(
                    x: screenFrame.minX + x, y: globalTopY,
                    width: container.bounds.width, height: container.bounds.height)
                x += container.bounds.width + gap
            }
            rowBottom += rowHeight + gap
        }
    }

    private func highlightLayer(
        windowFrame: CGRect, screenFrame: CGRect, overlayHeight: CGFloat
    ) -> CAShapeLayer {
        let localTopY = windowFrame.minY - screenFrame.minY
        let local = CGRect(
            x: windowFrame.minX - screenFrame.minX,
            y: overlayHeight - localTopY - windowFrame.height,
            width: windowFrame.width,
            height: windowFrame.height
        )
        let width = CGFloat(config.focusedHighlightWidth)
        let shape = CAShapeLayer()
        shape.path = CGPath(
            rect: local.insetBy(dx: width / 2, dy: width / 2), transform: nil)
        shape.fillColor = nil
        shape.lineWidth = width
        shape.strokeColor = cgColor(config.focusedHighlightColor)
        return shape
    }

    private func hintState(of hint: HintKeyAssignment.Hint) -> HintState {
        if hint.entry.window.isFocused { return .active }
        if isDockHint(hint) { return .occluded }
        return .normal
    }

    /// Space 番号バッジの色パレット(元 spaceBadge.spaceColors: 青/緑/橙/紫/桃)
    private static let spaceBadgeColors: [ConfigColor] = [
        ConfigColor(red: 0.34, green: 0.64, blue: 0.96, alpha: 0.56),
        ConfigColor(red: 0.30, green: 0.78, blue: 0.47, alpha: 0.56),
        ConfigColor(red: 0.95, green: 0.60, blue: 0.25, alpha: 0.56),
        ConfigColor(red: 0.68, green: 0.42, blue: 0.90, alpha: 0.56),
        ConfigColor(red: 0.92, green: 0.38, blue: 0.58, alpha: 0.56),
    ]

    /// ヒント1個分のレイヤー(角丸背景+アイコン+キー+タイトル)
    private func hintContainer(for hint: HintKeyAssignment.Hint) -> CALayer {
        let state = hintState(of: hint)
        let style = config.states[state] ?? config.states[.normal]!

        let padding = CGFloat(config.padding)
        let iconSize = CGFloat(config.iconSize)

        let keyText = textLayer(
            hint.key, fontSize: config.keyFontSize, color: style.keyColor, bold: true)
        let title =
            config.titleShow
            ? textLayer(
                truncate(
                    hint.entry.title.isEmpty ? hint.entry.appTitle : hint.entry.title,
                    max: config.titleMaxSize),
                fontSize: config.titleFontSize, color: style.titleColor, bold: false)
            : nil

        // 隠れウィンドウのプレビュー(要・画面収録権限。未許可時はスキップ)
        var previewImage: CGImage?
        if isDockHint(hint), config.previewEnabled, WindowCapture.hasPermission {
            previewImage = WindowCapture.captureImage(windowID: hint.entry.window.id)
        }
        var belowPreviewSize = CGSize.zero
        if let image = previewImage, config.previewMode == "below", image.width > 0 {
            let width = CGFloat(config.previewWidth)
            belowPreviewSize = CGSize(
                width: width,
                height: width * CGFloat(image.height) / CGFloat(image.width))
        }

        let contentWidth = max(
            iconSize + 8 + keyText.preferredFrameSize().width,
            title?.preferredFrameSize().width ?? 0,
            belowPreviewSize.width,
            CGFloat(config.keyMinWidth))
        let contentHeight =
            max(iconSize, keyText.preferredFrameSize().height)
            + (title != nil ? title!.preferredFrameSize().height + 8 : 0)
            + (belowPreviewSize.height > 0
                ? belowPreviewSize.height + CGFloat(config.previewPadding) : 0)

        let container = CALayer()
        container.bounds = CGRect(
            x: 0, y: 0,
            width: contentWidth + padding * 2,
            height: contentHeight + padding * 2)
        container.backgroundColor = cgColor(style.bgColor)
        container.cornerRadius = CGFloat(config.cornerRadius)

        // mode "background": プレビューをヒント全体の背景として敷く
        if let image = previewImage, config.previewMode == "background" {
            container.masksToBounds = true
            let previewLayer = CALayer()
            previewLayer.contents = image
            previewLayer.contentsGravity = .resizeAspectFill
            previewLayer.frame = container.bounds
            previewLayer.opacity = Float(config.previewAlpha)
            container.addSublayer(previewLayer)
        }

        // mode "below": タイトルの下に小さくプレビューを表示
        var bottomY = padding
        if let image = previewImage, belowPreviewSize.height > 0 {
            let previewLayer = CALayer()
            previewLayer.contents = image
            previewLayer.contentsGravity = .resizeAspectFill
            previewLayer.masksToBounds = true
            previewLayer.cornerRadius = 4
            previewLayer.opacity = Float(config.previewAlpha)
            previewLayer.frame = CGRect(
                x: (container.bounds.width - belowPreviewSize.width) / 2,
                y: bottomY,
                width: belowPreviewSize.width, height: belowPreviewSize.height)
            container.addSublayer(previewLayer)
            bottomY += belowPreviewSize.height + CGFloat(config.previewPadding)
        }

        // アイコン(左)+キー(右)を上段に、タイトルを下段に
        let topRowY = bottomY + (title != nil ? title!.preferredFrameSize().height + 8 : 0)
        if let app = NSRunningApplication(processIdentifier: hint.entry.window.pid) {
            let iconLayer = CALayer()
            let icon = app.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
            var rect = CGRect(origin: .zero, size: icon.size)
            iconLayer.contents = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            iconLayer.frame = CGRect(x: padding, y: topRowY, width: iconSize, height: iconSize)
            iconLayer.opacity = Float(style.iconAlpha)
            container.addSublayer(iconLayer)
        }

        let keySize = keyText.preferredFrameSize()
        keyText.frame = CGRect(
            x: padding + iconSize + 8,
            y: topRowY + (iconSize - keySize.height) / 2,
            width: keySize.width, height: keySize.height)
        container.addSublayer(keyText)

        if let title {
            let titleSize = title.preferredFrameSize()
            title.frame = CGRect(
                x: (container.bounds.width - titleSize.width) / 2,
                y: bottomY,
                width: titleSize.width, height: titleSize.height)
            container.addSublayer(title)
        }

        // Space 番号バッジ(別Space候補のみ、右上に表示)
        if let spaceNumber = hint.entry.window.spaceNumber {
            let badgeSize: CGFloat = 32
            let color = Self.spaceBadgeColors[(spaceNumber - 1) % Self.spaceBadgeColors.count]
            let badge = CATextLayer()
            badge.string = String(spaceNumber)
            badge.font = NSFont.boldSystemFont(ofSize: 18)
            badge.fontSize = 18
            badge.alignmentMode = .center
            badge.foregroundColor = CGColor(gray: 1, alpha: 0.92)
            badge.backgroundColor = CGColor(
                red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            badge.borderColor = CGColor(red: 0.98, green: 0.99, blue: 1.00, alpha: 0.72)
            badge.borderWidth = 1
            badge.cornerRadius = badgeSize / 2
            badge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            badge.frame = CGRect(
                x: container.bounds.width - badgeSize - 4,
                y: container.bounds.height - badgeSize - 4,
                width: badgeSize, height: badgeSize)
            container.addSublayer(badge)
        }

        return container
    }

    private func textLayer(
        _ text: String, fontSize: Double, color: ConfigColor, bold: Bool
    ) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = text
        layer.font = bold
            ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        layer.fontSize = fontSize
        layer.foregroundColor = cgColor(color)
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer.alignmentMode = .center
        return layer
    }

    private func truncate(_ text: String, max maxSize: Int) -> String {
        text.count <= maxSize ? text : String(text.prefix(maxSize)) + "…"
    }

    private func cgColor(_ color: ConfigColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    // MARK: - 入力処理

    /// ナビゲーションキー比較用のキー名("space" "return" 等の特殊キー名に正規化)
    private func keyName(of event: EventTap.KeyEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space: return "space"
        case kVK_Return: return "return"
        case kVK_Tab: return "tab"
        default: return event.character?.lowercased()
        }
    }

    private func handleKeyDown(_ event: EventTap.KeyEvent) -> Bool {
        guard isVisible else { return false }

        // Escape で閉じる
        if event.keyCode == UInt32(kVK_Escape) {
            close()
            return true
        }
        // ホットキー再押下でトグル(モーダル中は Carbon ホットキーに届かないため自前判定)
        if let hotkeyKey = config.hotkeyKey,
            let hotkeyCode = KeyCodes.keyCode(for: hotkeyKey),
            event.keyCode == hotkeyCode,
            event.flags.contains(KeyCodes.cgEventFlags(for: config.hotkeyModifiers))
        {
            close()
            return true
        }
        // Backspace で1文字戻す
        if event.keyCode == UInt32(kVK_Delete) || event.keyCode == UInt32(kVK_ForwardDelete) {
            currentInput = HintInputMatcher.backspace(currentInput: currentInput)
            updateHighlight()
            return true
        }
        // focusBack キー
        if let name = keyName(of: event),
            name == config.navigationFocusBackKey,
            let focusHistory
        {
            close()
            focusHistory.focusBack(centerCursor: config.cursorOnSelect)
            return true
        }
        // 数字キー 1〜9 で該当 Space へ移動
        if config.spacesNumbers,
            let character = event.character,
            let number = Int(character), (1...9).contains(number)
        {
            close()
            Spaces.gotoSpace(number: number)
            return true
        }
        // 前後の Space へ移動
        if let name = keyName(of: event) {
            if name == config.prevSpaceKey {
                close()
                Spaces.gotoPrevSpace()
                return true
            }
            if name == config.nextSpaceKey {
                close()
                Spaces.gotoNextSpace()
                return true
            }
        }
        // Window Mover のエリア選択へ遷移
        if let name = keyName(of: event),
            name == config.windowMoverKey,
            let onOpenWindowMover
        {
            close()
            onOpenWindowMover()
            return true
        }
        // 方向キー(8方向ナビゲーション)
        if let name = keyName(of: event),
            let direction = config.directionHintKeys[name]
        {
            runDirectionalMove(direction)
            return true
        }

        // ヒント文字の逐次マッチ
        guard let character = event.character, !character.isEmpty,
            character.rangeOfCharacter(from: .alphanumerics) != nil
        else { return true }

        switch HintInputMatcher.advance(
            currentInput: currentInput, char: character, keys: hints.map(\.key))
        {
        case .selected(let key):
            if let hint = hints.first(where: { $0.key == key }) {
                let swap =
                    config.swapModifiers.map {
                        event.flags.contains(KeyCodes.cgEventFlags(for: $0))
                    } ?? false
                selectWindow(hint, swap: swap)
            }
        case .partial(let input):
            currentInput = input
            updateHighlight()
        case .reset:
            currentInput = ""
            updateHighlight()
        }
        return true  // 表示中は全キーを消費
    }

    private func handleMouseDown(_ location: CGPoint) -> Bool {
        guard isVisible else { return false }
        // ヒント上のクリック → 選択、外側 → 閉じる
        if let hint = hints.first(where: { hintFrames[$0.key]?.contains(location) == true }) {
            selectWindow(hint)
            return true
        }
        close()
        return false  // 外クリックはアプリに透過
    }

    private func selectWindow(_ hint: HintKeyAssignment.Hint, swap: Bool = false) {
        let window = hint.entry.window
        close()
        guard let ax = AXWindow.resolve(windowID: window.id, pid: window.pid) else { return }
        if swap, let focused = WindowEnumerator.focusedWindow(),
            focused.windowID != ax.windowID,
            let fromFrame = focused.frame, let toFrame = ax.frame
        {
            // 移動元と移動先の frame を交換(元 swapWindowFrames)
            focused.setFrame(toFrame)
            ax.setFrame(fromFrame)
        }
        ax.focus()
        if config.cursorOnSelect {
            Mouse.moveToCenter(of: ax.frame ?? window.frame)
        }
    }

    /// 方向ナビゲーション: 現Space の非オクルージョン候補から最良を選んでフォーカス
    private func runDirectionalMove(_ direction: Direction) {
        let ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        guard let current = ordered.first(where: { $0.isFocused }) else {
            close()
            return
        }
        let candidates = WindowEnumerator.standardWindows(from: ordered)
            .filter {
                !DirectionScoring.isFullyOccludedWindow(
                    $0, orderedWindows: ordered, config: config.directionScoring)
            }
        let previous = focusHistory?.previousWindow().flatMap { prev in
            ordered.first { $0.id == prev.windowID }
        }
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: candidates,
            direction: direction,
            previous: previous,
            orderedWindows: ordered,
            config: config.directionScoring
        )
        close()
        guard let target,
            let ax = AXWindow.resolve(windowID: target.id, pid: target.pid)
        else { return }
        ax.focus()
        if config.cursorOnSelect {
            Mouse.moveToCenter(of: ax.frame ?? target.frame)
        }
    }

    /// 入力中の接頭辞に一致しないヒントを dimmed 表示にする
    private func updateHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for hint in hints {
            guard let container = hintContainers[hint.key] else { continue }
            let matches = currentInput.isEmpty || hint.key.hasPrefix(currentInput)
            let state: HintState = matches ? hintState(of: hint) : .dimmed
            let style = config.states[state] ?? config.states[.normal]!
            container.backgroundColor = cgColor(style.bgColor)
            container.opacity = matches ? 1.0 : 0.35
        }
        CATransaction.commit()
    }

    func teardown() {
        close()
        hotkey?.unregister()
        hotkey = nil
    }
}
