import AppKit
import Carbon.HIToolbox
import JinraiCore
import JinraiPlatform

/// Window Layouts のレイアウト選択モーダル。
/// 上部の入力欄でレイアウト名・説明をインクリメンタルサーチし、
/// ↑↓(ctrl+n/p)で選択、Enter で適用する。検索・選択の状態は
/// WindowLayoutPickerLogic(純ロジック)が持ち、ここは描画とキー結線のみ担う。
@MainActor
final class WindowLayoutPicker: NSObject, NSTextFieldDelegate {
    private let config: WindowLayoutsConfig
    /// モーダル系機能で共有(遷移中にタップを途切れさせないため)。
    /// ハンドラは他機能に上書きされるので表示のたびに bindEventTap() で張り直す
    private let eventTap: EventTap

    private var overlay: OverlayPanel?
    private var logic: WindowLayoutPickerLogic?
    private var searchField: PickerTextField?
    private var panelFrame: CGRect?
    private var previousApplication: NSRunningApplication?
    private var showJinraiMode = false
    private(set) var isVisible = false

    /// 選択確定時のコールバック(WindowLayoutsFeature が apply を結線する)
    var onSelect: ((WindowLayoutsConfig.Layout, Bool) -> Void)?
    /// JINRAI Mode 中にピッカーをキャンセルしたときのコールバック
    var onCancelJinraiMode: (() -> Void)?
    /// JINRAI Mode 中にピッカーを表示したディスプレイを通知するコールバック
    var onShowJinraiModeDisplay: ((JinraiModeDisplayTarget) -> Void)?

    /// 表示中はピッカーのホットキーが EventTap に消費されて Carbon Hotkey が
    /// 発火しないため、toggle クローズ用に keyCode+flags を自前で判定する
    private let hotkeyKeyCode: UInt32?
    private let hotkeyFlags: CGEventFlags

    private struct Row {
        let container: CALayer
        let nameLayer: CATextLayer
        let descriptionLayer: CATextLayer
    }
    private var countLayer: CATextLayer?
    private var rows: [Row] = []

    private let inputRowHeight: CGFloat = 44
    private let listPadding: CGFloat = 6
    private let nameFontSize: CGFloat = 14
    private let descriptionFontSize: CGFloat = 12

    private final class PickerTextField: NSTextField {}

    init(config: WindowLayoutsConfig, eventTap: EventTap) {
        self.config = config
        self.eventTap = eventTap
        if let binding = config.pickerHotkey {
            hotkeyKeyCode = KeyCodes.keyCode(for: binding.key)
            hotkeyFlags = KeyCodes.cgEventFlags(for: binding.modifiers)
        } else {
            hotkeyKeyCode = nil
            hotkeyFlags = []
        }

        super.init()
    }

    private func bindEventTap() {
        eventTap.onLeftMouseDown = { [weak self] location in
            guard let self else { return false }
            if self.isPointInsidePanel(location) {
                return false
            }
            self.closeAndCancelJinraiMode(restorePreviousApp: false)
            return false
        }
        eventTap.onKeyDown = { [weak self] event in
            guard let self, self.isVisible else { return false }
            if let hotkeyKeyCode = self.hotkeyKeyCode, event.keyCode == hotkeyKeyCode,
                event.flags.contains(self.hotkeyFlags)
            {
                self.closeAndCancelJinraiMode(restorePreviousApp: true)
                return true
            }
            return false
        }
    }

    func toggle() {
        if isVisible { closeAndCancelJinraiMode(restorePreviousApp: true) } else { show() }
    }

    func teardown() {
        close(restorePreviousApp: false)
    }

    // MARK: - 表示

    func show(jinraiMode: Bool = false) {
        guard !isVisible, !config.layouts.isEmpty else { return }
        showJinraiMode = jinraiMode

        // 配置基準: フォーカス中ウィンドウの中央(なければスクリーン中央)。
        // Application Hints と同じ基準で、Window Hints からの遷移時に視線移動を抑える
        let focusFrame = WindowEnumerator.focusedWindow()?.frame
        let screen = focusFrame.flatMap { ScreenUtil.screenContaining($0) } ?? NSScreen.main
        guard let screen else { return }
        let screenFrame = ScreenUtil.frame(of: screen)
        let center =
            focusFrame.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: screenFrame.midX, y: screenFrame.midY)

        bindEventTap()
        guard eventTap.start() else {
            NSLog("[jinrai.windowLayouts] クリック捕捉を開始できません")
            showJinraiMode = false
            return
        }

