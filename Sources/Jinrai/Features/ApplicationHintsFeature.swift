import AppKit
import Carbon.HIToolbox
import JinraiCore
import JinraiPlatform
import UserNotifications

/// アプリランチャー(元 application_hints.lua)。
/// 登録アプリをグリッド表示し、キーで起動 or 新規ウィンドウ作成する。
@MainActor
final class ApplicationHintsFeature {
    private let config: ApplicationHintsConfig
    private var hotkey: Hotkey?
    private let eventTap = EventTap()

    private var overlays: [OverlayWindow] = []
    private var currentInput = ""
    private var cells: [String: AppCell] = [:]  // key → セル
    private(set) var isVisible = false

    /// 新規ウィンドウ出現待ちの状態
    private var waiting = false
    private var waitTimer: Timer?
    private var waitTimeoutTimer: Timer?

    /// Window Hints へ戻る遷移コールバック(jinraiMode フラグ付き)
    var onOpenWindowHints: ((Bool) -> Void)?
    /// JinraiMode: 開始 / ウィンドウ作成完了後(→ エリア選択へ)/ キャンセル
    var onStartJinraiMode: (() -> Void)?
    var onSelectInJinraiMode: ((_ windowID: UInt32, _ pid: pid_t) -> Void)?
    var onCancelJinraiMode: (() -> Void)?
    /// 現在の表示が JinraiMode 文脈か
    private var showJinraiMode = false

    private struct AppCell {
        let entry: ApplicationHintsConfig.AppEntry
        let container: CALayer
        let iconLayer: CALayer
        let keyLayer: CATextLayer
        let nameLayer: CATextLayer
        let stateLayer: CATextLayer
    }

    init(config: ApplicationHintsConfig) {
        self.config = config

        if let key = config.hotkeyKey {
            hotkey = Hotkey(modifiers: config.hotkeyModifiers, key: key) { [weak self] in
                self?.toggle()
            }
        }

        eventTap.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        eventTap.onLeftMouseDown = { [weak self] _ in
            self?.closeAndCancelJinraiMode()
            return false
        }
    }

    func toggle() {
        if isVisible { closeAndCancelJinraiMode() } else { show() }
    }

    /// 閉じる + JinraiMode 中ならキャンセル通知(Escape・外クリック用)
    private func closeAndCancelJinraiMode() {
        let wasJinrai = showJinraiMode
        close()
        if wasJinrai {
            onCancelJinraiMode?()
        }
    }

    // MARK: - 表示

    func show(jinraiMode: Bool = false) {
        guard !isVisible, !config.apps.isEmpty else { return }
        showJinraiMode = jinraiMode

        // 配置基準: フォーカス中ウィンドウの中央(なければスクリーン中央)
        let focused = WindowEnumerator.focusedWindow()
        let focusFrame = focused?.frame
        let screen =
            focusFrame.flatMap { ScreenUtil.screenContaining($0) } ?? NSScreen.main
        guard let screen else { return }
        let screenFrame = ScreenUtil.frame(of: screen)
        let center =
            focusFrame.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: screenFrame.midX, y: screenFrame.midY)

        guard eventTap.start() else {
            NSLog("[jinrai.application_hints] キー捕捉を開始できません")
            return
        }

