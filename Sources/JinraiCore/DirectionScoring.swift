import CoreGraphics
import Foundation

/// 8方向ウィンドウナビゲーション(元 window_hints.lua L1508-2026)。
/// 座標系は top-left 原点・Y下向き(up = y が小さい方向)。
public enum Direction: String, CaseIterable, Sendable {
    case left, right, up, down
    case upLeft, upRight, downLeft, downRight

    public var isCardinal: Bool {
        switch self {
        case .left, .right, .up, .down: return true
        default: return false
        }
    }
}

public enum DirectionScoring {
    public struct Config: Sendable {
        /// 直交重なりの差がこの px 以下なら同等とみなす
        public var cardinalOverlapTieThresholdPx: CGFloat
        /// 主軸重なり率がこれ以下なら「離れている」とみなし直交重なり条件を免除
        public var maxPrimaryOverlapRatioForDetached: CGFloat
        /// 「離れていない」候補に要求する直交重なり率
        public var minOrthogonalOverlapRatio: CGFloat
        /// この可視率を満たす候補を優先(0 で無効)
        public var preferredVisibleRatio: Double
        public var sampling: Occlusion.SamplingConfig

        public init(
            cardinalOverlapTieThresholdPx: CGFloat = 720,
            maxPrimaryOverlapRatioForDetached: CGFloat = 0.2,
            minOrthogonalOverlapRatio: CGFloat = 0.5,
            preferredVisibleRatio: Double = 0.4,
            sampling: Occlusion.SamplingConfig = Occlusion.SamplingConfig()
        ) {
            self.cardinalOverlapTieThresholdPx = cardinalOverlapTieThresholdPx
            self.maxPrimaryOverlapRatioForDetached = maxPrimaryOverlapRatioForDetached
            self.minOrthogonalOverlapRatio = minOrthogonalOverlapRatio
            self.preferredVisibleRatio = preferredVisibleRatio
            self.sampling = sampling
        }
    }

    static let scoreEpsilon: CGFloat = 0.0001
    static let containsTolerance: CGFloat = 8

    // MARK: - 幾何プリミティブ

    /// 方向への主軸ギャップ(負の重なりは0に切り上げ)
    public static func directionalPrimaryGap(
        _ direction: Direction, from: CGRect, to: CGRect
    ) -> CGFloat {
        switch direction {
        case .left: return max(0, from.minX - to.maxX)
        case .right: return max(0, to.minX - from.maxX)
        case .up: return max(0, from.minY - to.maxY)
        case .down: return max(0, to.minY - from.maxY)
        default: return .greatestFiniteMagnitude
        }
    }

