import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("DockLayout")
struct DockLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func item(_ key: String, width: CGFloat, winX: CGFloat, winY: CGFloat = 540)
        -> DockLayout.Item
    {
        DockLayout.Item(
            key: key, width: width, height: 100, windowCenterX: winX, windowCenterY: winY)
    }

    /// 横方向に重ならないこと(ソート後の隣接で最小間隔を満たす)
    func assertNoHorizontalOverlap(_ placements: [DockLayout.Placement], gap: CGFloat) {
        let sorted = placements.sorted { $0.frame.minX < $1.frame.minX }
        for i in 1..<sorted.count {
            #expect(
                sorted[i].frame.minX >= sorted[i - 1].frame.maxX - 0.001,
                "\(sorted[i].key) が \(sorted[i - 1].key) と重なっている")
        }
    }

    func assertWithinScreen(_ placements: [DockLayout.Placement]) {
        for p in placements {
            #expect(p.frame.minX >= screen.minX - 0.001)
            #expect(p.frame.maxX <= screen.maxX + 0.001)
            #expect(p.frame.minY >= screen.minY - 0.001)
            #expect(p.frame.maxY <= screen.maxY + 0.001)
        }
    }

    @Test("blend=0: 中央整列で重ならない")
    func centeredNoOverlap() {
        let items = (0..<5).map { item("K\($0)", width: 200, winX: 960) }
        let placements = DockLayout.layout(
            items: items, screenFrame: screen, gap: 12, dockMargin: 96, xBlend: 0, yBlend: 0)
        assertNoHorizontalOverlap(placements, gap: 12)
        assertWithinScreen(placements)
    }

    @Test("ウィンドウが右側に集中してもプレビューが重ならない(報告バグの再現)")
    func clusteredRightNoOverlap() {
        // 全ウィンドウが画面右寄り(x=1600 付近)に集中
        let items = (0..<6).map { item("K\($0)", width: 300, winX: 1500 + CGFloat($0) * 20) }
        let placements = DockLayout.layout(
            items: items, screenFrame: screen, gap: 12, dockMargin: 96,
            xBlend: 0.65, yBlend: 1)
        assertNoHorizontalOverlap(placements, gap: 12)
        assertWithinScreen(placements)
    }

    @Test("ウィンドウ位置へ寄せつつ順序はウィンドウの X 順になる")
    func orderedByWindowX() {
        let items = [
            item("A", width: 200, winX: 1600),
            item("B", width: 200, winX: 300),
            item("C", width: 200, winX: 900),
        ]
        let placements = DockLayout.layout(
            items: items, screenFrame: screen, gap: 12, dockMargin: 96,
            xBlend: 0.65, yBlend: 0)
        let byX = placements.sorted { $0.frame.minX < $1.frame.minX }.map(\.key)
        #expect(byX == ["B", "C", "A"])  // winX 昇順
    }

    @Test("左寄りウィンドウは左に、右寄りは右に配置される(片側余白の解消)")
    func distributedAcrossScreen() {
        let items = [
            item("L", width: 200, winX: 200),
            item("R", width: 200, winX: 1700),
        ]
        let placements = DockLayout.layout(
            items: items, screenFrame: screen, gap: 12, dockMargin: 96,
            xBlend: 0.65, yBlend: 0)
        let byKey = Dictionary(uniqueKeysWithValues: placements.map { ($0.key, $0.frame) })
        // L は画面左半分、R は右半分
        #expect(byKey["L"]!.midX < screen.midX)
        #expect(byKey["R"]!.midX > screen.midX)
    }

    @Test("行に収まらない数は複数行に分割される")
    func splitsIntoRows() {
        // 幅400 × 6個 + gap は 1行(1920)に収まらない → 複数行
        let items = (0..<6).map { item("K\($0)", width: 400, winX: 960) }
        let placements = DockLayout.layout(
            items: items, screenFrame: screen, gap: 12, dockMargin: 96, xBlend: 0, yBlend: 0)
        assertWithinScreen(placements)
        // 同一 Y の行ごとに重ならない
        let rows = Dictionary(grouping: placements) { $0.frame.minY }
        for (_, rowItems) in rows {
            assertNoHorizontalOverlap(rowItems, gap: 12)
        }
        #expect(rows.count >= 2)
    }

    @Test("上半分のウィンドウは Y が画面上端側に寄る")
    func topWindowsMoveUp() {
        let top = item("T", width: 200, winX: 960, winY: 100)  // 画面上半分
        let bottom = item("B", width: 200, winX: 960, winY: 1000)  // 下半分
        let placements = DockLayout.layout(
            items: [top, bottom], screenFrame: screen, gap: 12, dockMargin: 96,
            xBlend: 0, yBlend: 1)
        let byKey = Dictionary(uniqueKeysWithValues: placements.map { ($0.key, $0.frame) })
        #expect(byKey["T"]!.minY < byKey["B"]!.minY)
    }

    @Test("空入力では空配置")
    func emptyItems() {
        #expect(
            DockLayout.layout(
                items: [], screenFrame: screen, gap: 12, dockMargin: 96,
                xBlend: 0.65, yBlend: 1
            ).isEmpty)
    }

    @Test("densityScale: 合計面積が上限内なら縮小しない")
    func densityScaleWithinBudget() {
        let sizes = [CGSize(width: 400, height: 300), CGSize(width: 400, height: 300)]
        #expect(
            DockLayout.densityScale(boxSizes: sizes, screenFrame: screen, maxFillRatio: 0.5)
                == 1)
    }

    @Test("densityScale: 超過時は縮小後の合計面積が上限に一致する")
    func densityScaleShrinksToBudget() {
        // 800×600 × 10 = 4.8M > 1920×1080×0.5 ≈ 1.04M
        let sizes = (0..<10).map { _ in CGSize(width: 800, height: 600) }
        let scale = DockLayout.densityScale(
            boxSizes: sizes, screenFrame: screen, maxFillRatio: 0.5)
        #expect(scale < 1)
        let scaledArea = sizes.reduce(CGFloat(0)) {
            $0 + $1.width * scale * $1.height * scale
        }
        let budget = screen.width * screen.height * 0.5
        #expect(abs(scaledArea - budget) < 0.001)
    }

    @Test("densityScale: 空入力・ゼロ画面では 1 を返す")
    func densityScaleDegenerateInputs() {
        #expect(
            DockLayout.densityScale(boxSizes: [], screenFrame: screen, maxFillRatio: 0.5)
                == 1)
        #expect(
            DockLayout.densityScale(
                boxSizes: [CGSize(width: 800, height: 600)], screenFrame: .zero,
                maxFillRatio: 0.5
            ) == 1)
    }
}
