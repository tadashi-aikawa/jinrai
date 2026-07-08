import AppKit

/// キー入力を受けるオーバーレイ用の nonactivating パネル(Spotlight 型)。
/// OverlayWindow と同じ透明ボーダレス構成だが、NSPanel + .nonactivatingPanel により
/// アプリをアクティブ化せずにキーウィンドウになれる。
/// これによりパネルを閉じたときに macOS が直前のアクティブアプリへ
/// アクティブ状態を返す(=そのウィンドウが raise される)副作用を避けられる。
@MainActor
public final class OverlayPanel: NSPanel {
    public override var canBecomeKey: Bool { true }

    /// frame は CG/AX 準拠の top-left 座標で渡す
    public init(frame: CGRect, level overlayLevel: OverlayLevel) {
        super.init(
            contentRect: ScreenUtil.toAppKit(frame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + overlayLevel.rawValue)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        contentView = view
    }

    public var rootLayer: CALayer? {
        contentView?.layer
    }
}
