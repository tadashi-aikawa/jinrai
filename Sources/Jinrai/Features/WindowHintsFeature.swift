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
    private(set) var isVisible = false

    init(config: WindowHintsConfig, focusHistory: FocusHistoryFeature?) {
        self.config = config
        self.focusHistory = focusHistory

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

    /// 候補収集(最小版: 現Space の可視標準ウィンドウ)
    private func collectEntries() -> [HintKeyAssignment.Entry] {
        let ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        let standard = WindowEnumerator.standardWindows(from: ordered)
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
        for key in config.directionHintKeys.keys { reserved.insert(key.uppercased()) }
        if let key = config.prevSpaceKey { reserved.insert(key.uppercased()) }
        if let key = config.nextSpaceKey { reserved.insert(key.uppercased()) }
        return reserved
    }

    // MARK: - 描画

    private func buildOverlays() {
        for screen in NSScreen.screens {
            let screenFrame = ScreenUtil.frame(of: screen)
            let overlay = OverlayWindow(frame: screenFrame)
            guard let root = overlay.rootLayer else { continue }

            for hint in hints {
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

    /// ヒント1個分のレイヤー(角丸背景+アイコン+キー+タイトル)
    private func hintContainer(for hint: HintKeyAssignment.Hint) -> CALayer {
        let state: HintState = hint.entry.window.isFocused ? .active : .normal
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

        let contentWidth = max(
            iconSize + 8 + keyText.preferredFrameSize().width,
            title?.preferredFrameSize().width ?? 0,
            CGFloat(config.keyMinWidth))
        let contentHeight =
            max(iconSize, keyText.preferredFrameSize().height)
            + (title != nil ? title!.preferredFrameSize().height + 8 : 0)

        let container = CALayer()
        container.bounds = CGRect(
            x: 0, y: 0,
            width: contentWidth + padding * 2,
            height: contentHeight + padding * 2)
        container.backgroundColor = cgColor(style.bgColor)
        container.cornerRadius = CGFloat(config.cornerRadius)

        // アイコン(左)+キー(右)を上段に、タイトルを下段に
        let topRowY = padding + (title != nil ? title!.preferredFrameSize().height + 8 : 0)
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
                y: padding,
                width: titleSize.width, height: titleSize.height)
            container.addSublayer(title)
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
        if let character = event.character?.lowercased(),
            character == config.navigationFocusBackKey,
            let focusHistory
        {
            close()
            focusHistory.focusBack(centerCursor: config.cursorOnSelect)
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
                selectWindow(hint)
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

    private func selectWindow(_ hint: HintKeyAssignment.Hint) {
        let window = hint.entry.window
        close()
        guard let ax = AXWindow.resolve(windowID: window.id, pid: window.pid) else { return }
        ax.focus()
        if config.cursorOnSelect {
            Mouse.moveToCenter(of: ax.frame ?? window.frame)
        }
    }

    /// 入力中の接頭辞に一致しないヒントを dimmed 表示にする
    private func updateHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for hint in hints {
            guard let container = hintContainers[hint.key] else { continue }
            let matches = currentInput.isEmpty || hint.key.hasPrefix(currentInput)
            let state: HintState =
                matches
                ? (hint.entry.window.isFocused ? .active : .normal)
                : .dimmed
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
