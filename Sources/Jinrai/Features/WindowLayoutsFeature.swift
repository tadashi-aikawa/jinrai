import AppKit
import JinraiCore
import JinraiPlatform

/// Window Layouts: 定義済みレイアウト(複数ウィンドウ → ディスプレイ・エリア)を
/// ホットキーで一括適用する。計画の算出は WindowLayoutPlanner(純ロジック)が担う。
@MainActor
final class WindowLayoutsFeature {
    private let config: WindowLayoutsConfig
    /// 適用完了後にカーソルをフォーカスウィンドウ中央へ移動するか(windowMover 設定を共有)
    private let cursorAfterMove: Bool
    /// モーダル系機能で共有する EventTap(ピッカーと、launch 出現待ち中のキー保持に使う)
    private let eventTap: EventTap
    private var hotkeys: [Hotkey] = []
    /// activeWindow はフォーカス対象(unlistedWindows のみのレイアウトなど、フォーカス対象がなければ nil)
    var onJinraiModeApply: ((_ activeWindow: (windowID: UInt32, pid: pid_t)?) -> Void)?
    var onJinraiModeCancel: (() -> Void)?
    var onJinraiModePickerDisplay: ((JinraiModeDisplayTarget) -> Void)?

    /// 1回の適用セッション。launch したアプリのウィンドウ出現待ちと、
    /// フルスクリーン解除を伴う非同期 apply の完了を追跡し、全解決後にフォーカスを確定する
    private final class Session {
        let layout: WindowLayoutsConfig.Layout
        let screens: [WindowLayoutPlanner.ScreenInput]
        var claimedIDs: Set<UInt32> = []
        var pendingLaunchIndices: [Int] = []
        var pendingApplies = 0
        var deadline = Date()
        var focusTarget: (entryIndex: Int, windowID: UInt32, pid: pid_t)?
        var preferredFocusEntryIndex: Int?
        var appliedTargets: [(entryIndex: Int, windowID: UInt32, pid: pid_t)] = []
        let jinraiMode: Bool
        /// 出現待ちの間 EventTap のキー保持(holdKeysForNextStart)を仕掛けたか。
        /// 仕掛けた場合のみ、完了時に保持キーの受け渡しと tap の解放を行う
        var didHoldKeys = false

        init(
            layout: WindowLayoutsConfig.Layout, screens: [WindowLayoutPlanner.ScreenInput],
            jinraiMode: Bool
        ) {
            self.layout = layout
            self.screens = screens
            self.jinraiMode = jinraiMode
        }
    }
    private var session: Session?
    private var waitTimer: Timer?
    /// レイアウト選択モーダル(pickerHotkey または Window Hints 経由の導線がある時のみ生成)
    private var picker: WindowLayoutPicker?

    init(config: WindowLayoutsConfig, cursorAfterMove: Bool, eventTap: EventTap) {
        self.config = config
        self.cursorAfterMove = cursorAfterMove
        self.eventTap = eventTap

        for layout in config.layouts {
            guard let binding = layout.hotkey else { continue }
            let hotkey = Hotkey(modifiers: binding.modifiers, key: binding.key) { [weak self] in
                self?.apply(layout: layout)
            }
            if let hotkey {
                hotkeys.append(hotkey)
            } else {
                NSLog("[jinrai.windowLayouts] ホットキーの登録に失敗: %@", binding.key)
            }
        }

        if config.pickerHotkey != nil || config.windowHintsKey != nil {
            let picker = WindowLayoutPicker(config: config, eventTap: eventTap)
            picker.onSelect = { [weak self] layout, jinraiMode in
                self?.apply(layout: layout, jinraiMode: jinraiMode)
            }
            picker.onCancelJinraiMode = { [weak self] in
                self?.onJinraiModeCancel?()
            }
            picker.onShowJinraiModeDisplay = { [weak self] displayTarget in
                self?.onJinraiModePickerDisplay?(displayTarget)
            }
            if let binding = config.pickerHotkey {
                let hotkey = Hotkey(modifiers: binding.modifiers, key: binding.key) {
                    [weak picker] in
                    picker?.toggle()
                }
                if let hotkey {
                    hotkeys.append(hotkey)
                } else {
                    NSLog("[jinrai.windowLayouts] ピッカーのホットキーの登録に失敗: %@", binding.key)
                }
            }
            self.picker = picker
        }
    }

