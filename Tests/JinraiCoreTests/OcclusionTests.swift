import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("Occlusion")
struct OcclusionTests {
    @Test("サンプリング無効時は 4x4 固定")
    func gridDisabled() {
        let grid = Occlusion.samplingGrid(
            windowFrame: CGRect(x: 0, y: 0, width: 3840, height: 2160),
            config: .init(enabled: false))
        #expect(grid.cols == 4 && grid.rows == 4)
    }

    @Test("基準サイズのウィンドウは最小格子")
    func gridBaseSize() {
        let grid = Occlusion.samplingGrid(
            windowFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        #expect(grid.cols == 4 && grid.rows == 4)
    }

    @Test("大きなウィンドウは格子が増え、最大値でクランプ")
    func gridLargeWindow() {
        let grid = Occlusion.samplingGrid(
            windowFrame: CGRect(x: 0, y: 0, width: 3840, height: 2160))
        #expect(grid.cols == 8 && grid.rows == 8)
        let huge = Occlusion.samplingGrid(
            windowFrame: CGRect(x: 0, y: 0, width: 10000, height: 10000))
        #expect(huge.cols == 8 && huge.rows == 8)
    }

    @Test("小さなウィンドウも最小値でクランプ")
    func gridSmallWindow() {
        let grid = Occlusion.samplingGrid(
            windowFrame: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(grid.cols == 4 && grid.rows == 4)
    }

    @Test("完全被覆なら occluded")
    func fullyOccluded() {
        let target = CGRect(x: 10, y: 10, width: 100, height: 100)
        let cover = [CGRect(x: 0, y: 0, width: 200, height: 200)]
        #expect(Occlusion.isWindowOccluded(targetFrame: target, coveringFrames: cover))
    }

    @Test("一部でも露出していれば occluded ではない")
    func partiallyVisible() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let cover = [CGRect(x: 0, y: 0, width: 100, height: 60)]
        #expect(!Occlusion.isWindowOccluded(targetFrame: target, coveringFrames: cover))
    }

    @Test("複数矩形の合わせ技で完全被覆")
    func occludedByMultiple() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let covers = [
            CGRect(x: 0, y: 0, width: 100, height: 50),
            CGRect(x: 0, y: 50, width: 100, height: 50),
        ]
        #expect(Occlusion.isWindowOccluded(targetFrame: target, coveringFrames: covers))
    }

    @Test("可視率の測定: 半分露出")
    func visibilityHalf() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let cover = [CGRect(x: 0, y: 0, width: 50, height: 100)]
        let result = Occlusion.measureWindowVisibility(
            targetFrame: target, coveringFrames: cover)
        #expect(result.visibleRatio == 0.5)
        #expect(!result.isFullyOccluded)
    }

    @Test("minVisibleRatio を満たすと早期リターンで meets=true")
    func visibilityMeetsMinRatio() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let cover = [CGRect(x: 0, y: 0, width: 50, height: 100)]
        let result = Occlusion.measureWindowVisibility(
            targetFrame: target, coveringFrames: cover, minVisibleRatio: 0.4)
        #expect(result.meetsMinVisibleRatio)
        let strict = Occlusion.measureWindowVisibility(
            targetFrame: target, coveringFrames: cover, minVisibleRatio: 0.6)
        #expect(!strict.meetsMinVisibleRatio)
    }

    @Test("visibilityFilter で方向側のサンプルだけ数える")
    func visibilityWithFilter() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        // 覆いなしだが、x >= 50 のサンプルのみ可視とみなす
        let result = Occlusion.measureWindowVisibility(
            targetFrame: target, coveringFrames: [],
            visibilityFilter: { px, _ in px >= 50 })
        #expect(result.visibleRatio == 0.5)
    }

    @Test("覆いがなければ中心を返す")
    func uncoveredCenterNoCover() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(
            Occlusion.findUncoveredCenter(windowFrame: frame, coveringFrames: [])
                == CGPoint(x: 50, y: 50))
    }

    @Test("中心が覆われていたら最寄りの露出サンプル点を返す")
    func uncoveredCenterShifted() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        // 左 70% を覆う → 露出は x >= 70
        let covers = [CGRect(x: 0, y: 0, width: 70, height: 100)]
        let point = Occlusion.findUncoveredCenter(windowFrame: frame, coveringFrames: covers)
        #expect(point.x > 70)
    }
}
