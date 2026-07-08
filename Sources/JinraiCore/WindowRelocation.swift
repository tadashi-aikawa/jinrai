import CoreGraphics

/// 新規ウィンドウを基準ディスプレイ内へ移動するための配置計算。
/// 座標系は CG/AX 準拠の top-left 原点。サイズは常に維持する。
public enum WindowRelocation {
    /// ターゲット visibleFrame との重なりがこの比率以上なら「内にある」とみなし移動しない
    public static let insideOverlapThreshold: CGFloat = 0.5

    /// 移動判定の許容誤差(pt)。移動後の frame が元とほぼ同じなら移動不要とみなす
    static let tolerance: CGFloat = 0.5

    /// 移動が必要なら移動後の frame(サイズ不変)を返す。不要なら nil。
    /// - Parameters:
    ///   - window: 新規ウィンドウの frame
    ///   - targetVisibleFrame: 基準ディスプレイの visibleFrame
    ///   - sourceVisibleFrame: 出現元ディスプレイの visibleFrame(相対位置維持用。nil ならクランプのみ)
    public static func relocatedFrame(
        window: CGRect,
        targetVisibleFrame: CGRect,
        sourceVisibleFrame: CGRect?
    ) -> CGRect? {
        guard Geometry.isValidFrame(window), Geometry.isValidFrame(targetVisibleFrame) else {
            return nil
        }

        // 大部分がターゲット内なら移動しない(数pxのはみ出しで動かさない)
        let overlap = Geometry.intersect(window, targetVisibleFrame).map(Geometry.area) ?? 0
        if overlap / Geometry.area(window) >= insideOverlapThreshold {
            return nil
        }

        // 出現元ディスプレイ内での余白比率を維持してターゲットへ写像
        var origin = window.origin
        if let source = sourceVisibleFrame, Geometry.isValidFrame(source) {
            origin.x =
                targetVisibleFrame.minX
                + ratio(position: window.minX, min: source.minX, room: source.width - window.width)
                * max(0, targetVisibleFrame.width - window.width)
            origin.y =
                targetVisibleFrame.minY
                + ratio(position: window.minY, min: source.minY, room: source.height - window.height)
                * max(0, targetVisibleFrame.height - window.height)
        }

        // ターゲット内へクランプ。visibleFrame より大きい軸は top-left 揃え
        origin.x = clamp(
            origin.x, min: targetVisibleFrame.minX, max: targetVisibleFrame.maxX - window.width)
        origin.y = clamp(
            origin.y, min: targetVisibleFrame.minY, max: targetVisibleFrame.maxY - window.height)

        let relocated = CGRect(origin: origin, size: window.size)
        guard !Geometry.frameNear(relocated, window, tolerance: tolerance) else { return nil }
        return relocated
    }

    /// 余白内での正規化位置(0〜1)。余白がない(ウィンドウの方が大きい)場合は 0
    private static func ratio(position: CGFloat, min: CGFloat, room: CGFloat) -> CGFloat {
        guard room > 0 else { return 0 }
        return Swift.min(Swift.max((position - min) / room, 0), 1)
    }

    /// max < min(ウィンドウの方が大きい)場合は min を優先(タイトルバーの可視性を保証)
    private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(Swift.min(value, max), min)
    }
}
