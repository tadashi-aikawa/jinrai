import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("FreeArea")
struct FreeAreaTests {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("占有なしなら画面全体が最良の空き領域")
    func noOccupied() {
        let best = FreeArea.bestFreeFrame(
            screenFrame: screen, occupiedFrames: [], currentFrame: nil)
        #expect(best == screen)
    }

    @Test("左半分が占有されたら右半分が空き")
    func leftHalfOccupied() {
        let occupied = [CGRect(x: 0, y: 0, width: 960, height: 1080)]
        let best = FreeArea.bestFreeFrame(
            screenFrame: screen, occupiedFrames: occupied, currentFrame: nil)
        #expect(best == CGRect(x: 960, y: 0, width: 960, height: 1080))
    }

    @Test("面積最大の空き矩形を選ぶ")
    func picksLargestArea() {
        // 中央上寄りの占有 → 下の帯が最大
        let occupied = [CGRect(x: 0, y: 0, width: 1920, height: 400)]
        let best = FreeArea.bestFreeFrame(
            screenFrame: screen, occupiedFrames: occupied, currentFrame: nil)
        #expect(best == CGRect(x: 0, y: 400, width: 1920, height: 680))
    }

    @Test("同面積なら現 frame の中心に近い方を選ぶ")
    func tieBreakByCenterDistance() {
        // 中央の縦帯を占有 → 左右同面積
        let occupied = [CGRect(x: 800, y: 0, width: 320, height: 1080)]
        let current = CGRect(x: 1500, y: 100, width: 300, height: 300)
        let best = FreeArea.bestFreeFrame(
            screenFrame: screen, occupiedFrames: occupied, currentFrame: current)
        #expect(best == CGRect(x: 1120, y: 0, width: 800, height: 1080))
    }

    @Test("同面積・距離指定なしなら上寄り→左寄り")
    func tieBreakByTopLeft() {
        let occupied = [CGRect(x: 800, y: 0, width: 320, height: 1080)]
        let best = FreeArea.bestFreeFrame(
            screenFrame: screen, occupiedFrames: occupied, currentFrame: nil)
        #expect(best == CGRect(x: 0, y: 0, width: 800, height: 1080))
    }

    @Test("全面占有なら空き領域なし")
    func fullyOccupied() {
        let best = FreeArea.bestFreeFrame(
            screenFrame: screen, occupiedFrames: [screen], currentFrame: nil)
        #expect(best == nil)
    }

    @Test("複数占有の矩形差分で空き矩形集合を得る")
    func multipleOccupied() {
        let occupied = [
            CGRect(x: 0, y: 0, width: 960, height: 1080),
            CGRect(x: 960, y: 0, width: 960, height: 540),
        ]
        let frames = FreeArea.freeFramesForScreen(
            screenFrame: screen, occupiedFrames: occupied)
        #expect(frames == [CGRect(x: 960, y: 540, width: 960, height: 540)])
    }

    @Test("隠れた背面ウィンドウは設定により障害物から除外される")
    func occupiedFramesExcludeHiddenWindows() {
        let front = WindowInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let hidden = WindowInfo(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let standard = [front, hidden]
        let screenFrame = CGRect(x: 0, y: 0, width: 200, height: 100)

        #expect(
            FreeArea.occupiedFrames(
                screenFrame: screenFrame,
                standardWindows: standard,
                activeWindowID: nil,
                hiddenWindowThreshold: 1,
                excludeHiddenWindows: true
            ) == [front.frame])

        #expect(
            FreeArea.occupiedFrames(
                screenFrame: screenFrame,
                standardWindows: standard,
                activeWindowID: nil,
                hiddenWindowThreshold: 1,
                excludeHiddenWindows: false
            ) == [front.frame, hidden.frame])
    }
}
