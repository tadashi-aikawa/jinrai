import AppKit
import CoreGraphics
import JinraiCore

/// CGWindowList による Z順ウィンドウ列挙(元 hs.window.orderedWindows / visibleWindows 相当)。
/// frame/title は CGWindowList の辞書から取るため AX の同期 IPC を伴わず高速。
public enum WindowEnumerator {
    /// 現在画面に見えているウィンドウを前面→背面順で返す
    public static func orderedWindows() -> [WindowInfo] {
        windows(options: [.optionOnScreenOnly, .excludeDesktopElements])
    }

    /// 別 Space 含む全ウィンドウ(前面→背面順)
    public static func allSpacesWindows() -> [WindowInfo] {
        windows(options: [.optionAll, .excludeDesktopElements])
    }

    private static func windows(options: CGWindowListOption) -> [WindowInfo] {
        guard
            let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[String: Any]]
        else { return [] }

        let focusedPid = NSWorkspace.shared.frontmostApplication?.processIdentifier

        var results: [WindowInfo] = []
        for info in list {
            guard
                let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                let windowID = info[kCGWindowNumber as String] as? UInt32,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0 else { continue }
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            // メニューバー項目などの小さな面は layer==0 に混ざらないが、念のため空矩形は除外
            guard frame.width > 0, frame.height > 0 else { continue }

            let appName = info[kCGWindowOwnerName as String] as? String ?? ""
            let title = info[kCGWindowName as String] as? String ?? ""
            let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier

            results.append(
                WindowInfo(
                    id: windowID,
                    pid: pid,
                    bundleID: bundleID,
                    appName: appName,
                    title: title,
                    frame: frame,
                    spaceNumber: nil,
                    isFocused: pid == focusedPid && results.isEmpty
                ))
        }
        return results
    }

    /// 標準ウィンドウのみに絞る(AX subrole の確認込み。候補収集用)
    public static func standardWindows(from windows: [WindowInfo]) -> [WindowInfo] {
        var axCache: [pid_t: [AXWindow]] = [:]
        return windows.filter { win in
            let axWindows = axCache[win.pid] ?? AXWindow.windows(pid: win.pid)
            axCache[win.pid] = axWindows
            guard let ax = axWindows.first(where: { $0.windowID == win.id }) else {
                return false
            }
            return ax.isStandard
        }
    }

    /// 別 Space 候補を標準ウィンドウに絞る。AX は他 Space のウィンドウを列挙できない
    /// (macOS の制限)ため、列挙で解決できないものは観測済みの AX 要素キャッシュで
    /// subrole を判定する(キャッシュ済み要素への属性読み取りは Space をまたいでも有効)。
    /// 未観測のウィンドウは候補にしない。常駐アプリの不可視ウィンドウ
    /// (Shottr 等。CGWindowList には載るが AX には現れない)を幽霊候補として
    /// 拾わないためで、キャッシュ済みのみ対象なのは元 hs.window.filter と同じ性質
    public static func offSpaceStandardWindows(from windows: [WindowInfo]) -> [WindowInfo] {
        var axCache: [pid_t: [AXWindow]] = [:]
        return windows.filter { win in
            let axWindows = axCache[win.pid] ?? AXWindow.windows(pid: win.pid)
            axCache[win.pid] = axWindows
            if let ax = axWindows.first(where: { $0.windowID == win.id }) {
                return ax.isStandard
            }
            guard let cached = WindowRegistry.shared.window(for: win.id) else { return false }
            return cached.isStandard
        }
    }

    /// フォーカス中のウィンドウ(AX 経由)
    public static func focusedWindow() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, AXWindow.messagingTimeout)
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
            let element = value
        else { return nil }
        let axElement = element as! AXUIElement
        guard let windowID = AXWindow.windowID(of: axElement) else { return nil }
        let window = AXWindow(element: axElement, pid: app.processIdentifier, windowID: windowID)
        // フォーカスされたウィンドウは別 Space フォーカス用キャッシュにも蓄積する
        WindowRegistry.shared.register([window])
        return window
    }
}
