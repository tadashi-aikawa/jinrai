import CoreGraphics
import Foundation

/// Window Hints ラベルの重なり回避配置。
///
/// 各ラベルは対象ウィンドウの中心に置きたいが、ウィンドウ同士が重なると
/// ラベルも重なって読めなくなる。ソート順に1件ずつ配置し、既配置と重なる場合は
/// 既配置の縁に沿った候補位置から「希望位置に最も近い空き」を選ぶ。
/// 重ならないラベルは希望位置から一切動かない。座標は top-left 原点。
public enum HintLayout {
    public struct Item: Equatable, Sendable {
        public var key: String
        public var center: CGPoint
        public var width: CGFloat
        public var height: CGFloat

        public init(key: String, center: CGPoint, width: CGFloat, height: CGFloat) {
            self.key = key
            self.center = center
            self.width = width
            self.height = height
        }
    }

    public struct Placement: Equatable, Sendable {
        public var key: String
        public var frame: CGRect
    }

    /// 重ならない最終配置(top-left グローバル frame)を返す。
    /// obstacles は動かせない既存要素(dockヒント等)で、これとも重ねない。
    /// 結果は入力順に依存せず決定的。空き位置が全くない極端なケースのみ
    /// 希望位置のまま重なりを許容する。
    public static func layout(
        items: [Item],
        screenFrame: CGRect,
        obstacles: [CGRect] = [],
        gap: CGFloat = 4
    ) -> [Placement] {
        guard !items.isEmpty else { return [] }

        // 処理順を固定して決定性を担保(入力順に依存しない)
        var sorted = items
        sorted.sort { a, b in
            if a.center.y != b.center.y { return a.center.y < b.center.y }
            if a.center.x != b.center.x { return a.center.x < b.center.x }
            return a.key < b.key
        }

        var placements: [Placement] = []
        var placedFrames: [CGRect] = obstacles

        for item in sorted {
            let desired = clampToScreen(
                CGRect(
                    x: item.center.x - item.width / 2,
                    y: item.center.y - item.height / 2,
                    width: item.width, height: item.height),
                screenFrame)
            let frame =
                isFree(desired, placedFrames, gap: gap)
                ? desired
                : nearestFreeFrame(
                    desired: desired, placed: placedFrames,
                    screenFrame: screenFrame, gap: gap) ?? desired
            placements.append(Placement(key: item.key, frame: frame))
            placedFrames.append(frame)
        }
        return placements
    }

    /// gap 込みで既配置のどれとも交差しないか
    static func isFree(_ frame: CGRect, _ placed: [CGRect], gap: CGFloat) -> Bool {
        let padded = frame.insetBy(dx: -gap, dy: -gap)
        return placed.allSatisfy { !padded.intersects($0) }
    }

    /// 既配置の縁に接する候補(X・Y 独立の組み合わせ)から、
    /// 希望位置に最も近い空き位置を返す。
    /// 距離同点は縦方向(Y のみの移動)を優先 — ラベルは横長なので縦にずらす方が読みやすい。
    static func nearestFreeFrame(
        desired: CGRect, placed: [CGRect], screenFrame: CGRect, gap: CGFloat
    ) -> CGRect? {
        var xs: [CGFloat] = [desired.minX]
        var ys: [CGFloat] = [desired.minY]
        for p in placed {
            xs.append(p.minX - gap - desired.width)
            xs.append(p.maxX + gap)
            ys.append(p.minY - gap - desired.height)
            ys.append(p.maxY + gap)
        }
        xs = xs.map { min(max($0, screenFrame.minX), screenFrame.maxX - desired.width) }
        ys = ys.map { min(max($0, screenFrame.minY), screenFrame.maxY - desired.height) }

        var best: CGRect?
        var bestScore = CGFloat.greatestFiniteMagnitude
        for y in ys {
            for x in xs {
                let candidate = CGRect(
                    x: x, y: y, width: desired.width, height: desired.height)
                guard isFree(candidate, placed, gap: gap) else { continue }
                let dx = x - desired.minX
                let dy = y - desired.minY
                // 横移動をわずかに重くして、同距離なら縦ずらしを選ぶ
                let score = dx * dx * 1.0625 + dy * dy
                if score < bestScore
                    || (score == bestScore && isPreferred(candidate, over: best))
                {
                    best = candidate
                    bestScore = score
                }
            }
        }
        return best
    }

    /// スコア同点時の決定的な tie-break(y → x の昇順)
    static func isPreferred(_ candidate: CGRect, over current: CGRect?) -> Bool {
        guard let current else { return true }
        if candidate.minY != current.minY { return candidate.minY < current.minY }
        return candidate.minX < current.minX
    }

    static func clampToScreen(_ frame: CGRect, _ screenFrame: CGRect) -> CGRect {
        var frame = frame
        frame.origin.x = min(
            max(frame.origin.x, screenFrame.minX), screenFrame.maxX - frame.width)
        frame.origin.y = min(
            max(frame.origin.y, screenFrame.minY), screenFrame.maxY - frame.height)
        return frame
    }
}
