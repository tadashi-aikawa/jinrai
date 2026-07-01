import CoreGraphics
import Testing

@testable import JinraiCore

/// 元 spec(window_hints_spec.lua)の findDirectionalWindowTarget ケースを移植。
/// 元 spec は config 未指定キーが 0 / 無効になるため、明示的に同じ値を渡す。
@Suite("DirectionScoring")
struct DirectionScoringTests {
    func win(_ id: UInt32, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> WindowInfo {
        WindowInfo(id: id, frame: CGRect(x: x, y: y, width: w, height: h))
    }

    /// 元 spec 相当: tieThreshold=0, sampling 無効, preferredVisibleRatio 指定
    func specConfig(preferredVisibleRatio: Double = 0) -> DirectionScoring.Config {
        DirectionScoring.Config(
            cardinalOverlapTieThresholdPx: 0,
            preferredVisibleRatio: preferredVisibleRatio,
            sampling: .init(enabled: false)
        )
    }

    @Test("右: 単純に右にある候補を選ぶ")
    func simpleRight() {
        let current = win(1, 0, 0, 100, 100)
        let right = win(2, 200, 0, 100, 100)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current, candidates: [right], direction: .right,
            orderedWindows: [current, right], config: specConfig())
        #expect(target?.id == 2)
    }

    @Test("右: 左にある候補は選ばない")
    func rightExcludesLeft() {
        let current = win(1, 200, 0, 100, 100)
        let left = win(2, 0, 0, 100, 100)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current, candidates: [left], direction: .right,
            orderedWindows: [current, left], config: specConfig())
        #expect(target == nil)
    }

    @Test("上下左右: preferredVisibleRatio は移動方向側の露出を優先する")
    func prefersExposedInDirection() {
        let current = win(1, 65, 20, 20, 60)
        let containingRight = win(2, 0, 0, 100, 100)
        let exposedRight = win(3, 130, 20, 80, 60)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [containingRight, exposedRight],
            direction: .right,
            orderedWindows: [current, containingRight, exposedRight],
            config: specConfig(preferredVisibleRatio: 0.5))
        #expect(target?.id == 3)
    }

    @Test("上下左右: 移動方向の大きな背面候補より内側の前面候補を優先する")
    func prefersForegroundInside() {
        let current = win(1, 0, 0, 100, 120)
        let backgroundRight = win(2, 110, 0, 170, 120)
        let foregroundInside = win(3, 140, 25, 70, 70)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [backgroundRight, foregroundInside],
            direction: .right,
            orderedWindows: [current, foregroundInside, backgroundRight],
            config: specConfig(preferredVisibleRatio: 0.5))
        #expect(target?.id == 3)
    }

    @Test("上下左右: 内包された候補をウィンドウ順序に依存せず優先する")
    func prefersContainedRegardlessOfOrder() {
        let current = win(1, 320, 0, 100, 120)
        let containingLeft = win(2, 0, 0, 280, 120)
        let containedLeft = win(3, 170, 25, 70, 70)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [containingLeft, containedLeft],
            direction: .left,
            orderedWindows: [current, containingLeft, containedLeft],
            config: specConfig(preferredVisibleRatio: 0.5))
        #expect(target?.id == 3)
    }

    @Test("上下左右: 数pxはみ出した内包候補も移動先として優先する")
    func prefersSlightlyProtrudingContained() {
        let current = win(1, 320, 0, 100, 120)
        let containingLeft = win(2, 0, 0, 280, 120)
        let slightlyProtrudingLeft = win(3, 206, 25, 80, 70)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [containingLeft, slightlyProtrudingLeft],
            direction: .left,
            orderedWindows: [current, containingLeft, slightlyProtrudingLeft],
            config: specConfig(preferredVisibleRatio: 0.5))
        #expect(target?.id == 3)
    }

    @Test("直交重なりが大きい候補を優先する")
    func prefersLargerOrthogonalOverlap() {
        let current = win(1, 0, 0, 100, 100)
        let alignedRight = win(2, 200, 0, 100, 100)  // 重なり100
        let offsetRight = win(3, 200, 80, 100, 100)  // 重なり20
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [offsetRight, alignedRight],
            direction: .right,
            orderedWindows: [current, offsetRight, alignedRight],
            config: specConfig())
        #expect(target?.id == 2)
    }

    @Test("重なり同等なら主軸ギャップが小さい候補を優先する")
    func prefersSmallerPrimaryGap() {
        let current = win(1, 0, 0, 100, 100)
        let near = win(2, 150, 0, 100, 100)
        let far = win(3, 400, 0, 100, 100)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [far, near],
            direction: .right,
            orderedWindows: [current, far, near],
            config: specConfig())
        #expect(target?.id == 2)
    }

    @Test("重なりの差が tieThreshold 以下なら主軸ギャップで選ぶ")
    func tieThresholdFallsBackToGap() {
        let current = win(1, 0, 0, 100, 720)
        let bigOverlapFar = win(2, 500, 0, 100, 720)  // 重なり720, ギャップ400
        let smallOverlapNear = win(3, 150, 0, 100, 200)  // 重なり200, ギャップ50
        var config = specConfig()
        config.cardinalOverlapTieThresholdPx = 720
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [bigOverlapFar, smallOverlapNear],
            direction: .right,
            orderedWindows: [current, bigOverlapFar, smallOverlapNear],
            config: config)
        #expect(target?.id == 3)
    }

    @Test("主軸が重なる(detached でない)候補は直交重なり50%が必要")
    func requiresOrthogonalOverlapWhenPrimaryOverlaps() {
        let current = win(1, 0, 0, 200, 100)
        // 主軸(x)が大きく重なるが、直交(y)の重なりが小さい → 候補外
        let overlappingButOffset = win(2, 100, 95, 200, 100)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [overlappingButOffset],
            direction: .right,
            orderedWindows: [current, overlappingButOffset],
            config: specConfig())
        #expect(target == nil)
    }

    @Test("斜め: 右下の候補を選ぶ")
    func diagonalDownRight() {
        let current = win(1, 0, 0, 100, 100)
        let downRight = win(2, 200, 200, 100, 100)
        let upRight = win(3, 200, -200, 100, 100)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [upRight, downRight],
            direction: .downRight,
            orderedWindows: [current, upRight, downRight],
            config: specConfig())
        #expect(target?.id == 2)
    }

    @Test("斜め: ギャップ合計が小さい候補を優先する")
    func diagonalPrefersSmallerGap() {
        let current = win(1, 0, 0, 100, 100)
        let near = win(2, 150, 150, 100, 100)
        let far = win(3, 400, 400, 100, 100)
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: [far, near],
            direction: .downRight,
            orderedWindows: [current, far, near],
            config: specConfig())
        #expect(target?.id == 2)
    }

    @Test("完全に隠れたウィンドウの判定")
    func fullyOccludedWindowDetection() {
        let front = win(10, 0, 0, 300, 300)
        let hidden = win(11, 50, 50, 100, 100)
        let ordered = [front, hidden]
        #expect(
            DirectionScoring.isFullyOccludedWindow(
                hidden, orderedWindows: ordered, config: specConfig()))
        #expect(
            !DirectionScoring.isFullyOccludedWindow(
                front, orderedWindows: ordered, config: specConfig()))
    }
}