    /// 斜め方向の X/Y ギャップ
    public static func diagonalAxisGaps(
        _ direction: Direction, from: CGRect, to: CGRect
    ) -> (x: CGFloat, y: CGFloat) {
        let leftX = max(0, from.minX - to.maxX)
        let rightX = max(0, to.minX - from.maxX)
        let upY = max(0, from.minY - to.maxY)
        let downY = max(0, to.minY - from.maxY)
        switch direction {
        case .upLeft: return (leftX, upY)
        case .upRight: return (rightX, upY)
        case .downLeft: return (leftX, downY)
        case .downRight: return (rightX, downY)
        default: return (.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        }
    }

    static func rangeOverlap(
        _ aStart: CGFloat, _ aEnd: CGFloat, _ bStart: CGFloat, _ bEnd: CGFloat
    ) -> CGFloat {
        max(0, min(aEnd, bEnd) - max(aStart, bStart))
    }

    /// outer が inner を(許容8px で)包含し、かつ主軸方向に余裕があるか
    public static func frameContainsFrameForDirection(
        _ direction: Direction, outer: CGRect, inner: CGRect
    ) -> Bool {
        let hasPrimaryAxisRoom: Bool
        switch direction {
        case .left, .right: hasPrimaryAxisRoom = inner.width < outer.width
        case .up, .down: hasPrimaryAxisRoom = inner.height < outer.height
        default: hasPrimaryAxisRoom = false
        }
        let t = containsTolerance
        return hasPrimaryAxisRoom
            && outer.minX - t <= inner.minX
            && outer.minY - t <= inner.minY
            && outer.maxX + t >= inner.maxX
            && outer.maxY + t >= inner.maxY
    }

    public static func orthogonalOverlap(
        _ direction: Direction, from: CGRect, to: CGRect
    ) -> CGFloat {
        if direction == .left || direction == .right {
            return rangeOverlap(from.minY, from.maxY, to.minY, to.maxY)
        }
        return rangeOverlap(from.minX, from.maxX, to.minX, to.maxX)
    }

    static func overlapRatio(_ overlap: CGFloat, _ denominator: CGFloat) -> CGFloat {
        guard denominator > 0 else { return 0 }
        return overlap / denominator
    }

    public static func primaryAxisOverlapRatio(
        _ direction: Direction, from: CGRect, to: CGRect
    ) -> CGFloat {
        switch direction {
        case .left, .right:
            return overlapRatio(
                rangeOverlap(from.minX, from.maxX, to.minX, to.maxX),
                min(from.width, to.width))
        case .up, .down:
            return overlapRatio(
                rangeOverlap(from.minY, from.maxY, to.minY, to.maxY),
                min(from.height, to.height))
        default:
            return 0
        }
    }

    public static func orthogonalOverlapRatio(
        _ direction: Direction, from: CGRect, to: CGRect
    ) -> CGFloat {
        let overlap = orthogonalOverlap(direction, from: from, to: to)
        switch direction {
        case .left, .right: return overlapRatio(overlap, min(from.height, to.height))
        case .up, .down: return overlapRatio(overlap, min(from.width, to.width))
        default: return 0
        }
    }

    // MARK: - 候補判定

    /// 基本方向: 対象のエッジが現ウィンドウのエッジを越えているか
    public static func cardinalDirectionEdgePasses(
        _ direction: Direction, from: CGRect, to: CGRect
    ) -> Bool {
        switch direction {
        case .left: return to.minX < from.minX
        case .right: return to.maxX > from.maxX
        case .up: return to.minY < from.minY
        case .down: return to.maxY > from.maxY
        default: return false
        }
    }

    public struct OverlapMetadata: Sendable {
        public var primaryOverlapRatio: CGFloat
        public var orthogonalOverlapRatio: CGFloat
        public var requiresOrthogonalOverlap: Bool
        public var passesOverlap: Bool
    }

    public static func cardinalOverlapMetadata(
        _ direction: Direction, from: CGRect, to: CGRect, config: Config
    ) -> OverlapMetadata {
        let primaryRatio = primaryAxisOverlapRatio(direction, from: from, to: to)
        let orthogonalRatio = orthogonalOverlapRatio(direction, from: from, to: to)
        let requiresOrthogonalOverlap = primaryRatio > config.maxPrimaryOverlapRatioForDetached
        return OverlapMetadata(
            primaryOverlapRatio: primaryRatio,
            orthogonalOverlapRatio: orthogonalRatio,
            requiresOrthogonalOverlap: requiresOrthogonalOverlap,
            passesOverlap: !requiresOrthogonalOverlap
                || orthogonalRatio >= config.minOrthogonalOverlapRatio
        )
    }

    /// 斜め方向: 中心点の位置関係のみで判定
    public static func isDirectionalCandidate(
        _ direction: Direction, fromCenter: CGPoint, toCenter: CGPoint
    ) -> Bool {
        switch direction {
        case .left: return toCenter.x < fromCenter.x
        case .right: return toCenter.x > fromCenter.x
        case .up: return toCenter.y < fromCenter.y
        case .down: return toCenter.y > fromCenter.y
        case .upLeft: return toCenter.x < fromCenter.x && toCenter.y < fromCenter.y
        case .upRight: return toCenter.x > fromCenter.x && toCenter.y < fromCenter.y
        case .downLeft: return toCenter.x < fromCenter.x && toCenter.y > fromCenter.y
        case .downRight: return toCenter.x > fromCenter.x && toCenter.y > fromCenter.y
        }
    }

    static func secondaryAxisDelta(
        _ direction: Direction, fromCenter: CGPoint, toCenter: CGPoint
    ) -> CGFloat {
        if direction == .left || direction == .right {
            return abs(toCenter.y - fromCenter.y)
        }
        return abs(toCenter.x - fromCenter.x)
    }

    // MARK: - 最良ターゲット探索

    struct Candidate {
        var window: WindowInfo
        var frame: CGRect
        var zOrder: Int
        var isPrevious: Bool
        // cardinal
        var primaryGap: CGFloat = 0
        var orthogonalOverlap: CGFloat = 0
        var secondary: CGFloat = 0
        var meetsMinVisibleRatio = true
        var visibleRatio: Double = 1
        // diagonal
        var diagonalGap: CGFloat = 0
        var distance2: CGFloat = 0
    }

    /// 対象ウィンドウの前面にあるウィンドウの矩形群(Z順リストから)
    public static func coveringFramesBeforeWindow(
        orderedWindows: [WindowInfo], targetWindowID: UInt32
    ) -> [CGRect] {
        var frames: [CGRect] = []
        for win in orderedWindows {
            if win.id == targetWindowID { break }
            if Geometry.isValidFrame(win.frame) {
                frames.append(win.frame)
            }
        }
        return frames
    }

    /// 完全に隠れているウィンドウか(方向ナビの候補フィルタ)
    public static func isFullyOccludedWindow(
        _ window: WindowInfo, orderedWindows: [WindowInfo], config: Config
    ) -> Bool {
        guard Geometry.isValidFrame(window.frame) else { return false }
        let coveringFrames = coveringFramesBeforeWindow(
            orderedWindows: orderedWindows, targetWindowID: window.id)
        guard !coveringFrames.isEmpty else { return false }
        let grid = Occlusion.samplingGrid(windowFrame: window.frame, config: config.sampling)
        return Occlusion.isWindowOccluded(
            targetFrame: window.frame, coveringFrames: coveringFrames,
            cols: grid.cols, rows: grid.rows)
    }

    static func measureVisibilityForDirection(
        _ window: WindowInfo,
        orderedWindows: [WindowInfo],
        config: Config,
        direction: Direction,
        currentFrame: CGRect
    ) -> Occlusion.VisibilityResult {
        let coveringFrames = coveringFramesBeforeWindow(
            orderedWindows: orderedWindows, targetWindowID: window.id)
        let hasDirectionFilter = direction.isCardinal
        if coveringFrames.isEmpty && !hasDirectionFilter {
            return Occlusion.VisibilityResult(
                visibleRatio: 1, isFullyOccluded: false, meetsMinVisibleRatio: true)
        }
        let grid = Occlusion.samplingGrid(windowFrame: window.frame, config: config.sampling)
        let filter: ((CGFloat, CGFloat) -> Bool)? =
            hasDirectionFilter
            ? { px, py in isSampleInDirection(direction, fromFrame: currentFrame, px: px, py: py) }
            : nil
        return Occlusion.measureWindowVisibility(
            targetFrame: window.frame,
            coveringFrames: coveringFrames,
            cols: grid.cols,
            rows: grid.rows,
            minVisibleRatio: config.preferredVisibleRatio,
            visibilityFilter: filter
        )
    }

    /// サンプル点が現ウィンドウから見て指定方向にあるか
    static func isSampleInDirection(
        _ direction: Direction, fromFrame: CGRect, px: CGFloat, py: CGFloat
    ) -> Bool {
        switch direction {
        case .left: return px <= fromFrame.minX
        case .right: return px >= fromFrame.maxX
        case .up: return py <= fromFrame.minY
        case .down: return py >= fromFrame.maxY
        default: return true
        }
    }

    /// 指定方向の最良ウィンドウを選ぶ(元 findDirectionalWindowTarget)。
    /// candidateWindows / orderedWindows は Z順(前面が先頭)。
    public static func findDirectionalWindowTarget(
        current: WindowInfo,
        candidates: [WindowInfo],
        direction: Direction,
        previous: WindowInfo? = nil,
        orderedWindows: [WindowInfo] = [],
        config: Config = Config()
    ) -> WindowInfo? {
        let currentFrame = current.frame
        guard Geometry.isValidFrame(currentFrame) else { return nil }
        let currentCenter = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        var zOrderLookup: [UInt32: Int] = [:]
        for (index, win) in orderedWindows.enumerated() where zOrderLookup[win.id] == nil {
            zOrderLookup[win.id] = index
        }
        let visibleRatioPreferenceEnabled =
            config.preferredVisibleRatio > 0 && direction.isCardinal

        var best: Candidate?

        for win in candidates where win.id != current.id {
            let frame = win.frame
            guard Geometry.isValidFrame(frame) else { continue }
            let center = CGPoint(x: frame.midX, y: frame.midY)

            let isCandidate: Bool
            var overlapMetadata: OverlapMetadata?
            if direction.isCardinal {
                guard cardinalDirectionEdgePasses(direction, from: currentFrame, to: frame) else {
                    continue
                }
                let metadata = cardinalOverlapMetadata(
                    direction, from: currentFrame, to: frame, config: config)
                overlapMetadata = metadata
                isCandidate = metadata.passesOverlap
            } else {
                isCandidate = isDirectionalCandidate(
                    direction, fromCenter: currentCenter, toCenter: center)
            }
            guard isCandidate else { continue }

            var candidate = Candidate(
                window: win,
                frame: frame,
                zOrder: zOrderLookup[win.id] ?? Int.max,
                isPrevious: previous.map { $0.id == win.id } ?? false
            )

            if direction.isCardinal {
                candidate.primaryGap = directionalPrimaryGap(
                    direction, from: currentFrame, to: frame)
                candidate.orthogonalOverlap = orthogonalOverlap(
                    direction, from: currentFrame, to: frame)
                candidate.secondary = secondaryAxisDelta(
                    direction, fromCenter: currentCenter, toCenter: center)
                if visibleRatioPreferenceEnabled {
                    let visibility = measureVisibilityForDirection(
                        win, orderedWindows: orderedWindows, config: config,
                        direction: direction, currentFrame: currentFrame)
                    candidate.meetsMinVisibleRatio = visibility.meetsMinVisibleRatio
                    candidate.visibleRatio = visibility.visibleRatio
                }
                _ = overlapMetadata
            } else {
                let gaps = diagonalAxisGaps(direction, from: currentFrame, to: frame)
                let dx = center.x - currentCenter.x
                let dy = center.y - currentCenter.y
                candidate.diagonalGap = gaps.x + gaps.y
                candidate.distance2 = dx * dx + dy * dy
            }

            guard let currentBest = best else {
                best = candidate
                continue
            }
            if isBetterCandidate(
                candidate, than: currentBest, direction: direction, config: config,
                visibleRatioPreferenceEnabled: visibleRatioPreferenceEnabled)
            {
                best = candidate
            }
        }

        return best?.window
    }

    static func isBetterCandidate(
        _ candidate: Candidate,
        than best: Candidate,
        direction: Direction,
        config: Config,
        visibleRatioPreferenceEnabled: Bool
    ) -> Bool {
        let eps = scoreEpsilon
        if direction.isCardinal {
            if frameContainsFrameForDirection(direction, outer: best.frame, inner: candidate.frame) {
                return true
            }
            if frameContainsFrameForDirection(direction, outer: candidate.frame, inner: best.frame) {
                return false
            }
            if candidate.meetsMinVisibleRatio != best.meetsMinVisibleRatio {
                return candidate.meetsMinVisibleRatio
            }
            if visibleRatioPreferenceEnabled
                && !candidate.meetsMinVisibleRatio
                && abs(candidate.visibleRatio - best.visibleRatio) > Double(eps)
            {
                return candidate.visibleRatio > best.visibleRatio
            }
            let overlapDiff = candidate.orthogonalOverlap - best.orthogonalOverlap
            let overlapTie = abs(overlapDiff) <= (config.cardinalOverlapTieThresholdPx + eps)
            if !overlapTie && abs(overlapDiff) > eps {
                return overlapDiff > 0
            }
            if candidate.primaryGap < (best.primaryGap - eps) {
                return true
            }
            if abs(candidate.primaryGap - best.primaryGap) <= eps {
                if candidate.zOrder != best.zOrder {
                    return candidate.zOrder < best.zOrder
                }
                if candidate.secondary != best.secondary {
                    return candidate.secondary < best.secondary
                }
                if candidate.isPrevious != best.isPrevious {
                    return candidate.isPrevious
                }
                return candidate.window.id < best.window.id
            }
            return false
        }

        // 斜め方向
        if candidate.diagonalGap < (best.diagonalGap - eps) {
            return true
        }
        if abs(candidate.diagonalGap - best.diagonalGap) <= eps {
            if candidate.zOrder != best.zOrder {
                return candidate.zOrder < best.zOrder
            }
            if candidate.distance2 < (best.distance2 - eps) {
                return true
            }
            if abs(candidate.distance2 - best.distance2) <= eps {
                if candidate.isPrevious != best.isPrevious {
                    return candidate.isPrevious
                }
                return candidate.window.id < best.window.id
            }
        }
        return false
    }
}
