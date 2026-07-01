import CoreGraphics

/// 矩形演算(元 window_mover.lua の frame 関数群)。
/// CGRect をそのまま使うが、元実装同様「幅・高さが正」のものだけを有効とみなす。
public enum Geometry {
    public static func isValidFrame(_ frame: CGRect) -> Bool {
        frame.width > 0 && frame.height > 0
    }

    /// 交差矩形。接しているだけ(幅0)は nil
    public static func intersect(_ a: CGRect, _ b: CGRect) -> CGRect? {
        guard isValidFrame(a), isValidFrame(b) else { return nil }
        let x1 = max(a.minX, b.minX)
        let y1 = max(a.minY, b.minY)
        let x2 = min(a.maxX, b.maxX)
        let y2 = min(a.maxY, b.maxY)
        guard x2 > x1, y2 > y1 else { return nil }
        return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    /// base から occupied を引いた残り(上・下・左・右の最大4矩形)
    public static func subtract(_ base: CGRect, _ occupied: CGRect) -> [CGRect] {
        guard let cut = intersect(base, occupied) else { return [base] }
        let rects = [
            CGRect(x: base.minX, y: base.minY, width: base.width, height: cut.minY - base.minY),
            CGRect(x: base.minX, y: cut.maxY, width: base.width, height: base.maxY - cut.maxY),
            CGRect(x: base.minX, y: cut.minY, width: cut.minX - base.minX, height: cut.height),
            CGRect(x: cut.maxX, y: cut.minY, width: base.maxX - cut.maxX, height: cut.height),
        ]
        return rects.filter(isValidFrame)
    }

    public static func area(_ frame: CGRect) -> CGFloat {
        frame.width * frame.height
    }

    public static func centerDistanceSquared(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return dx * dx + dy * dy
    }

    public static func frameNear(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        guard isValidFrame(a), isValidFrame(b) else { return false }
        return abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }

    /// frame のうち coverFrames に覆われている面積(重複部分は二重計上しない)
    public static func coveredArea(of frame: CGRect, by coverFrames: [CGRect]) -> CGFloat {
        var coveredFrames: [CGRect] = []
        var coveredArea: CGFloat = 0
        for coverFrame in coverFrames {
            guard let coveredPart = intersect(frame, coverFrame) else { continue }
            var uncoveredParts = [coveredPart]
            for alreadyCovered in coveredFrames {
                uncoveredParts = uncoveredParts.flatMap { subtract($0, alreadyCovered) }
                if uncoveredParts.isEmpty { break }
            }
            for uncoveredPart in uncoveredParts {
                coveredFrames.append(uncoveredPart)
                coveredArea += area(uncoveredPart)
            }
        }
        return coveredArea
    }

    /// 前面矩形群による被覆率が threshold 以上なら「隠れている」
    public static func isHiddenByFrontFrames(
        _ frame: CGRect, frontFrames: [CGRect], threshold: CGFloat
    ) -> Bool {
        let covered = coveredArea(of: frame, by: frontFrames)
        if threshold <= 0 {
            return covered > 0
        }
        return covered / area(frame) >= threshold
    }
}
