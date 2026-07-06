import CoreGraphics
import Foundation

/// 隠れウィンドウ・別Space候補の「ドック」配置(元 window_hints.lua の
/// resolveOccludedDockItemXs / resolveOccludedDockItemY / splitDockItemsIntoRows)。
///
/// X 方向は Pool Adjacent Violators(単調回帰)で「最小間隔を保ちつつ各アイテムを
/// ウィンドウ実位置へ寄せた目標にできるだけ近づける」配置を求め、最後に画面内へシフトする。
/// これにより貪欲配置で起きる横方向の重なり・片側の余白が解消される。
/// 座標は top-left 原点。
public enum DockLayout {
    public struct Item: Equatable, Sendable {
        public var key: String
        public var width: CGFloat
        public var height: CGFloat
        public var windowCenterX: CGFloat
        public var windowCenterY: CGFloat

        public init(
            key: String, width: CGFloat, height: CGFloat,
            windowCenterX: CGFloat, windowCenterY: CGFloat
        ) {
            self.key = key
            self.width = width
            self.height = height
            self.windowCenterX = windowCenterX
            self.windowCenterY = windowCenterY
        }
    }

    public struct Placement: Equatable, Sendable {
        public var key: String
        public var frame: CGRect
    }

    /// ドックヒント箱の合計面積が screenArea × maxFillRatio を超える場合の一律縮小率。
    /// 収まっていれば 1.0。箱の数に応じて全体をなだらかに縮め、多数ウィンドウ時に
    /// HintLayout が空き位置を見つけられず重なりを許容する破綻を防ぐ。
    /// 面積比のため各辺の縮小率は √ を取る
    public static func densityScale(
        boxSizes: [CGSize], screenFrame: CGRect, maxFillRatio: CGFloat
    ) -> CGFloat {
        let totalArea = boxSizes.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
        let budget = screenFrame.width * screenFrame.height * maxFillRatio
        guard totalArea > 0, budget > 0, totalArea > budget else { return 1 }
        return sqrt(budget / totalArea)
    }

    static func clamp(_ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        if value < lo { return lo }
        if value > hi { return hi }
        return value
    }

