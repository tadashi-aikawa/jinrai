import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("CycleState")
struct CycleStateTests {
    let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let ratios = CycleState.defaultRatios

    /// 元 spec「横方向の cycle は 1/2、1/3、2/3 の順で幅を切り替える」を再現
    @Test("cycleLeft の反復で 1/2 → 1/3 → 2/3 を巡回する")
    func horizontalCycleSequence() {
        var state = CycleState()
        var frame = CGRect(x: 50, y: 50, width: 500, height: 300)
        var applied: [CGRect] = []

        for _ in 0..<4 {
            let index = state.nextIndex(
                command: .cycleLeft, currentFrame: frame, ratioCount: ratios.count)
            let target = CycleState.targetFrame(
                command: .cycleLeft, ratio: ratios[index], screenFrame: screen)
            applied.append(target)
            frame = target  // setFrame 成功を模擬
            state.recordApplied(command: .cycleLeft, index: index, actualFrame: frame)
        }

        #expect(applied[0] == CGRect(x: 0, y: 0, width: 600, height: 900))
        #expect(applied[1] == CGRect(x: 0, y: 0, width: 400, height: 900))
        #expect(applied[2] == CGRect(x: 0, y: 0, width: 800, height: 900))
        #expect(applied[3] == CGRect(x: 0, y: 0, width: 600, height: 900))
    }

    @Test("コマンドが変わると先頭の比率から再開する")
    func commandChangeRestartsCycle() {
        var state = CycleState()
        var frame = CGRect(x: 0, y: 0, width: 600, height: 900)
        state.recordApplied(command: .cycleLeft, index: 0, actualFrame: frame)

        let index = state.nextIndex(
            command: .cycleHorizontalCenter, currentFrame: frame, ratioCount: ratios.count)
        #expect(index == 0)
        let target = CycleState.targetFrame(
            command: .cycleHorizontalCenter, ratio: ratios[index], screenFrame: screen)
        #expect(target == CGRect(x: 300, y: 0, width: 600, height: 900))
        frame = target
        state.recordApplied(command: .cycleHorizontalCenter, index: index, actualFrame: frame)

        let next = state.nextIndex(
            command: .cycleHorizontalCenter, currentFrame: frame, ratioCount: ratios.count)
        let nextTarget = CycleState.targetFrame(
            command: .cycleHorizontalCenter, ratio: ratios[next], screenFrame: screen)
        #expect(nextTarget == CGRect(x: 400, y: 0, width: 400, height: 900))
    }

    @Test("実 frame が target とずれても記録した実 frame と一致すれば次へ進む")
    func advancesWhenActualFrameDiffers() {
        var state = CycleState()
        // target 400 に対しアプリが 360 に丸めたケース
        let actual = CGRect(x: 0, y: 0, width: 360, height: 900)
        state.recordApplied(command: .cycleLeft, index: 1, actualFrame: actual)

        let index = state.nextIndex(
            command: .cycleLeft, currentFrame: actual, ratioCount: ratios.count)
        #expect(index == 2)
    }

    @Test("手動リサイズ後は先頭から再開する")
    func manualResizeRestartsCycle() {
        var state = CycleState()
        state.recordApplied(
            command: .cycleLeft, index: 2,
            actualFrame: CGRect(x: 0, y: 0, width: 800, height: 900))

        let manual = CGRect(x: 0, y: 0, width: 500, height: 900)
        let index = state.nextIndex(
            command: .cycleLeft, currentFrame: manual, ratioCount: ratios.count)
        #expect(index == 0)
    }

    @Test("縦方向の cycle は高さを切り替える")
    func verticalCycle() {
        let target = CycleState.targetFrame(
            command: .cycleBottom, ratio: 1 / 3, screenFrame: screen)
        #expect(target == CGRect(x: 0, y: 600, width: 1200, height: 300))
    }
}

@Suite("AreaSpec")
struct AreaSpecTests {
    let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)

    @Test("full はスクリーン全体")
    func full() {
        #expect(AreaSpec.frame(for: "full", screenFrame: screen) == screen)
    }

    @Test("half 系")
    func halves() {
        #expect(
            AreaSpec.frame(for: "halfLeft", screenFrame: screen)
                == CGRect(x: 0, y: 0, width: 600, height: 900))
        #expect(
            AreaSpec.frame(for: "halfHorizontalCenter", screenFrame: screen)
                == CGRect(x: 300, y: 0, width: 600, height: 900))
        #expect(
            AreaSpec.frame(for: "halfBottom", screenFrame: screen)
                == CGRect(x: 0, y: 450, width: 1200, height: 450))
    }

    @Test("quarter の四隅とストリップ")
    func quarters() {
        #expect(
            AreaSpec.frame(for: "quarterTopRight", screenFrame: screen)
                == CGRect(x: 600, y: 0, width: 600, height: 450))
        #expect(
            AreaSpec.frame(for: "quarterHorizontalRightCenter", screenFrame: screen)
                == CGRect(x: 600, y: 0, width: 300, height: 900))
    }

    @Test("sixth は 3列×2行")
    func sixths() {
        #expect(
            AreaSpec.frame(for: "sixthBottomCenter", screenFrame: screen)
                == CGRect(x: 400, y: 450, width: 400, height: 450))
    }

    @Test("twoThirdsCenter はディスプレイ中央の 2/3")
    func twoThirdsCenter() {
        #expect(
            AreaSpec.frame(for: "twoThirdsCenter", screenFrame: screen)
                == CGRect(x: 200, y: 150, width: 800, height: 600))
    }

    @Test("固定サイズ中央: 画面内に収まるよう調整される")
    func fixedSizeCenter() {
        #expect(
            AreaSpec.frame(for: "800x600Center", screenFrame: screen)
                == CGRect(x: 200, y: 150, width: 800, height: 600))
        // 画面より大きい指定はクランプ
        #expect(
            AreaSpec.frame(for: "1920x1080Center", screenFrame: screen)
                == CGRect(x: 0, y: 0, width: 1200, height: 900))
    }

    @Test("未知のエリア名は nil")
    func unknownArea() {
        #expect(AreaSpec.frame(for: "unknown", screenFrame: screen) == nil)
        #expect(AreaSpec.frame(for: "freeArea", screenFrame: screen) == nil)
    }

    @Test("kind の判定")
    func kinds() {
        #expect(AreaSpec.kind(of: "full") == .full)
        #expect(AreaSpec.kind(of: "freeArea") == .freeArea)
        #expect(AreaSpec.kind(of: "halfLeft") == .half)
        #expect(AreaSpec.kind(of: "threeQuartersTop") == .threeQuarters)
        #expect(AreaSpec.kind(of: "1920x1080Center") == .fixedSizeCenter)
        #expect(AreaSpec.kind(of: "unknown") == nil)
    }
}
