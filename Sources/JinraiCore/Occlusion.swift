import CoreGraphics
import Foundation

/// オクルージョン判定(元 window_hints.lua L1199-1339)。
/// ウィンドウ面をサンプル格子で走査し、前面矩形群による被覆を判定する。
public enum Occlusion {
    public struct SamplingConfig: Sendable {
        /// サンプリングによる隠れ具合の判定を有効にするか(occlusion.sampling.enabled)
        public var enabled: Bool
        /// サンプリング密度の基準画面幅(occlusion.sampling.baseWidth)
        public var baseWidth: CGFloat
        /// サンプリング密度の基準画面高さ(occlusion.sampling.baseHeight)
        public var baseHeight: CGFloat
        /// 横方向の最小サンプル数(occlusion.sampling.minCols)
        public var minCols: Int
        /// 縦方向の最小サンプル数(occlusion.sampling.minRows)
        public var minRows: Int
        /// 横方向の最大サンプル数(occlusion.sampling.maxCols)
        public var maxCols: Int
        /// 縦方向の最大サンプル数(occlusion.sampling.maxRows)
        public var maxRows: Int

        public init(
            enabled: Bool = true,
            baseWidth: CGFloat = 1920,
            baseHeight: CGFloat = 1080,
            minCols: Int = 4,
            minRows: Int = 4,
            maxCols: Int = 8,
            maxRows: Int = 8
        ) {
            self.enabled = enabled
            self.baseWidth = baseWidth
            self.baseHeight = baseHeight
            self.minCols = minCols
            self.minRows = minRows
            self.maxCols = maxCols
            self.maxRows = maxRows
        }
    }

    public struct VisibilityResult: Equatable, Sendable {
        public var visibleRatio: Double
        public var isFullyOccluded: Bool
        public var meetsMinVisibleRatio: Bool
    }

    /// 境界含む点包含(元 isPointInRect と同じ閉区間判定)
    public static func isPointInRect(_ px: CGFloat, _ py: CGFloat, _ rect: CGRect) -> Bool {
        px >= rect.minX && px <= rect.maxX && py >= rect.minY && py <= rect.maxY
    }

    /// ウィンドウサイズに応じたサンプル格子(cols, rows)
    public static func samplingGrid(
        windowFrame: CGRect, config: SamplingConfig = SamplingConfig()
    ) -> (cols: Int, rows: Int) {
        guard config.enabled else { return (4, 4) }
        let baseWidth = max(1, config.baseWidth)
        let baseHeight = max(1, config.baseHeight)
        let minCols = max(1, config.minCols)
        let minRows = max(1, config.minRows)
        let maxCols = max(minCols, config.maxCols)
        let maxRows = max(minRows, config.maxRows)

        let cols = Int(
            (CGFloat(minCols) * windowFrame.width / baseWidth + 0.5).rounded(.down))
        let rows = Int(
            (CGFloat(minRows) * windowFrame.height / baseHeight + 0.5).rounded(.down))
        return (min(max(cols, minCols), maxCols), min(max(rows, minRows), maxRows))
    }

    /// 全サンプル点が前面矩形に覆われていれば true(完全被覆)
    public static func isWindowOccluded(
        targetFrame: CGRect, coveringFrames: [CGRect], cols: Int = 4, rows: Int = 4
    ) -> Bool {
        let sampleCols = max(1, cols)
        let sampleRows = max(1, rows)
        for row in 0..<sampleRows {
            for col in 0..<sampleCols {
                let px = targetFrame.minX + targetFrame.width * (CGFloat(col) + 0.5) / CGFloat(sampleCols)
                let py = targetFrame.minY + targetFrame.height * (CGFloat(row) + 0.5) / CGFloat(sampleRows)
                let covered = coveringFrames.contains { isPointInRect(px, py, $0) }
                if !covered { return false }
            }
        }
        return true
    }

    /// 可視率の測定。visibilityFilter で「この方向のサンプルだけ数える」等の制約を掛けられる
    public static func measureWindowVisibility(
        targetFrame: CGRect,
        coveringFrames: [CGRect],
        cols: Int = 4,
        rows: Int = 4,
        minVisibleRatio: Double = 0,
        visibilityFilter: ((CGFloat, CGFloat) -> Bool)? = nil
    ) -> VisibilityResult {
        let sampleCols = max(1, cols)
        let sampleRows = max(1, rows)
        let total = sampleCols * sampleRows
        let minRatio = min(max(minVisibleRatio, 0), 1)
        let requiredVisible = Int((Double(total) * minRatio - 0.000001).rounded(.up))
        var visible = 0

        for row in 0..<sampleRows {
            for col in 0..<sampleCols {
                let px = targetFrame.minX + targetFrame.width * (CGFloat(col) + 0.5) / CGFloat(sampleCols)
                let py = targetFrame.minY + targetFrame.height * (CGFloat(row) + 0.5) / CGFloat(sampleRows)
                let covered = coveringFrames.contains { isPointInRect(px, py, $0) }
                if !covered && (visibilityFilter?(px, py) ?? true) {
                    visible += 1
                    if requiredVisible > 0 && visible >= requiredVisible {
                        return VisibilityResult(
                            visibleRatio: Double(visible) / Double(total),
                            isFullyOccluded: false,
                            meetsMinVisibleRatio: true
                        )
                    }
                }
            }
        }

        return VisibilityResult(
            visibleRatio: Double(visible) / Double(total),
            isFullyOccluded: visible == 0,
            meetsMinVisibleRatio: visible >= requiredVisible
        )
    }

    /// 覆われていないサンプル点のうち中心に最も近い点(ヒント表示位置の調整用)
    public static func findUncoveredCenter(
        windowFrame: CGRect, coveringFrames: [CGRect]
    ) -> CGPoint {
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard !coveringFrames.isEmpty else { return center }

        let cols = 5
        let rows = 5
        var best = center
        var bestDist = CGFloat.greatestFiniteMagnitude
        for row in 0..<rows {
            for col in 0..<cols {
                let px = windowFrame.minX + windowFrame.width * (CGFloat(col) + 0.5) / CGFloat(cols)
                let py = windowFrame.minY + windowFrame.height * (CGFloat(row) + 0.5) / CGFloat(rows)
                let covered = coveringFrames.contains { isPointInRect(px, py, $0) }
                if !covered {
                    let dx = px - center.x
                    let dy = py - center.y
                    let dist = dx * dx + dy * dy
                    if dist < bestDist {
                        bestDist = dist
                        best = CGPoint(x: px, y: py)
                    }
                }
            }
        }
        return best
    }
}
