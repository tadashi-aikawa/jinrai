import AppKit
import JinraiCore
import JinraiPlatform

/// フォーカス履歴(元 focus_history.lua のプラットフォーム結線)。
/// FocusBack と WindowHints で共有する。
@MainActor
final class FocusHistoryFeature {
    let logic: FocusHistoryLogic<AXWindow>
    private let observer = FocusObserver()

    init() {
        logic = FocusHistoryLogic(
            windowID: { $0.windowID },
            appKey: { Self.appKey(of: $0) },
            isVisible: { Self.isVisible($0) },
            // 非選択のネイティブタブと閉じられたウィンドウは Space 所属を失う。
            // logic の呼び出しは全てメインスレッド(FocusObserver / 各機能)から行われる
            isOnAnySpace: { window in
                MainActor.assumeIsolated { Spaces.spaceID(of: window.windowID) != nil }
            }
        )

        observer.onFocusChanged = { [weak self] window in
            self?.logic.updateWindowState(window)
        }
        observer.start()
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
