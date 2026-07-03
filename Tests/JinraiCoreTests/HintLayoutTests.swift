import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("HintLayout")
struct HintLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func item(
        _ key: String, x: CGFloat, y: CGFloat, w: CGFloat = 80, h: CGFloat = 32
    ) -> HintLayout.Item {
        HintLayout.Item(key: key, center: CGPoint(x: x, y: y), width: w, height: h)
    }

    /// 全ペアで gap 込みの交差がないこと
    func assertNoOverlap(_ placements: [HintLayout.Placement], gap: CGFloat = 4) {
        for i in 0..<placements.count {
            for j in (i + 1)..<placements.count {
                let a = placements[i].frame
                let b = placements[j].frame
                let overlapX = min(a.maxX, b.maxX) - max(a.minX, b.minX) + gap
                let overlapY = min(a.maxY, b.maxY) - max(a.minY, b.minY) + gap
                #expect(
                    overlapX <= 0.001 || overlapY <= 0.001,
                    "\(placements[i].key) が \(placements[j].key) と重なっている")
            }
        }
    }

    func assertWithinScreen(_ placements: [HintLayout.Placement]) {
        for p in placements {
            #expect(p.frame.minX >= screen.minX - 0.001)
            #expect(p.frame.maxX <= screen.maxX + 0.001)
            #expect(p.frame.minY >= screen.minY - 0.001)
            #expect(p.frame.maxY <= screen.maxY + 0.001)
        }
    }

    @Test("重ならない入力は希望位置のまま動かない")
    func noOverlapKeepsPositions() {
        let items = [
            item("A", x: 200, y: 200),
            item("B", x: 600, y: 400),
            item("C", x: 1200, y: 800),
        ]
        let placements = HintLayout.layout(items: items, screenFrame: screen)
        for placement in placements {
            let original = items.first { $0.key == placement.key }!
            #expect(placement.frame.midX == original.center.x)
            #expect(placement.frame.midY == original.center.y)
        }
        assertNoOverlap(placements)
    }

    @Test("同一 center の2件は縦方向に分離される")
    func identicalCentersSeparateVertically() {
        let items = [item("A", x: 960, y: 540), item("B", x: 960, y: 540)]
        let placements = HintLayout.layout(items: items, screenFrame: screen)
        assertNoOverlap(placements)
        assertWithinScreen(placements)
        // 横位置は変わらず、縦にずれる
        for p in placements {
            #expect(p.frame.midX == 960)
        }
        #expect(placements[0].frame.midY != placements[1].frame.midY)
    }

    @Test("密集クラスタ(8件)でも全件が非重複・画面内")
    func denseClusterResolves() {
        let items = (0..<8).map {
            item("K\($0)", x: 960 + CGFloat($0 % 3) * 10, y: 540 + CGFloat($0 / 3) * 8)
        }
        let placements = HintLayout.layout(items: items, screenFrame: screen)
        #expect(placements.count == 8)
        assertNoOverlap(placements)
        assertWithinScreen(placements)
    }

    @Test("画面隅にクランプされた密集も非重複・画面内")
    func cornerClusterResolves() {
        // 画面外にはみ出す希望位置 → クランプで全件が左上隅に集まるケース
        let items = (0..<5).map { item("K\($0)", x: 10, y: 10) }
        let placements = HintLayout.layout(items: items, screenFrame: screen)
        assertNoOverlap(placements)
        assertWithinScreen(placements)
    }

    @Test("入力順を逆にしても同一結果(決定性)")
    func deterministicRegardlessOfInputOrder() {
        let items = [
            item("A", x: 960, y: 540),
            item("B", x: 970, y: 545),
            item("C", x: 950, y: 535),
            item("D", x: 960, y: 540),
        ]
        let forward = HintLayout.layout(items: items, screenFrame: screen)
        let backward = HintLayout.layout(items: items.reversed(), screenFrame: screen)
        let forwardByKey = Dictionary(uniqueKeysWithValues: forward.map { ($0.key, $0.frame) })
        for p in backward {
            #expect(forwardByKey[p.key] == p.frame, "\(p.key) の配置が入力順で変わった")
        }
    }

    @Test("obstacles(dockヒント等)とも重ならない")
    func avoidsObstacles() {
        // 画面中央に大きな障害物(プレビュー背景つき dock ヒント相当)
        let obstacle = CGRect(x: 760, y: 340, width: 400, height: 400)
        let items = [item("A", x: 960, y: 540), item("B", x: 960, y: 540)]
        let placements = HintLayout.layout(
            items: items, screenFrame: screen, obstacles: [obstacle])
        assertNoOverlap(placements)
        assertWithinScreen(placements)
        for p in placements {
            let padded = p.frame.insetBy(dx: -4, dy: -4)
            #expect(!padded.intersects(obstacle), "\(p.key) が障害物と重なっている")
        }
    }

    @Test("部分交差は最小移動で分離される")
    func partialOverlapMovesMinimally() {
        // 縦に半分だけ重なる2件 → 先勝ちで A は動かず、B が下へ最小限ずれる
        let items = [item("A", x: 960, y: 540), item("B", x: 960, y: 556)]
        let placements = HintLayout.layout(items: items, screenFrame: screen)
        assertNoOverlap(placements)
        let a = placements.first { $0.key == "A" }!
        let b = placements.first { $0.key == "B" }!
        #expect(a.frame.midY == 540)
        // B の移動量は重なり解消に必要な分(16 + gap 4)だけ
        #expect(abs(b.frame.midY - 556) <= 20.001, "B の移動量が過大")
        for p in placements {
            #expect(p.frame.midX == 960)
        }
    }
}