    func showPicker(jinraiMode: Bool = false) {
        picker?.show(jinraiMode: jinraiMode)
    }

    func teardown() {
        for hotkey in hotkeys {
            hotkey.unregister()
        }
        hotkeys.removeAll()
        picker?.teardown()
        picker = nil
        cancelSession()
    }

    private func cancelSession() {
        waitTimer?.invalidate()
        waitTimer = nil
        session = nil
    }

    // MARK: - 適用

    private func apply(layout: WindowLayoutsConfig.Layout, jinraiMode: Bool = false) {
        // 適用中の再発火は前回セッションを破棄して上書きする
        cancelSession()

        let screens = snapshotScreens()
        let plan = WindowLayoutPlanner.makePlan(
            entries: layout.windows,
            closeEntries: layout.closeWindows,
            onScreenWindows: WindowEnumerator.orderedWindows(),
            minimizedWindows: collectMinimizedWindows(for: layout),
            screens: screens
        )
        // unlistedWindows 指定時は配置対象が1件もなくても続行する(未記述ウィンドウ処理だけを行う)
        guard
            !plan.placements.isEmpty || !plan.pendingLaunchIndices.isEmpty
                || !plan.closeTargets.isEmpty || layout.unlistedWindows != nil
        else {
            NSLog("[jinrai.windowLayouts] '%@' にマッチするウィンドウがありません", layout.name)
            if jinraiMode {
                onJinraiModeCancel?()
            }
            return
        }

        let session = Session(layout: layout, screens: screens, jinraiMode: jinraiMode)
        // AXClose は非同期のため、閉じかけウィンドウを launch 待ちの再マッチや
        // unlistedWindows 処理が掴まないよう claim 済みにしておく
        session.claimedIDs =
            Set(plan.placements.map(\.windowID)).union(plan.closeTargets.map(\.windowID))
        session.deadline = Date().addingTimeInterval(config.windowWaitTimeout)
        session.preferredFocusEntryIndex = plan.preferredFocusEntryIndex
        self.session = session

        // apply の completion は同期的に呼ばれることがあるため、
        // セットアップが終わるまで finish を保留するガードを立てる
        session.pendingApplies += 1

        // closeWindows は「必ず閉じる」ため配置より先に実行する
        if !plan.closeTargets.isEmpty {
            for target in plan.closeTargets {
                AXWindow.resolve(windowID: target.windowID, pid: target.pid)?.close()
            }
            NSLog(
                "[jinrai.windowLayouts] closeWindows でウィンドウを閉じました: %d",
                plan.closeTargets.count)
        }

        for placement in plan.placements {
            guard let ax = AXWindow.resolve(windowID: placement.windowID, pid: placement.pid)
            else { continue }
            if placement.needsUnminimize {
                ax.unminimize()
            }
            applyFrame(
                placement.frame, to: ax, entryIndex: placement.entryIndex,
                windowID: placement.windowID, pid: placement.pid, session: session)
        }
        if let focusIndex = plan.focusEntryIndex,
            let placement = plan.placements.first(where: { $0.entryIndex == focusIndex })
        {
            session.focusTarget = (focusIndex, placement.windowID, placement.pid)
        }

        launchPendingApps(indices: plan.pendingLaunchIndices, session: session)

        session.pendingApplies -= 1
        finishIfSettled(session)
    }

