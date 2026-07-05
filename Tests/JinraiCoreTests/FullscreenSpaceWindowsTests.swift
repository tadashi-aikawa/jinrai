import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("FullscreenSpaceWindows")
struct FullscreenSpaceWindowsTests {
    @Test("本体ウィンドウのみ通し、小さな補助ウィンドウは除外する")
    func filtersAuxiliaryWindows() {
        let ids = FullscreenSpaceWindows.mainWindowIDs(windows: [
            (id: 1, spaceID: 100, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            // Chrome のステータスバブルのような小窓
            (id: 2, spaceID: 100, frame: CGRect(x: 0, y: 1060, width: 300, height: 20)),
            (id: 3, spaceID: 100, frame: CGRect(x: 0, y: 0, width: 400, height: 60)),
        ])
        #expect(ids == [1])
    }

    @Test("Split View の2ウィンドウはどちらも通る")
    func keepsSplitViewWindows() {
        let ids = FullscreenSpaceWindows.mainWindowIDs(windows: [
            (id: 1, spaceID: 100, frame: CGRect(x: 0, y: 0, width: 960, height: 1080)),
            (id: 2, spaceID: 100, frame: CGRect(x: 960, y: 0, width: 960, height: 1080)),
        ])
        #expect(ids == [1, 2])
    }

    @Test("Space ごとに独立して判定する")
    func evaluatesPerSpace() {
        let ids = FullscreenSpaceWindows.mainWindowIDs(windows: [
            (id: 1, spaceID: 100, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            // 別 Space では小さめでもその Space 内で最大なら通る
            (id: 2, spaceID: 200, frame: CGRect(x: 0, y: 0, width: 600, height: 400)),
        ])
        #expect(ids == [1, 2])
    }

    @Test("空入力・面積ゼロは空を返す")
    func handlesEmptyAndZeroArea() {
        #expect(FullscreenSpaceWindows.mainWindowIDs(windows: []) == [])
        #expect(
            FullscreenSpaceWindows.mainWindowIDs(windows: [
                (id: 1, spaceID: 100, frame: .zero)
            ]) == [])
    }
}
