import CoreGraphics

/// マウスカーソル操作(元 hs.mouse.absolutePosition)
public enum Mouse {
    /// カーソルを移動する(座標は CG 準拠の top-left 原点)
    public static func move(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        // Warp 直後のクリック座標ズレを防ぐ
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// カーソルを frame の中央へ
    public static func moveToCenter(of frame: CGRect) {
        move(to: CGPoint(x: frame.midX, y: frame.midY))
    }
}
