import AppKit

/// オーバーレイ描画用の透明ボーダレスウィンドウ(元 hs.canvas 相当の基盤)。
/// 全 Space に表示され、マウスイベントを透過する。
@MainActor
public final class OverlayWindow: NSWindow {
    /// frame は CG/AX 準拠の top-left 座標で渡す。
    /// levelOffset で overlay レベルからの重なり順を調整(元 hs.canvas の overlay+1 等)
    public init(frame: CGRect, levelOffset: Int = 0) {
        super.init(
            contentRect: ScreenUtil.toAppKit(frame),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + levelOffset)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        contentView = view
    }

    public var rootLayer: CALayer? {
        contentView?.layer
    }

    /// top-left 座標で位置・サイズを変更
    public func setTopLeftFrame(_ frame: CGRect) {
        setFrame(ScreenUtil.toAppKit(frame), display: false)
    }
}
