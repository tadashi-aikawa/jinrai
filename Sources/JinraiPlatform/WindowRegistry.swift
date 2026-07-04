import AppKit
import ApplicationServices

/// 一度観測したウィンドウの AX 要素キャッシュ。
/// AX API は別 Space のウィンドウを列挙できない(macOS の制限)が、列挙済みの
/// AX 要素は Space をまたいでも有効で、focus() すると macOS が対象の Space へ
/// 自動的に切り替える。別 Space ウィンドウのフォーカスはこの経路を最優先で使う
/// (元 hs.window.filter がウィンドウをキャッシュしていた仕組みの代替)。
/// AX 列挙(AXWindow.windows / WindowEnumerator.focusedWindow)のたびに自動で蓄積される
public final class WindowRegistry: @unchecked Sendable {
    public static let shared = WindowRegistry()
    private let lock = NSLock()
    private var cache: [CGWindowID: AXWindow] = [:]

    private init() {}

    /// 観測したウィンドウを蓄積する(同一 ID は最新の要素で上書き)
    public func register(_ windows: [AXWindow]) {
        lock.lock()
        defer { lock.unlock() }
        for win in windows {
            cache[win.windowID] = win
        }
    }

    /// キャッシュから解決。要素が無効(ウィンドウが閉じた等)なら破棄して nil
    public func window(for id: CGWindowID) -> AXWindow? {
        lock.lock()
        let cached = cache[id]
        lock.unlock()
        guard let cached else { return nil }
        guard cached.frame != nil else {
            lock.lock()
            cache.removeValue(forKey: id)
            lock.unlock()
            return nil
        }
        return cached
    }

    /// 現在 Space に見えているウィンドウのアプリを AX 列挙してキャッシュを温める
    /// (起動直後や Space 切替直後に呼ぶ。列挙結果は register 経由で蓄積される)
    public func warmUpCurrentSpace() {
        let pids = Set(WindowEnumerator.orderedWindows().map(\.pid))
        for pid in pids {
            _ = AXWindow.windows(pid: pid)
        }
    }
}
