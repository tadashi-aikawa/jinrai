import CoreGraphics

/// 最大空き領域の探索(元 window_mover.lua の freeArea 系)
public enum FreeArea {
    /// スクリーンから占有矩形群を順に矩形差分して空き矩形集合を得る
    public static func freeFramesForScreen(
        screenFrame: CGRect, occupiedFrames: [CGRect]
    ) -> [CGRect] {
        var freeFrames = [screenFrame]
        for occupied in occupiedFrames {
            freeFrames = freeFrames.flatMap { Geometry.subtract($0, occupied) }
        }
        return freeFrames
    }

    /// 優先順位: 面積最大 → 現frame中心に近い → 上寄り → 左寄り
    public static func isBetterFreeFrame(
        candidate: CGRect, best: CGRect?, currentFrame: CGRect?
    ) -> Bool {
        guard let best else { return true }
        let candidateArea = Geometry.area(candidate)
        let bestArea = Geometry.area(best)
        if candidateArea != bestArea {
            return candidateArea > bestArea
        }
        if let currentFrame {
            let candidateDistance = Geometry.centerDistanceSquared(candidate, currentFrame)
            let bestDistance = Geometry.centerDistanceSquared(best, currentFrame)
            if candidateDistance != bestDistance {
                return candidateDistance < bestDistance
            }
        }
        if candidate.minY != best.minY {
            return candidate.minY < best.minY
        }
        return candidate.minX < best.minX
    }

    public static func bestFreeFrame(
        screenFrame: CGRect, occupiedFrames: [CGRect], currentFrame: CGRect?
    ) -> CGRect? {
        var best: CGRect?
        for freeFrame in freeFramesForScreen(
            screenFrame: screenFrame, occupiedFrames: occupiedFrames)
        {
            if isBetterFreeFrame(candidate: freeFrame, best: best, currentFrame: currentFrame) {
                best = freeFrame
            }
        }
        return best
    }
}
