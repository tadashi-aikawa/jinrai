import CoreGraphics
import Foundation

/// JinraiMode 演出の純粋ロジック(元 window_hints.lua の JinraiMode 関数群)
public enum JinraiModeLogic {
    /// アニメーションの1ステップ間隔(元 0.02s の doEvery)
    public static var animationInterval: Double { 0.02 }

    /// コンボ数 → キャラクター画像 index(jinrai0〜9.webp)。
    /// 0 は開始直後、1〜9 をコンボ数で巡回
    public static func comboImageIndex(count: Int) -> Int {
        count <= 0 ? 0 : ((count - 1) % 9) + 1
    }

    public static func animationSteps(duration: Double) -> Int {
        max(0, Int((duration / animationInterval).rounded(.up)))
    }

    /// 進捗(0〜1)に easing を適用
    public static func animationProgress(
        _ progress: Double, easing: JinraiModeConfig.Easing
    ) -> Double {
        let t = min(max(progress, 0), 1)
        switch easing {
        case .linear:
            return t
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        }
    }

    /// コンボキャラクターの基準サイズ(元 comboCanvasLayout の baseSize)
    public static func comboBaseSize(screenFrame: CGRect) -> CGFloat {
        min(560, screenFrame.width * 0.46, screenFrame.height * 0.7)
    }

    /// COMBO テキストのフォントサイズ(数字, "COMBO!")
    public static func comboTextSizes(baseSize: CGFloat) -> (number: CGFloat, label: CGFloat) {
        (
            number: max(72, (baseSize * 0.18).rounded(.down)),
            label: max(34, (baseSize * 0.075).rounded(.down))
        )
    }

    /// 演出の中心座標(activeWindow ならフォーカスウィンドウ中央、なければ画面中央)
    public static func displayCenter(
        position: String, windowFrame: CGRect?, screenFrame: CGRect
    ) -> CGPoint {
        if position == "activeWindow", let windowFrame {
            return CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        }
        return CGPoint(x: screenFrame.midX, y: screenFrame.midY)
    }

    /// COMBO テキストの Y 位置(top-left 座標)。
    /// ロゴ上端の 36px 上にテキスト下端を合わせ、画面上端 +16 でクランプ(元 COMBO_LOGO_GAP=-36)
    public static func comboTextTop(
        screenFrame: CGRect, center: CGPoint, logoSize: CGFloat, textHeight: CGFloat
    ) -> CGFloat {
        let logoTop = center.y - logoSize / 2
        return max(screenFrame.minY + 16, logoTop + 36 - textHeight)
    }
}
