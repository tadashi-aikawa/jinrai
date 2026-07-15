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
    /// ウィンドウがいずれかの Space に属しているか。
    /// 非選択のネイティブタブと閉じられたウィンドウは Space 所属を失う(実機検証)ため、
    /// 同一アプリ内のタブ切替と別ウィンドウへの切替の判別に使う。
    /// ただし Space 所属の反映は AX 通知の発火時点では間に合わないことがあるため、
    /// 記録時(shouldPromotePrevious)の判定はベストエフォートとし、
    /// 取り出し時(focusBack / previousWindow)にも同じ判定で候補を除外する
    private let isOnAnySpace: (Window) -> Bool

    public init(
        windowID: @escaping (Window) -> UInt32,
        appKey: @escaping (Window) -> String?,
        isVisible: @escaping (Window) -> Bool,
        isOnAnySpace: @escaping (Window) -> Bool
    ) {
        self.windowID = windowID
        self.appKey = appKey
        self.isVisible = isVisible
        self.isOnAnySpace = isOnAnySpace
    }

    /// 同一アプリ内のネイティブタブ切替は履歴に積まない(元 shouldPromotePrevious)。
    /// 遷移元が Space 所属を保っていれば別ウィンドウへの切替なので通常どおり積む
    func shouldPromotePrevious(from: Window?, to: Window?) -> Bool {
        guard let from, let to,
            let fromKey = appKey(from), let toKey = appKey(to)
        else { return true }
        if fromKey != toKey { return true }
        return isOnAnySpace(from)
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
        // フォーカスイベントの取り漏れに備え、現在のフォーカスで履歴を補正する
        // (nil は AX 取得の一時失敗の可能性があるため補正しない)
        if let focused {
            updateWindowState(focused)
        }

        var target: Window?
        while let candidate = history.popLast() {
            if isVisible(candidate), isOnAnySpace(candidate),
                windowID(candidate) != current.map(windowID)
            {
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
            if isVisible(window), isOnAnySpace(window),
                windowID(window) != current.map(windowID)
            {
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