    /// カーソル追従は個別移動ではなく最後のフォーカス確定時に1回だけ行う
    private func applyFrame(
        _ frame: CGRect, to window: AXWindow, entryIndex: Int, windowID: UInt32, pid: pid_t,
        session: Session
    ) {
        session.pendingApplies += 1
        WindowFrameApplier.apply(frame: frame, to: window, moveCursor: false) {
            [weak self, weak session] applied in
            guard let self, let session, self.session === session else { return }
            if applied {
                session.appliedTargets.append((entryIndex, windowID, pid))
            }
            session.pendingApplies -= 1
            self.finishIfSettled(session)
        }
    }

    // MARK: - launch とウィンドウ出現待ち

    private func launchPendingApps(indices: [Int], session: Session) {
        guard !indices.isEmpty else { return }
        var launchable: [Int] = []
        var launchedBundleIDs: Set<String> = []
        var openedURLs: Set<String> = []
        for index in indices {
            let entry = session.layout.windows[index]
            switch entry.launch {
            case .none:
                continue
            case .newWindowURL(let urlString):
                if openedURLs.contains(urlString) {
                    launchable.append(index)
                    continue
                }
                guard let url = URL(string: urlString) else {
                    NSLog("[jinrai.windowLayouts] URL が不正です: %@", urlString)
                    continue
                }
                // アプリをアクティブ化せず URL イベントだけ送る
                // (既存ウィンドウが一瞬前面に出るのを防ぐ。Application Hints と同じ)
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                NSWorkspace.shared.open(url, configuration: configuration)
                openedURLs.insert(urlString)
                launchable.append(index)
            case .app:
                if launchedBundleIDs.contains(entry.bundleID) {
                    launchable.append(index)
                    continue
                }
                guard
                    let appURL = NSWorkspace.shared.urlForApplication(
                        withBundleIdentifier: entry.bundleID)
                else {
                    NSLog("[jinrai.windowLayouts] アプリが見つかりません: %@", entry.bundleID)
                    continue
                }
                NSWorkspace.shared.openApplication(
                    at: appURL, configuration: NSWorkspace.OpenConfiguration())
                launchedBundleIDs.insert(entry.bundleID)
                launchable.append(index)
            }
        }
        session.pendingLaunchIndices = launchable
        guard !launchable.isEmpty else { return }
        // ピッカー経由では直前の close() で eventTap.stop() 済みだが、stop() の遅延破棄は
        // 同一 run loop turn しか守れず、出現待ちの間に押されたキーの行き先が失われる。
        // tap を維持してキーを保持し、フォーカス確定後に新しいウィンドウへ再送する
        // (直接ホットキー起動では tap が無いため何もしない)
        if eventTap.isRunning {
            eventTap.holdKeysForNextStart(timeout: config.windowWaitTimeout + 1)
            session.didHoldKeys = true
        }
        startWaitTimer(session)
    }

