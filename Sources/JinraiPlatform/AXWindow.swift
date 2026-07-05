import AppKit
import ApplicationServices
import CGSPrivate

/// AXUIElement によるウィンドウ操作ラッパー(元 hs.window 相当)。
/// 座標は CG/AX 準拠の top-left 原点。
public struct AXWindow {
    public let element: AXUIElement
    public let pid: pid_t
    public let windowID: CGWindowID

    /// 無応答アプリで AX 呼び出しがブロックしないためのタイムアウト(秒)
    static let messagingTimeout: Float = 0.25

    public init(element: AXUIElement, pid: pid_t, windowID: CGWindowID) {
        self.element = element
        self.pid = pid
        self.windowID = windowID
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    }

    // MARK: - 取得

    /// アプリの全ウィンドウ(AX)。windowID の解決込み
    public static func windows(pid: pid_t) -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
                == .success,
            let elements = value as? [AXUIElement]
        else { return [] }
        let windows = elements.compactMap { element -> AXWindow? in
            guard let id = windowID(of: element) else { return nil }
            return AXWindow(element: element, pid: pid, windowID: id)
        }
        // 別 Space ウィンドウのフォーカス用に、観測した AX 要素を蓄積しておく
        WindowRegistry.shared.register(windows)
        return windows
    }

    /// CGWindowID との対応付け(非公開 _AXUIElementGetWindow)
    public static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: UInt32 = 0
        guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// windowID から AXWindow を解決
    public static func resolve(windowID: CGWindowID, pid: pid_t) -> AXWindow? {
        windows(pid: pid).first { $0.windowID == windowID }
    }

    // MARK: - 属性

    public var title: String {
        attribute(kAXTitleAttribute) as? String ?? ""
    }

    public var isMinimized: Bool {
        attribute(kAXMinimizedAttribute) as? Bool ?? false
    }

    /// ネイティブフルスクリーン状態(kAXFullScreenAttribute は公開ヘッダにないため文字列で指定)
    public var isFullScreen: Bool {
        attribute("AXFullScreen") as? Bool ?? false
    }

    /// 標準ウィンドウか(元 isStandardWindow: subrole が AXStandardWindow)
    public var isStandard: Bool {
        (attribute(kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole
    }

    public var frame: CGRect? {
        guard
            let positionValue = attribute(kAXPositionAttribute),
            let sizeValue = attribute(kAXSizeAttribute)
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    // MARK: - 操作

    /// アニメなし即時の移動+リサイズ。
    /// サイズ→位置→サイズの順で設定すると Chrome 等のズレが減る
    public func setFrame(_ frame: CGRect) {
        setSize(frame.size)
        setPosition(frame.origin)
        setSize(frame.size)
    }

    public func setPosition(_ position: CGPoint) {
        var value = position
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
    }

    public func setSize(_ size: CGSize) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
    }

    /// ウィンドウをフォーカス(元 hs.window:focus())
    public func focus() {
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    public func minimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    public func setFullScreen(_ value: Bool) {
        AXUIElementSetAttributeValue(
            element, "AXFullScreen" as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    public func close() {
        var button: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element, kAXCloseButtonAttribute as CFString, &button) == .success
        else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    private func attribute(_ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}
