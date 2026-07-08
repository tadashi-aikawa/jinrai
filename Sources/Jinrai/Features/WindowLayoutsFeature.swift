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
    private var hotkeys: [Hotkey] = []
    var onJinraiModeApply: ((_ windowID: UInt32, _ pid: pid_t) -> Void)?
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

    init(config: WindowLayoutsConfig, cursorAfterMove: Bool) {
        self.config = config
        self.cursorAfterMove = cursorAfterMove

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
            let picker = WindowLayoutPicker(config: config)
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
            onScreenWindows: WindowEnumerator.orderedWindows(),
            minimizedWindows: collectMinimizedWindows(for: layout),
            runningBundleIDs: runningBundleIDs(for: layout),
            screens: screens
        )
        guard !plan.placements.isEmpty || !plan.pendingLaunchIndices.isEmpty else {
            NSLog("[jinrai.windowLayouts] '%@' にマッチするウィンドウがありません", layout.name)
            if jinraiMode {
                onJinraiModeCancel?()
            }
            return
        }

        let session = Session(layout: layout, screens: screens, jinraiMode: jinraiMode)
        session.claimedIDs = Set(plan.placements.map(\.windowID))
        session.deadline = Date().addingTimeInterval(config.windowWaitTimeout)
        session.preferredFocusEntryIndex = plan.preferredFocusEntryIndex
        self.session = session

        // apply の completion は同期的に呼ばれることがあるため、
        // セットアップが終わるまで finish を保留するガードを立てる
        session.pendingApplies += 1

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
        for index in indices {
            let bundleID = session.layout.windows[index].bundleID
            if launchedBundleIDs.contains(bundleID) {
                launchable.append(index)
                continue
            }
            guard
                let appURL = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: bundleID)
            else {
                NSLog("[jinrai.windowLayouts] アプリが見つかりません: %@", bundleID)
                continue
            }
            NSWorkspace.shared.openApplication(
                at: appURL, configuration: NSWorkspace.OpenConfiguration())
            launchedBundleIDs.insert(bundleID)
            launchable.append(index)
        }
        session.pendingLaunchIndices = launchable
        guard !launchable.isEmpty else { return }
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
                            entry: entry, screens: session.screens),
                        let ax = AXWindow.resolve(windowID: matched.id, pid: matched.pid)
                    else { continue }
                    session.claimedIDs.insert(matched.id)
                    session.pendingLaunchIndices.removeAll { $0 == index }
                    self.applyFrame(
                        frame, to: ax, entryIndex: index, windowID: matched.id, pid: matched.pid,
                        session: session)
                    // focus=true 指定があればそれを優先し、未指定なら従来どおり最後のエントリを優先
                    if index == session.preferredFocusEntryIndex
                        || (session.preferredFocusEntryIndex == nil
                            && index >= (session.focusTarget?.entryIndex ?? -1))
                    {
                        session.focusTarget = (index, matched.id, matched.pid)
                    }
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
        guard session.pendingLaunchIndices.isEmpty, session.pendingApplies == 0 else { return }
        defer { cancelSession() }
        guard let target = session.focusTarget,
            let ax = AXWindow.resolve(windowID: target.windowID, pid: target.pid)
        else {
            if session.jinraiMode {
                onJinraiModeCancel?()
            }
            return
        }
        bringAppliedWindowsToFront(session, focusTarget: target)
        ax.focus()
        if cursorAfterMove, let frame = ax.frame {
            Mouse.moveToCenter(of: frame)
        }
        if session.jinraiMode {
            onJinraiModeApply?(target.windowID, target.pid)
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
        for target in targets {
            AXWindow.resolve(windowID: target.windowID, pid: target.pid)?.focus()
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

    private func runningBundleIDs(for layout: WindowLayoutsConfig.Layout) -> Set<String> {
        Set(
            Set(layout.windows.map(\.bundleID)).filter {
                !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
            })
    }

    /// 最小化ウィンドウは CGWindowList(オンスクリーン)に載らないため AX から合成する
    private func collectMinimizedWindows(
        for layout: WindowLayoutsConfig.Layout
    ) -> [WindowInfo] {
        var result: [WindowInfo] = []
        for bundleID in Set(layout.windows.map(\.bundleID)) {
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