    /// 起動したアプリのウィンドウ出現を 0.1s ポーリングし、出現次第配置する。
    /// タイマーはセッション破棄時に invalidate されるため self.session を参照してよい
    private func startWaitTimer(_ session: Session) {
        waitTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let session = self.session else { return }
                let candidates = WindowEnumerator.orderedWindows()
                for index in session.pendingLaunchIndices {
                    let entry = session.layout.windows[index]
                    guard
                        let matched = WindowLayoutPlanner.match(
                            entry: entry, in: candidates, excluding: session.claimedIDs),
                        let frame = WindowLayoutPlanner.resolveFrame(
                            entry: entry, screens: session.screens, windowFrame: matched.frame),
                        let ax = AXWindow.resolve(windowID: matched.id, pid: matched.pid)
                    else { continue }
                    session.claimedIDs.insert(matched.id)
                    session.pendingLaunchIndices.removeAll { $0 == index }
                    // focus=true 指定があればそれを優先し、未指定なら従来どおり最後のエントリを優先。
                    // applyFrame の completion は同期的に呼ばれることがあり、最後の1件では
                    // そのまま finishIfSettled まで到達するため、focusTarget は先に確定させる
                    if index == session.preferredFocusEntryIndex
                        || (session.preferredFocusEntryIndex == nil
                            && index >= (session.focusTarget?.entryIndex ?? -1))
                    {
                        session.focusTarget = (index, matched.id, matched.pid)
                    }
                    self.applyFrame(
                        frame, to: ax, entryIndex: index, windowID: matched.id, pid: matched.pid,
                        session: session)
                }
                if session.pendingLaunchIndices.isEmpty {
                    self.waitTimer?.invalidate()
                    self.waitTimer = nil
                    self.finishIfSettled(session)
                } else if Date() > session.deadline {
                    for index in session.pendingLaunchIndices {
                        NSLog(
                            "[jinrai.windowLayouts] ウィンドウの出現がタイムアウトしました: %@",
                            session.layout.windows[index].bundleID)
                    }
                    session.pendingLaunchIndices.removeAll()
                    self.waitTimer?.invalidate()
                    self.waitTimer = nil
                    self.finishIfSettled(session)
                }
            }
        }
    }

    // MARK: - 完了処理

    /// launch 待ちと非同期 apply がすべて解決したらフォーカスを確定してセッションを閉じる
    private func finishIfSettled(_ session: Session) {
        // applyFrame の completion が同期的に finish まで到達した後、呼び元(出現待ちタイマー等)が
        // 破棄済みセッションで再度呼ぶことがあるため、現行セッションのみ処理する
        guard self.session === session else { return }
        guard session.pendingLaunchIndices.isEmpty, session.pendingApplies == 0 else { return }
        defer { cancelSession() }
        // 出現待ちの間に保持したキー(didHoldKeys 時のみ)。フォーカス確定後に届け先を決める
        let heldKeys = session.didHoldKeys ? eventTap.drainHeldKeyEvents() : []
        guard let target = session.focusTarget,
            let ax = AXWindow.resolve(windowID: target.windowID, pid: target.pid)
        else {
            // フォーカス対象がいなくても未記述ウィンドウ処理は行う
            // (windows 省略時など、unlistedWindows だけのレイアウトを成立させるため)。
            // レイアウト自体は適用済みなので JinraiMode のコンボも継続する
            handleUnlistedWindows(session)
            if session.jinraiMode {
                // 保持キーは次画面(スポットライト)への先行入力として持ち越す
                eventTap.stashKeyEvents(heldKeys)
                onJinraiModeApply?(nil)
            } else if session.didHoldKeys {
                // 届け先が無いため保持キーは破棄し、tap を解放してキーボードを返す
                eventTap.stop()
            }
            return
        }
        // 現アクティブアプリのウィンドウには AXRaise が勝てないため、
        // 先にフォーカス対象をアクティブ化して前面権を奪ってから残りを raise する。
        // WindowServerFocus は WindowServer 側で同期的に front process を切り替えるので、
        // activate() の非同期完了を待たずに後続の raise が有効になる
        WindowServerFocus.focus(windowID: target.windowID, pid: target.pid)
        ax.focus()
        bringAppliedWindowsToFront(session, focusTarget: target)
        handleUnlistedWindows(session)
        if cursorAfterMove, let frame = ax.frame {
            Mouse.moveToCenter(of: frame)
        }
        if session.jinraiMode {
            // 保持キーは次画面(スポットライト)への先行入力として持ち越す。
            // tap は次画面の start() が引き継ぐため stop しない
            eventTap.stashKeyEvents(heldKeys)
            onJinraiModeApply?((target.windowID, target.pid))
        } else {
            // 出現待ちの間に押されたキーはフォーカスしたウィンドウへ再送する
            if !heldKeys.isEmpty {
                EventTap.postKeyEvents(heldKeys, toPid: target.pid)
            }
            if session.didHoldKeys {
                eventTap.stop()
            }
        }
    }

    /// レイアウト対象全体を既存ウィンドウより前面へ出し、最後にフォーカス対象を最前面にする
    private func bringAppliedWindowsToFront(
        _ session: Session, focusTarget: (entryIndex: Int, windowID: UInt32, pid: pid_t)
    ) {
        var targets = session.appliedTargets
            .sorted { $0.entryIndex < $1.entryIndex }
            .reduce(into: [(entryIndex: Int, windowID: UInt32, pid: pid_t)]()) {
                result, target in
                guard !result.contains(where: { $0.windowID == target.windowID }) else { return }
                result.append(target)
            }
        targets.removeAll { $0.windowID == focusTarget.windowID }
        targets.append(focusTarget)
        // ここでは AXRaise のみを使う(フォーカス対象のアクティブ化は呼び出し側で先に完了済み)。
        // activate() や SkyLight の front process 化を連続発行すると、アプリ自身が
        // 非同期で自分のウィンドウを raise し直し、後続の raise 結果を上書きしてしまう
        // (Chrome 等の重いアプリで顕著)。AXRaise 単体で非アクティブアプリの
        // ウィンドウより前面へ出せることは実機検証済み
        for target in targets {
            AXWindow.resolve(windowID: target.windowID, pid: target.pid)?.raise()
        }
    }

    /// 配置対象に選ばれなかったオンスクリーン標準ウィンドウを、設定に応じて閉じる/一律配置する。
    /// raise せずベストエフォートで処理するため、直前に確定した z-order は壊さない
    private func handleUnlistedWindows(_ session: Session) {
        guard let action = session.layout.unlistedWindows else { return }
        let standardWindows = WindowEnumerator.standardWindows(from: WindowEnumerator.orderedWindows())
        let targets = WindowLayoutPlanner.unlistedWindows(
            from: standardWindows, keeping: session.claimedIDs)
        guard !targets.isEmpty else { return }
        switch action {
        case .close:
            for target in targets {
                AXWindow.resolve(windowID: target.id, pid: target.pid)?.close()
            }
            NSLog(
                "[jinrai.windowLayouts] 未記述ウィンドウを閉じました: %d",
                targets.count)
        case .place(let screenUUID, let area):
            // screen 省略時は各ウィンドウが現在いるディスプレイへ配置するため、1枚ずつ解決する
            for target in targets {
                guard
                    let frame = WindowLayoutPlanner.resolveFrame(
                        screenUUID: screenUUID, area: area, screens: session.screens,
                        windowFrame: target.frame),
                    let ax = AXWindow.resolve(windowID: target.id, pid: target.pid)
                else { continue }
                WindowFrameApplier.apply(frame: frame, to: ax, moveCursor: false) { _ in }
            }
            NSLog(
                "[jinrai.windowLayouts] 未記述ウィンドウを配置しました: %d",
                targets.count)
        }
    }

    // MARK: - スナップショット収集

    private func snapshotScreens() -> [WindowLayoutPlanner.ScreenInput] {
        // フォールバック先の「メイン」はプライマリディスプレイ(メニューバーのある画面)
        NSScreen.screens.enumerated().map { index, screen in
            WindowLayoutPlanner.ScreenInput(
                uuid: ScreenUtil.uuid(of: screen),
                visibleFrame: ScreenUtil.visibleFrame(of: screen),
                isMain: index == 0
            )
        }
    }

    /// 最小化ウィンドウは CGWindowList(オンスクリーン)に載らないため AX から合成する
    private func collectMinimizedWindows(
        for layout: WindowLayoutsConfig.Layout
    ) -> [WindowInfo] {
        var result: [WindowInfo] = []
        for bundleID in Set(layout.windows.map(\.bundleID) + layout.closeWindows.map(\.bundleID)) {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                for window in AXWindow.windows(pid: app.processIdentifier)
                where window.isMinimized && window.isStandard {
                    result.append(
                        WindowInfo(
                            id: window.windowID, pid: window.pid,
                            bundleID: bundleID, title: window.title))
                }
            }
        }
        return result
    }
}
