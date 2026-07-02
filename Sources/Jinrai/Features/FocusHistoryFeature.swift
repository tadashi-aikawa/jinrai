import AppKit
import JinraiCore
import JinraiPlatform

/// フォーカス履歴(元 focus_history.lua のプラットフォーム結線)。
/// FocusBack と WindowHints で共有する。
@MainActor
final class FocusHistoryFeature {
    let logic: FocusHistoryLogic<AXWindow>
    private let observer = FocusObserver()
    private var nativeTabsTimer: Timer?

    init(macosNativeTabs: MacosNativeTabsConfig) {
        let syncTargets = Set(macosNativeTabs.apps)
        logic = FocusHistoryLogic(
            syncTargetApps: syncTargets,
            windowID: { $0.windowID },
            appKey: { Self.appKey(of: $0) },
            isVisible: { Self.isVisible($0) }
        )

        observer.onFocusChanged = { [weak self] window in
            self?.logic.updateWindowState(window)
        }
        observer.start()

        // ネイティブタブアプリはタブ切替で AX 通知が飛ばないことがあるため定期補正
        if !syncTargets.isEmpty {
            let interval = max(macosNativeTabs.stateSyncInterval, 0.1)
            nativeTabsTimer = Timer.scheduledTimer(
                withTimeInterval: interval, repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let focused = WindowEnumerator.focusedWindow() else { return }
                    if self.logic.isSyncTargetWindow(focused) {
                        self.logic.updateWindowState(focused)
                    }
                }
            }
        }
    }

    /// 直前のウィンドウへフォーカスを戻す。対象がなければ nil
    @discardableResult
    func focusBack(centerCursor: Bool) -> AXWindow? {
        let focused = WindowEnumerator.focusedWindow()
        guard let target = logic.focusBack(focused: focused) else { return nil }
        logic.withSwitching {
            target.focus()
        }
        if centerCursor, let frame = target.frame {
            Mouse.moveToCenter(of: frame)
        }
        return target
    }

    func previousWindow() -> AXWindow? {
        logic.previousWindow()
    }

    func teardown() {
        nativeTabsTimer?.invalidate()
        nativeTabsTimer = nil
        observer.stop()
        logic.teardown()
    }

    static func appKey(of window: AXWindow) -> String? {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return nil }
        return app.bundleIdentifier ?? app.localizedName
    }

    static func isVisible(_ window: AXWindow) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: window.pid), !app.isTerminated,
            !app.isHidden
        else { return false }
        guard !window.isMinimized, let frame = window.frame else { return false }
        return frame.width > 0 && frame.height > 0
    }
}
