import AppKit

/// オーバーレイの重なり順(値が大きいほど前面)。
/// border < logo < combo < hints を保証する。
public enum OverlayLevel: Int, Sendable {
    case border = 0  // フォーカスborder(最背面)
    case logo = 1  // JINRAIロゴ
    case combo = 2  // JINRAI COMBO(キャラ+テキスト。ロゴより前面)
    case hints = 3  // Window/Area/Application Hints(最前面)
}

/// オーバーレイ描画用の透明ボーダレスウィンドウ(元 hs.canvas 相当の基盤)。
/// 全 Space に表示され、マウスイベントを透過する。
@MainActor
public final class OverlayWindow: NSWindow {
    public override var canBecomeKey: Bool { true }

    /// frame は CG/AX 準拠の top-left 座標で渡す。
    /// level は OverlayLevel で明示し、orderFront のタイミングに依らず前後を固定する
    public init(frame: CGRect, level overlayLevel: OverlayLevel) {
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
            rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + overlayLevel.rawValue)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        // orderFront のたびにシステムが出現アニメーション(スケールイン)をかけ、
        // 描画済みの枠線等が内側からスライドして見えるため無効化する
        // (Reduce Motion 有効時に発生しないのはこの演出がシステム側のものだから)
        animationBehavior = .none

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
