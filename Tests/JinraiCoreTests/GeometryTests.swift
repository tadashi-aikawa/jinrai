import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("Geometry")
struct GeometryTests {
    @Test("交差矩形を返す")
    func intersectOverlapping() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 50, y: 50, width: 100, height: 100)
        #expect(Geometry.intersect(a, b) == CGRect(x: 50, y: 50, width: 50, height: 50))
    }

    @Test("接しているだけなら nil")
    func intersectTouching() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 100, y: 0, width: 100, height: 100)
        #expect(Geometry.intersect(a, b) == nil)
    }

    @Test("離れていれば nil")
    func intersectDisjoint() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 50, y: 50, width: 10, height: 10)
        #expect(Geometry.intersect(a, b) == nil)
    }

    @Test("中央をくり抜くと上下左右の4矩形に分割される")
    func subtractCenter() {
        let base = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occupied = CGRect(x: 25, y: 25, width: 50, height: 50)
        let result = Geometry.subtract(base, occupied)
        #expect(result.count == 4)
        #expect(result.contains(CGRect(x: 0, y: 0, width: 100, height: 25)))  // 上
        #expect(result.contains(CGRect(x: 0, y: 75, width: 100, height: 25)))  // 下
        #expect(result.contains(CGRect(x: 0, y: 25, width: 25, height: 50)))  // 左
        #expect(result.contains(CGRect(x: 75, y: 25, width: 25, height: 50)))  // 右
    }

    @Test("重ならない場合は base をそのまま返す")
    func subtractNoOverlap() {
        let base = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occupied = CGRect(x: 200, y: 200, width: 50, height: 50)
        #expect(Geometry.subtract(base, occupied) == [base])
    }

    @Test("完全に覆われたら空になる")
    func subtractFullCover() {
        let base = CGRect(x: 10, y: 10, width: 50, height: 50)
        let occupied = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(Geometry.subtract(base, occupied).isEmpty)
    }

    @Test("角を占有すると2矩形になる")
    func subtractCorner() {
        let base = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occupied = CGRect(x: 0, y: 0, width: 50, height: 50)
        let result = Geometry.subtract(base, occupied)
        #expect(result.count == 2)
        #expect(result.contains(CGRect(x: 0, y: 50, width: 100, height: 50)))  // 下
        #expect(result.contains(CGRect(x: 50, y: 0, width: 50, height: 50)))  // 右
    }

    @Test("重複するカバー矩形の面積を二重計上しない")
    func coveredAreaNoDoubleCount() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let covers = [
            CGRect(x: 0, y: 0, width: 60, height: 100),
            CGRect(x: 40, y: 0, width: 60, height: 100),  // 40..60 が重複
        ]
        #expect(Geometry.coveredArea(of: frame, by: covers) == CGFloat(100 * 100))
    }

    @Test("部分被覆の面積を返す")
    func coveredAreaPartial() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let covers = [CGRect(x: 50, y: 0, width: 100, height: 100)]
        #expect(Geometry.coveredArea(of: frame, by: covers) == CGFloat(50 * 100))
    }

    @Test("threshold=0.5: 半分覆われていたら隠れている")
    func hiddenByThreshold() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let half = [CGRect(x: 0, y: 0, width: 50, height: 100)]
        #expect(Geometry.isHiddenByFrontFrames(frame, frontFrames: half, threshold: 0.5))
        #expect(!Geometry.isHiddenByFrontFrames(frame, frontFrames: half, threshold: 0.51))
    }

    @Test("threshold=0: 少しでも重なれば隠れている扱い")
    func hiddenByThresholdZero() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let tiny = [CGRect(x: 0, y: 0, width: 1, height: 1)]
        #expect(Geometry.isHiddenByFrontFrames(frame, frontFrames: tiny, threshold: 0))
        #expect(!Geometry.isHiddenByFrontFrames(frame, frontFrames: [], threshold: 0))
    }

    @Test("frameNear は許容差内の frame を同一とみなす")
    func frameNearTolerance() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 16, y: -16, width: 116, height: 84)
        #expect(Geometry.frameNear(a, b, tolerance: 16))
        let c = CGRect(x: 17, y: 0, width: 100, height: 100)
        #expect(!Geometry.frameNear(a, c, tolerance: 16))
    }
}
