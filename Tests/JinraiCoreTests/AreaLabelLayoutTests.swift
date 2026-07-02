import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("AreaLabelLayout")
struct AreaLabelLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)

    func candidate(_ key: String, _ areaName: String, fixedTopRight: Bool = false)
        -> AreaLabelLayout.Candidate
    {
        let areaFrame =
            areaName == "freeArea"
            ? screen
            : AreaSpec.frame(for: areaName, screenFrame: screen)!
        let size = AreaLabelLayout.labelSize(
            keyBoxWidth: 40, detailLabel: AreaLabelLayout.detailLabel(for: areaName))
        return AreaLabelLayout.Candidate(
            key: key, areaName: areaName, areaFrame: areaFrame,
            labelSize: size, fixedTopRight: fixedTopRight)
    }

    @Test("左端に重なる half/third/quarter は縦に積まれて重ならない")
    func leftEdgeLabelsStackVertically() {
        let candidates = [
            candidate("JW", "halfLeft"),
            candidate("JA", "thirdLeft"),
            candidate("JQ", "quarterLeft"),
        ]
        let frames = AreaLabelLayout.resolveLabelFrames(
            candidates: candidates, screenFrame: screen)
        for i in frames.indices {
            for j in frames.indices where i < j {
                #expect(
                    !frames[i].intersects(frames[j]),
                    "\(candidates[i].key) と \(candidates[j].key) が重なっている")
            }
        }
        // 種別オフセット: half(-28) が third(+28) より上、third が quarter(+52) より上
        #expect(frames[0].minY < frames[1].minY)
        #expect(frames[1].minY < frames[2].minY)
    }

    @Test("freeArea は画面右上に固定され、スタックの影響を受けない")
    func freeAreaFixedTopRight() {
        let candidates = [
            candidate("JD", "full"),
            candidate("JF", "freeArea", fixedTopRight: true),
        ]
        let frames = AreaLabelLayout.resolveLabelFrames(
            candidates: candidates, screenFrame: screen)
        let freeFrame = frames[1]
        #expect(freeFrame.maxX == screen.maxX - AreaLabelLayout.minMargin)
        #expect(freeFrame.minY == screen.minY + AreaLabelLayout.minMargin)
    }

    @Test("グリッド系はその行の中央に配置される")
    func gridLabelPlacedAtRowCenter() {
        let c = candidate("J2", "quarterTopRight")  // 右上クアドラント(row=1/2)
        let frame = AreaLabelLayout.resolveLabelFrames(
            candidates: [c], screenFrame: screen)[0]
        // 水平はエリア中央
        #expect(abs(frame.midX - c.areaFrame.midX) < 1)
        // 垂直は (row-0.5)/rows = 0.25 の位置
        let expectedY = c.areaFrame.minY + (c.areaFrame.height - frame.height) * 0.25
        #expect(abs(frame.minY - expectedY) < 1)
    }

    @Test("縦分割系はスロット中央に配置される")
    func verticalSlotLabelPlacedAtSlotCenter() {
        let c = candidate("LJ", "halfBottom")  // slots=2, index=2 → 0.75
        let frame = AreaLabelLayout.resolveLabelFrames(
            candidates: [c], screenFrame: screen)[0]
        let expectedY = c.areaFrame.minY + (c.areaFrame.height - frame.height) * 0.75
        #expect(abs(frame.minY - expectedY) < 1)
    }

    @Test("多数のラベルが画面下端をはみ出す場合はグループ全体が上へシフトされる")
    func overflowShiftsGroupUp() {
        // 下端付近に初期配置される quarter 系を大量に置いてはみ出させる
        let names = [
            "quarterLeft", "quarterHorizontalLeftCenter",
            "quarterHorizontalRightCenter", "quarterRight",
        ]
        // 全て左端の狭いエリアに重ねる代わりに、同じ full を複数キーで登録
        var candidates = names.enumerated().map { i, _ in candidate("K\(i)", "full") }
        candidates.append(candidate("KX", "quarterBottom"))
        let frames = AreaLabelLayout.resolveLabelFrames(
            candidates: candidates, screenFrame: screen)
        for frame in frames {
            #expect(frame.maxY <= screen.maxY - AreaLabelLayout.minMargin + 0.5)
            #expect(frame.minY >= screen.minY)
        }
    }

    @Test("detailLabel: freeArea と WxHCenter")
    func detailLabels() {
        #expect(AreaLabelLayout.detailLabel(for: "freeArea") == "Free")
        #expect(AreaLabelLayout.detailLabel(for: "1280x720Center") == "1280x720")
        #expect(AreaLabelLayout.detailLabel(for: "halfLeft") == nil)
    }

    @Test("iconSpec: 全エリア名に定義がある")
    func iconSpecCoversAllAreas() {
        for name in WindowMoverConfigBuilder.directAreaCommands {
            #expect(AreaLabelLayout.iconSpec(for: name) != nil, "iconSpec がない: \(name)")
        }
        #expect(AreaLabelLayout.iconSpec(for: "full") != nil)
        #expect(AreaLabelLayout.iconSpec(for: "freeArea") == .free)
        #expect(AreaLabelLayout.iconSpec(for: "1920x1080Center") == .fixedSizeCenter)
    }
}