        previousApplication = NSWorkspace.shared.frontmostApplication
        logic = WindowLayoutPickerLogic(
            items: config.layouts.map { .init(name: $0.name, description: $0.description) },
            maxVisibleRows: config.maxVisibleRows)
        buildPanel(center: center, screen: screen, screenFrame: screenFrame)
        render()
        isVisible = true
        if jinraiMode {
            // ピッカーがキーウィンドウになると focusedWindow が解決できなくなるため、
            // 表示前に取得したウィンドウ frame をスナップショットとして渡す。
            // 中心の算出(jinraiMode.position の解釈)は JinraiModeVisuals 側が行う
            onShowJinraiModeDisplay?(
                JinraiModeDisplayTarget(
                    screenFrame: screenFrame, windowFrame: focusFrame, screen: screen))
        }
    }

    private func closeAndCancelJinraiMode(restorePreviousApp: Bool) {
        let wasJinrai = showJinraiMode
        close(restorePreviousApp: restorePreviousApp)
        if wasJinrai {
            onCancelJinraiMode?()
        }
    }

    func close(restorePreviousApp: Bool = true) {
        guard isVisible || overlay != nil else { return }
        isVisible = false
        showJinraiMode = false
        eventTap.stop()
        if let searchField {
            NotificationCenter.default.removeObserver(
                self, name: NSControl.textDidChangeNotification, object: searchField)
        }
        overlay?.orderOut(nil)
        if restorePreviousApp, let previousApplication,
            previousApplication != NSRunningApplication.current
        {
            previousApplication.activate(options: [])
        }
        overlay = nil
        logic = nil
        searchField = nil
        countLayer = nil
        panelFrame = nil
        previousApplication = nil
        rows = []
    }

    private func buildPanel(center: CGPoint, screen: NSScreen, screenFrame: CGRect) {
        let scale = screen.backingScaleFactor
        let panelW = CGFloat(config.pickerWidth)
        let rowH = CGFloat(config.rowHeight)
        let rowCount = min(config.layouts.count, config.maxVisibleRows)
        let panelH = inputRowHeight + 1 + listPadding * 2 + CGFloat(rowCount) * rowH

        // パネル全体が画面内に収まるよう開始座標をクランプ(top-left 座標)
        func clampStart(_ c: CGFloat, _ total: CGFloat, _ start: CGFloat, _ size: CGFloat)
            -> CGFloat
        {
            let maxStart = start + max(0, size - total)
            return min(max(c - total / 2, start), maxStart)
        }
        let startX = clampStart(center.x, panelW, screenFrame.minX, screenFrame.width)
        let startY = clampStart(center.y, panelH, screenFrame.minY, screenFrame.height)
        panelFrame = CGRect(x: startX, y: startY, width: panelW, height: panelH)

        let overlay = OverlayPanel(frame: panelFrame!, level: .hints)
        overlay.ignoresMouseEvents = false
        guard let root = overlay.rootLayer else { return }

        let panel = CALayer()
        panel.frame = CGRect(x: 0, y: 0, width: panelW, height: panelH)
        panel.backgroundColor = cgColor(config.bgColor)
        panel.cornerRadius = CGFloat(config.cornerRadius)
        panel.masksToBounds = true
        root.addSublayer(panel)

        // 入力行(クエリ + 件数)
        let countWidth: CGFloat = 80
        let inputBackground = CALayer()
        inputBackground.frame = CGRect(
            x: 10, y: panelH - inputRowHeight + (inputRowHeight - 30) / 2,
            width: panelW - countWidth - 32, height: 30)
        inputBackground.backgroundColor = inputBackgroundColor()
        inputBackground.borderColor = inputBorderColor()
        inputBackground.borderWidth = 1
        inputBackground.cornerRadius = 7
        panel.addSublayer(inputBackground)

        let search = PickerTextField(
            frame: CGRect(
                x: 18, y: panelH - inputRowHeight + (inputRowHeight - 22) / 2,
                width: panelW - countWidth - 48, height: 22))
        search.font = .systemFont(ofSize: 16)
        search.textColor = nsColor(config.textColor)
        search.placeholderAttributedString = NSAttributedString(
            string: "Type to filter...",
            attributes: [
                .foregroundColor: nsColor(config.dimmedTextColor),
                .font: NSFont.systemFont(ofSize: 16),
            ])
        search.isBordered = false
        search.isBezeled = false
        search.drawsBackground = false
        search.backgroundColor = .clear
        search.focusRingType = .none
        search.usesSingleLineMode = true
        search.lineBreakMode = .byTruncatingTail
        search.cell?.isScrollable = true
        search.delegate = self
        overlay.contentView?.addSubview(search)
        searchField = search
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(searchFieldDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: search)

        let count = textLayer("", size: 12, bold: false, scale: scale)
        count.alignmentMode = .right
        count.foregroundColor = cgColor(config.dimmedTextColor)
        count.frame = CGRect(
            x: panelW - countWidth - 16, y: panelH - inputRowHeight + (inputRowHeight - 16) / 2,
            width: countWidth, height: 16)
        panel.addSublayer(count)
        countLayer = count

        // 区切り線
        let separator = CALayer()
        var separatorColor = config.dimmedTextColor
        separatorColor.alpha *= 0.5
        separator.backgroundColor = cgColor(separatorColor)
        separator.frame = CGRect(x: 0, y: panelH - inputRowHeight - 1, width: panelW, height: 1)
        panel.addSublayer(separator)

        // レイアウト行(表示最大数分をプリアロケートし、render で内容を差し替える)
        let listTop = panelH - inputRowHeight - 1 - listPadding
        for index in 0..<rowCount {
            let container = CALayer()
            container.frame = CGRect(
                x: 8, y: listTop - CGFloat(index + 1) * rowH, width: panelW - 16, height: rowH)
            container.cornerRadius = 6

            let name = textLayer("", size: nameFontSize, bold: true, scale: scale)
            let description = textLayer(
                "", size: descriptionFontSize, bold: false, scale: scale)
            container.addSublayer(name)
            container.addSublayer(description)
            panel.addSublayer(container)
            rows.append(Row(container: container, nameLayer: name, descriptionLayer: description))
        }

        // nonactivating パネルなのでアプリをアクティブ化せずにキー入力を受けられる。
        // NSApp.activate すると、閉じたときに macOS が直前のアクティブアプリへ
        // アクティブ状態を返し、そのウィンドウがレイアウト適用後に raise されてしまう
        overlay.makeKeyAndOrderFront(nil)
        overlay.makeFirstResponder(search)
        self.overlay = overlay
    }

    /// logic の状態を各レイヤーへ反映する
    private func render() {
        guard let logic else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        countLayer?.string = "\(logic.filtered.count)/\(logic.items.count)"

        let visible = logic.visibleItems
        for (index, row) in rows.enumerated() {
            guard index < visible.count else {
                row.container.isHidden = true
                continue
            }
            let item = visible[index]
            let selected = logic.scrollOffset + index == logic.selectedIndex
            row.container.isHidden = false
            row.container.backgroundColor =
                selected ? cgColor(config.selectedBgColor) : nil

            let rowW = row.container.frame.width
            let rowH = row.container.frame.height
            let nameWidth = min(
                measuredWidth(item.name, size: nameFontSize, bold: true) + 4, rowW - 32)
            row.nameLayer.string = item.name
            row.nameLayer.foregroundColor =
                cgColor(selected ? config.selectedTextColor : config.textColor)
            row.nameLayer.frame = CGRect(
                x: 8, y: (rowH - 18) / 2, width: nameWidth, height: 18)

            row.descriptionLayer.string = item.description ?? ""
            row.descriptionLayer.foregroundColor = cgColor(config.dimmedTextColor)
            let descriptionX = 8 + nameWidth + 8
            row.descriptionLayer.frame = CGRect(
                x: descriptionX, y: (rowH - 16) / 2,
                width: max(0, rowW - descriptionX - 8), height: 16)
        }
    }

    // MARK: - キー入力

    @objc private func searchFieldDidChange(_ notification: Notification) {
        guard let search = notification.object as? NSTextField else { return }
        logic?.setQuery(search.stringValue)
        render()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let fieldEditor = obj.userInfo?["NSFieldEditor"] as? NSTextView else { return }
        fieldEditor.backgroundColor = .clear
        fieldEditor.drawsBackground = false
        fieldEditor.textColor = nsColor(config.textColor)
        fieldEditor.insertionPointColor = nsColor(config.textColor)
    }

    func control(
        _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
        guard isVisible else { return false }

        switch NSStringFromSelector(commandSelector) {
        case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
            submitSelectedLayout()
            return true
        case "cancelOperation:":
            closeAndCancelJinraiMode(restorePreviousApp: true)
            return true
        case "moveUp:":
            logic?.moveUp()
            render()
            return true
        case "moveDown:":
            logic?.moveDown()
            render()
            return true
        default:
            return false
        }
    }

    private func submitSelectedLayout() {
        guard let item = logic?.selectedItem,
            let layout = config.layouts.first(where: { $0.name == item.name })
        else { return }
        let wasJinrai = showJinraiMode
        close(restorePreviousApp: false)
        onSelect?(layout, wasJinrai)
    }

    private func isPointInsidePanel(_ point: CGPoint) -> Bool {
        panelFrame?.contains(point) == true
    }

    // MARK: - 描画ヘルパー

    private func textLayer(_ text: String, size: CGFloat, bold: Bool, scale: CGFloat)
        -> CATextLayer
    {
        let layer = CATextLayer()
        layer.string = text
        layer.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        layer.fontSize = size
        layer.contentsScale = scale
        layer.isWrapped = false
        layer.truncationMode = .end
        return layer
    }

    private func measuredWidth(_ text: String, size: CGFloat, bold: Bool) -> CGFloat {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func cgColor(_ color: ConfigColor) -> CGColor {
        CGColor(
            red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func nsColor(_ color: ConfigColor) -> NSColor {
        NSColor(
            red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func inputBackgroundColor() -> CGColor {
        CGColor(
            red: config.textColor.red,
            green: config.textColor.green,
            blue: config.textColor.blue,
            alpha: min(config.textColor.alpha, 1) * 0.08)
    }

    private func inputBorderColor() -> CGColor {
        CGColor(
            red: config.dimmedTextColor.red,
            green: config.dimmedTextColor.green,
            blue: config.dimmedTextColor.blue,
            alpha: min(config.dimmedTextColor.alpha, 1) * 0.45)
    }

}