        currentInput = ""
        cells = [:]
        buildGrid(center: center, screen: screen, screenFrame: screenFrame)
        applyHighlights()
        isVisible = true
    }

    func close() {
        guard isVisible || !overlays.isEmpty else { return }
        isVisible = false
        showJinraiMode = false
        stopWait()
        eventTap.stop()
        for overlay in overlays {
            overlay.orderOut(nil)
        }
        overlays = []
        cells = [:]
        currentInput = ""
    }

    private func buildGrid(center: CGPoint, screen: NSScreen, screenFrame: CGRect) {
        let columns = min(config.columns, config.apps.count)
        let rows = Int((Double(config.apps.count) / Double(columns)).rounded(.up))
        let itemW = CGFloat(config.itemWidth)
        let itemH = CGFloat(config.itemHeight)
        let gap = CGFloat(config.gap)
        let totalWidth = CGFloat(columns) * itemW + CGFloat(columns - 1) * gap
        let totalHeight = CGFloat(rows) * itemH + CGFloat(rows - 1) * gap

        // グリッド全体が画面内に収まるよう開始座標をクランプ(top-left 座標)
        func clampStart(_ c: CGFloat, _ total: CGFloat, _ start: CGFloat, _ size: CGFloat)
            -> CGFloat
        {
            let maxStart = start + max(0, size - total)
            return min(max(c - total / 2, start), maxStart)
        }
        let startX = clampStart(center.x, totalWidth, screenFrame.minX, screenFrame.width)
        let startY = clampStart(center.y, totalHeight, screenFrame.minY, screenFrame.height)

        let overlay = OverlayWindow(frame: screenFrame, level: .hints)
        guard let root = overlay.rootLayer else { return }

        for (index, entry) in config.apps.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = startX + CGFloat(col) * (itemW + gap)
            let y = startY + CGFloat(row) * (itemH + gap)
            // overlay ローカル座標(bottom-left)へ
            let local = CGRect(
                x: x - screenFrame.minX,
                y: screenFrame.height - (y - screenFrame.minY) - itemH,
                width: itemW, height: itemH)
            let cell = buildCell(
                entry: entry, frame: local, scale: screen.backingScaleFactor)
            root.addSublayer(cell.container)
            cells[entry.key] = cell
        }

        overlay.orderFrontRegardless()
        overlays.append(overlay)
    }

    private func buildCell(
        entry: ApplicationHintsConfig.AppEntry, frame: CGRect, scale: CGFloat
    ) -> AppCell {
        let iconSize = CGFloat(config.iconSize)
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: entry.bundleID
        ).first

        let container = CALayer()
        container.frame = frame
        container.cornerRadius = CGFloat(config.cornerRadius)

        // アイコン(左、top-left 基準 x=16,y=24 → AppKit 反転)
        let iconLayer = CALayer()
        if let icon = appIcon(bundleID: entry.bundleID, running: running) {
            var rect = CGRect(origin: .zero, size: icon.size)
            iconLayer.contents = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        iconLayer.frame = CGRect(
            x: 16, y: frame.height - 24 - iconSize, width: iconSize, height: iconSize)
        container.addSublayer(iconLayer)

        let textX: CGFloat = 88
        let keyLayer = textLayer(entry.key, size: 30, bold: true, scale: scale)
        keyLayer.frame = CGRect(x: textX, y: frame.height - 14 - 36, width: 110, height: 36)
        container.addSublayer(keyLayer)

        let displayName = entry.name ?? appName(bundleID: entry.bundleID, running: running)
        let nameLayer = textLayer(displayName, size: 14, bold: false, scale: scale)
        nameLayer.frame = CGRect(x: textX, y: frame.height - 56 - 20, width: frame.width - textX - 12, height: 20)
        container.addSublayer(nameLayer)

        // 状態ラベル: 起動済=NEW / 未起動=OPEN
        let stateLayer = textLayer(
            running != nil ? "NEW" : "OPEN", size: 12, bold: true, scale: scale)
        stateLayer.foregroundColor = cgColor(config.stateColor)
        stateLayer.frame = CGRect(x: textX, y: frame.height - 82 - 16, width: 110, height: 16)
        container.addSublayer(stateLayer)

        return AppCell(
            entry: entry, container: container, iconLayer: iconLayer,
            keyLayer: keyLayer, nameLayer: nameLayer, stateLayer: stateLayer)
    }

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

    private func appIcon(bundleID: String, running: NSRunningApplication?) -> NSImage? {
        if let icon = running?.icon { return icon }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    private func appName(bundleID: String, running: NSRunningApplication?) -> String {
        if let name = running?.localizedName { return name }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    // MARK: - キー入力

    private func handleKeyDown(_ event: EventTap.KeyEvent) -> Bool {
        guard isVisible else { return false }
        // 待機中は Escape のみ
        if waiting {
            if event.keyCode == UInt32(kVK_Escape) { closeAndCancelJinraiMode() }
            return true
        }
        if event.keyCode == UInt32(kVK_Escape) {
            closeAndCancelJinraiMode()
            return true
        }
        if event.keyCode == UInt32(kVK_Delete) {
            currentInput = String(currentInput.dropLast())
            applyHighlights()
            return true
        }
        // JinraiMode 開始(triggers.applicationHints.key。表示は開いたまま)
        if let name = jinraiKeyName(of: event),
            name == config.jinraiModeKey
        {
            if !showJinraiMode {
                showJinraiMode = true
                currentInput = ""
                onStartJinraiMode?()
                applyHighlights()
            }
            return true
        }
        // Window Hints へ戻る
        if let name = event.character?.uppercased(),
            name == config.windowHintsKey, let onOpenWindowHints
        {
            let wasJinrai = showJinraiMode
            close()
            onOpenWindowHints(wasJinrai)
            return true
        }

        guard let character = event.character?.uppercased(), !character.isEmpty,
            character.rangeOfCharacter(from: .alphanumerics) != nil
        else { return true }

        let input = currentInput + character
        if let cell = cells.values.first(where: { $0.entry.key == input }) {
            select(cell.entry)
            return true
        }
        if cells.keys.contains(where: { $0.hasPrefix(input) }) {
            currentInput = input
        } else {
            currentInput = ""
        }
        applyHighlights()
        return true
    }

    /// JinraiMode トリガキー比較用("return" 等の特殊キー名に正規化)
    private func jinraiKeyName(of event: EventTap.KeyEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space: return "space"
        case kVK_Return: return "return"
        case kVK_Tab: return "tab"
        default: return event.character?.lowercased()
        }
    }

    private func applyHighlights() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for cell in cells.values {
            let active = currentInput.isEmpty || cell.entry.key.hasPrefix(currentInput)
            cell.container.backgroundColor = cgColor(
                active ? config.bgColor : config.dimmedBgColor)
            cell.iconLayer.opacity = active ? 1.0 : 0.3
            let textColor = active ? config.textColor : config.dimmedTextColor
            cell.nameLayer.foregroundColor = cgColor(textColor)
            cell.stateLayer.foregroundColor = cgColor(
                active ? config.stateColor : config.dimmedTextColor)

            // 入力済みプレフィックスをグレーアウト(Window Hints と同じ表現)
            let key = cell.entry.key
            let prefixLength =
                active && !currentInput.isEmpty ? min(currentInput.count, key.count) : 0
            if prefixLength > 0 {
                let font = NSFont.boldSystemFont(ofSize: 30)
                let attributed = NSMutableAttributedString()
                attributed.append(
                    NSAttributedString(
                        string: String(key.prefix(prefixLength)),
                        attributes: [
                            .font: font,
                            .foregroundColor: nsColor(config.keyHighlightColor),
                        ]))
                attributed.append(
                    NSAttributedString(
                        string: String(key.dropFirst(prefixLength)),
                        attributes: [
                            .font: font,
                            .foregroundColor: nsColor(textColor),
                        ]))
                cell.keyLayer.string = attributed
            } else {
                cell.keyLayer.string = key
                cell.keyLayer.foregroundColor = cgColor(textColor)
            }
        }
        CATransaction.commit()
    }

    // MARK: - 起動 / 新規ウィンドウ

    private func select(_ entry: ApplicationHintsConfig.AppEntry) {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: entry.bundleID
        ).first
        // 事前の標準ウィンドウID集合(新規ウィンドウ検出の基準)
        let previousIDs = Set(
            WindowEnumerator.orderedWindows()
                .filter { $0.bundleID == entry.bundleID }
                .map(\.id))

        // 状態ラベルを WAIT に
        cells[entry.key]?.stateLayer.string = "WAIT"

        if let urlString = entry.newWindowURL, let url = URL(string: urlString) {
            // アプリをアクティブ化せず URL イベントだけ送る(元 hs.urlevent.openURL 相当。
            // 既存ウィンドウが一瞬前面に出るのを防ぐ)。
            // 新規ウィンドウは出現検出後に ax.focus() で前面化される
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.open(url, configuration: configuration)
        } else if let running {
            // 起動済み → 新規ウィンドウのホットキーを対象アプリへ直接送出。
            // 自身の EventTap を経由しない postKeyStroke(toPid:) を使わないと、
            // モーダル中のキー捕捉に消費されて届かない。
            // activate() は既存ウィンドウを前面に出してしまうため呼ばない。
            // 新規ウィンドウは出現検出後に ax.focus() で前面化される
            EventTap.postKeyStroke(
                modifiers: entry.newWindowModifiers, key: entry.newWindowKey,
                toPid: running.processIdentifier)
        } else {
            // 未起動 → 起動
            guard
                let appURL = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: entry.bundleID)
            else {
                reportError("アプリが見つかりません: \(entry.bundleID)")
                close()
                return
            }
            NSWorkspace.shared.openApplication(
                at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }

        startWindowWait(entry: entry, previousIDs: previousIDs)
    }

    /// 新規ウィンドウ出現を 0.1s ポーリングし、focus 確認後に閉じる
    private func startWindowWait(
        entry: ApplicationHintsConfig.AppEntry, previousIDs: Set<UInt32>
    ) {
        waiting = true
        let deadline = Date().addingTimeInterval(config.windowWaitTimeout)

        waitTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.waiting else { return }
                let candidates = WindowEnumerator.orderedWindows()
                    .filter { $0.bundleID == entry.bundleID && !previousIDs.contains($0.id) }
                if let newWindow = candidates.first,
                    let ax = AXWindow.resolve(windowID: newWindow.id, pid: newWindow.pid)
                {
                    ax.focus()
                    self.stopWait()
                    let wasJinrai = self.showJinraiMode
                    self.close()
                    // JinraiMode 中: 作成したウィンドウを続けて配置(→ エリア選択へ)
                    if wasJinrai {
                        self.onSelectInJinraiMode?(newWindow.id, newWindow.pid)
                    }
                    return
                }
                if Date() > deadline {
                    self.stopWait()
                    self.reportError(
                        "新しいウィンドウの出現がタイムアウトしました: \(entry.bundleID)")
                    self.closeAndCancelJinraiMode()
                }
            }
        }
    }

    private func stopWait() {
        waiting = false
        waitTimer?.invalidate()
        waitTimer = nil
        waitTimeoutTimer?.invalidate()
        waitTimeoutTimer = nil
    }

    private func reportError(_ message: String) {
        NSLog("[jinrai.application_hints] %@", message)
        // UNUserNotificationCenter は .app バンドル外(swift run 等)から触ると
        // クラッシュするため、バンドルで動いているときだけ通知を出す
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true
            else { return }
            let content = UNMutableNotificationContent()
            content.title = "JINRAI"
            content.body = message
            try? await center.add(
                UNNotificationRequest(
                    identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    private func cgColor(_ color: ConfigColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func nsColor(_ color: ConfigColor) -> NSColor {
        NSColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    func teardown() {
        close()
        hotkey?.unregister()
        hotkey = nil
    }
}
