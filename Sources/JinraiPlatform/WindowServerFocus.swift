import AppKit
import CGSPrivate

/// 非公開 SkyLight API によるウィンドウフォーカス。
/// AX で列挙できない別 Space のウィンドウも直接フォーカスでき、
/// 別 Space のウィンドウを指定すると macOS がその Space へ自動的に切り替える
/// (Mission Control のショートカット設定に依存しない)
public enum WindowServerFocus {
    /// kCPSUserGenerated: ユーザー操作起因の最前面化(指定ウィンドウのみ raise される)
    private static let userGenerated: UInt32 = 0x200

    public static func focus(windowID: CGWindowID, pid: pid_t) {
        var psn = ProcessSerialNumber()
        guard CGSGetProcessForPID(pid, &psn) == noErr else { return }
        _SLPSSetFrontProcessWithOptions(&psn, windowID, userGenerated)
        makeKeyWindow(&psn, windowID: windowID)
    }

    /// 合成 mouse-down/up のペアを対象ウィンドウ宛に送り key window にする。
    /// CGSEventRecord のバイトレイアウトは AltTab の makeKeyWindow と同一
    /// (https://github.com/NUIKit/CGSInternal/blob/master/CGSEvent.h 由来)
    private static func makeKeyWindow(_ psn: inout ProcessSerialNumber, windowID: CGWindowID) {
        // レコード自体は 0xf8 バイトだが、macOS 14.7.4+ の WindowServer が
        // レコード末尾を越えて読むため余分に確保する
        var bytes = [UInt8](repeating: 0, count: 0x100)
        bytes[0x04] = 0xf8  // レコード長
        bytes[0x3a] = 0x10  // 用途不明フラグ
        // 0x3c: 配送先の CGWindowID(座標ではなく ID でこのウィンドウに届く)
        var wid = windowID
        memcpy(&bytes[0x3c], &wid, MemoryLayout<CGWindowID>.size)
        // 0x20: ウィンドウ相対のクリック座標。枠のすぐ外を指すことで
        // key window にはなるがコンテンツは何もクリックされない
        var point = CGPoint(x: -1, y: -1)
        memcpy(&bytes[0x20], &point, MemoryLayout<CGPoint>.size)
        // mouse-down → mouse-up のペアで「key になった」と認識させる
        bytes[0x08] = 0x01  // kCGEventLeftMouseDown
        SLPSPostEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02  // kCGEventLeftMouseUp
        SLPSPostEventRecordTo(&psn, &bytes)
    }
}
