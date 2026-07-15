import Foundation

/// フォーカス履歴の純粋ロジック(元 focus_history.lua)。
/// Window はプラットフォーム層のウィンドウ型(AXWindow 等)を想定したジェネリック。
/// ウィンドウの属性取得・可視判定はクロージャで注入し、ユニットテスト可能にする。
public final class FocusHistoryLogic<Window> {
    public static var maxHistorySize: Int { 20 }

    private var history: [Window] = []
    private var current: Window?
    private var switching = false

    private let windowID: (Window) -> UInt32
    /// bundleID ?? appName(元 appKeyOfWindow)
    private let appKey: (Window) -> String?
    private let isVisible: (Window) -> Bool
    /// アプリの AX ウィンドウ一覧に列挙されているか。
    /// 非選択のネイティブタブのウィンドウは列挙から消える(実機検証)ため、
    /// タブ切替と別ウィンドウへの切替の判別に使う
    private let isListedInApp: (Window) -> Bool
    /// macOS ネイティブタブ利用アプリの bundleID / アプリ名(空なら補正なし)
    private let syncTargetApps: Set<String>

    public init(
        syncTargetApps: Set<String> = [],
        windowID: @escaping (Window) -> UInt32,
        appKey: @escaping (Window) -> String?,
        isVisible: @escaping (Window) -> Bool,
        isListedInApp: @escaping (Window) -> Bool
    ) {
        self.syncTargetApps = syncTargetApps
        self.windowID = windowID
        self.appKey = appKey
        self.isVisible = isVisible
        self.isListedInApp = isListedInApp
    }

    public var hasSyncTargets: Bool { !syncTargetApps.isEmpty }

    public func isSyncTargetWindow(_ window: Window?) -> Bool {
        guard let window, !syncTargetApps.isEmpty, let key = appKey(window) else { return false }
        return syncTargetApps.contains(key)
    }

    /// 同一アプリ内のネイティブタブ切替は履歴に積まない(元 shouldPromotePrevious)。
    /// 遷移元がウィンドウ一覧に残っていれば別ウィンドウへの切替なので通常どおり積む
    func shouldPromotePrevious(from: Window?, to: Window?) -> Bool {
        guard !syncTargetApps.isEmpty else { return true }
        guard let from, let to,
            let fromKey = appKey(from), let toKey = appKey(to)
        else { return true }
        if fromKey != toKey { return true }
        if !syncTargetApps.contains(toKey) { return true }
        return isListedInApp(from)
    }

    /// フォーカス変化を記録(元 updateWindowState)
    public func updateWindowState(_ window: Window?) {
        guard !switching else { return }
        if let current,
            windowID(current) != window.map(windowID),
            shouldPromotePrevious(from: current, to: window)
        {
            history.append(current)
            if history.count > Self.maxHistorySize {
                history.removeFirst()
            }
        }
        current = window
    }

    /// 直前のウィンドウへ戻る対象を決定し、履歴を更新する(元 focusBack)。
    /// 返されたウィンドウのフォーカス操作は呼び出し側(プラットフォーム層)が行う。
    public func focusBack(focused: Window?) -> Window? {
        if hasSyncTargets, isSyncTargetWindow(focused) {
            updateWindowState(focused)
        }

        var target: Window?
        while let candidate = history.popLast() {
            if isVisible(candidate), windowID(candidate) != current.map(windowID) {
                target = candidate
                break
            }
        }
        guard let target else { return nil }

        if let current {
            history.append(current)
            if history.count > Self.maxHistorySize {
                history.removeFirst()
            }
        }
        current = target
        return target
    }

    /// 履歴を変更せず直前ウィンドウを返す(元 getPreviousWindow)
    public func previousWindow() -> Window? {
        for window in history.reversed() {
            if isVisible(window), windowID(window) != current.map(windowID) {
                return window
            }
        }
        return nil
    }

    /// フォーカス操作中の自己記録抑制(元 switching フラグ)
    public func withSwitching<T>(_ body: () throws -> T) rethrows -> T {
        switching = true
        defer { switching = false }
        return try body()
    }

    public func teardown() {
        history = []
        current = nil
    }
}