    /// 幅に収まるよう行分割(元 splitDockItemsIntoRows)
    static func splitIntoRows(
        _ items: [Item], availableWidth: CGFloat, gap: CGFloat
    ) -> [[Item]] {
        guard !items.isEmpty else { return [] }
        var rows: [[Item]] = []
        var current: [Item] = []
        var currentWidth: CGFloat = 0
        for item in items {
            if !current.isEmpty, currentWidth + gap + item.width > availableWidth {
                rows.append(current)
                current = [item]
                currentWidth = item.width
            } else {
                if !current.isEmpty { currentWidth += gap }
                current.append(item)
                currentWidth += item.width
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    /// 行内の X 座標を PAV で決定(元 resolveOccludedDockItemXs)。
    /// centeredXs は中央整列時の各アイテム左端。
    static func resolveRowXs(
        screenFrame: CGRect,
        widths: [CGFloat],
        centeredXs: [CGFloat],
        windowCenterXs: [CGFloat],
        gap: CGFloat,
        xBlend: CGFloat
    ) -> [CGFloat] {
        let count = widths.count
        guard count > 0 else { return [] }
        let screenRight = screenFrame.maxX

        // 各アイテムの目標 X(ウィンドウ実位置へ blend、画面内クランプ)
        var desiredXs = [CGFloat](repeating: 0, count: count)
        for i in 0..<count {
            var desiredX = centeredXs[i]
            if xBlend > 0 {
                let targetX = windowCenterXs[i] - widths[i] / 2
                desiredX = centeredXs[i] + (targetX - centeredXs[i]) * xBlend
            }
            let maxX = screenRight - widths[i]
            desiredXs[i] = clamp(desiredX, screenFrame.minX, maxX)
        }

        // Pool Adjacent Violators: 累積オフセットを引いて単調問題に変換し、
        // 平均が単調非減少になるようブロックをマージ
        struct Block {
            var startIndex: Int
            var endIndex: Int
            var sum: CGFloat
            var count: Int
            var mean: CGFloat
        }
        var offsets = [CGFloat](repeating: 0, count: count)
        var blocks: [Block] = []
        var runningOffset: CGFloat = 0
        for i in 0..<count {
            offsets[i] = runningOffset
            let z = desiredXs[i] - runningOffset
            blocks.append(
                Block(startIndex: i, endIndex: i, sum: z, count: 1, mean: z))
            while blocks.count >= 2, blocks[blocks.count - 2].mean > blocks[blocks.count - 1].mean {
                let b2 = blocks.removeLast()
                var b1 = blocks.removeLast()
                b1.endIndex = b2.endIndex
                b1.sum += b2.sum
                b1.count += b2.count
                b1.mean = b1.sum / CGFloat(b1.count)
                blocks.append(b1)
            }
            runningOffset += widths[i] + gap
        }

        var xs = [CGFloat](repeating: 0, count: count)
        for block in blocks {
            for i in block.startIndex...block.endIndex {
                xs[i] = block.mean + offsets[i]
            }
        }

        // 画面内に収まるよう全体を平行移動
        var lowerShift = -CGFloat.greatestFiniteMagnitude
        var upperShift = CGFloat.greatestFiniteMagnitude
        for i in 0..<count {
            lowerShift = max(lowerShift, screenFrame.minX - xs[i])
            upperShift = min(upperShift, (screenRight - widths[i]) - xs[i])
        }
        if lowerShift <= upperShift {
            let shift = clamp(0, lowerShift, upperShift)
            for i in 0..<count { xs[i] += shift }
            return xs
        }

        // フォールバック: 貪欲配置(1行に収まりきらない極端なケース)
        var fallback = [CGFloat](repeating: 0, count: count)
        var curX = xBlend > 0 ? screenFrame.minX : centeredXs[0]
        for i in 0..<count {
            var desiredX = centeredXs[i]
            if xBlend > 0 {
                let targetX = windowCenterXs[i] - widths[i] / 2
                desiredX = centeredXs[i] + (targetX - centeredXs[i]) * xBlend
            }
            let maxX = screenRight - widths[i]
            let x = clamp(max(curX, desiredX), screenFrame.minX, maxX)
            fallback[i] = x
            curX = x + widths[i] + gap
        }
        return fallback
    }

    /// Y 座標(上半分のウィンドウは画面上端へ寄せる。元 resolveOccludedDockItemY)
    static func resolveItemY(
        screenFrame: CGRect, itemHeight: CGFloat, centeredY: CGFloat,
        windowCenterY: CGFloat, yBlend: CGFloat, dockMargin: CGFloat
    ) -> CGFloat {
        var desiredY = centeredY
        if yBlend > 0 {
            let screenCenterY = screenFrame.minY + screenFrame.height / 2
            var targetY = centeredY
            if windowCenterY < screenCenterY {
                targetY = screenFrame.minY + dockMargin
            }
            desiredY = centeredY + (targetY - centeredY) * yBlend
        }
        let maxY = screenFrame.maxY - itemHeight
        return clamp(desiredY, screenFrame.minY, maxY)
    }

    /// ドック全体の配置。返り値は各アイテムの top-left グローバル frame。
    public static func layout(
        items: [Item],
        screenFrame: CGRect,
        gap: CGFloat,
        dockMargin: CGFloat,
        xBlend: CGFloat,
        yBlend: CGFloat
    ) -> [Placement] {
        guard !items.isEmpty else { return [] }

        // ウィンドウ位置へ寄せる場合は X 順に並べる(安定のため key で tiebreak)
        var sorted = items
        if xBlend > 0 {
            sorted.sort { a, b in
                a.windowCenterX != b.windowCenterX
                    ? a.windowCenterX < b.windowCenterX : a.key < b.key
            }
        }

        let rows = splitIntoRows(sorted, availableWidth: screenFrame.width, gap: gap)
        var placements: [Placement] = []
        var rowBottomY = screenFrame.maxY - dockMargin

        for row in rows {
            let totalWidth =
                row.reduce(0) { $0 + $1.width } + gap * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map(\.height).max() ?? 0
            let dockY = rowBottomY - rowHeight

            // 中央整列時の各アイテム左端
            let startX = screenFrame.minX + (screenFrame.width - totalWidth) / 2
            var centeredXs: [CGFloat] = []
            var cx = startX
            for item in row {
                centeredXs.append(cx)
                cx += item.width + gap
            }

            let xs = resolveRowXs(
                screenFrame: screenFrame,
                widths: row.map(\.width),
                centeredXs: centeredXs,
                windowCenterXs: row.map(\.windowCenterX),
                gap: gap,
                xBlend: xBlend)

            for (i, item) in row.enumerated() {
                let centeredY = dockY + (rowHeight - item.height)
                let y = resolveItemY(
                    screenFrame: screenFrame, itemHeight: item.height, centeredY: centeredY,
                    windowCenterY: item.windowCenterY, yBlend: yBlend, dockMargin: dockMargin)
                let x = clamp(xs[i], screenFrame.minX, screenFrame.maxX - item.width)
                placements.append(
                    Placement(
                        key: item.key,
                        frame: CGRect(x: x, y: y, width: item.width, height: item.height)))
            }
            rowBottomY = dockY - gap
        }
        return placements
    }
}
