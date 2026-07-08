import Testing

@testable import JinraiCore

@Suite("WindowLayoutPickerLogic")
struct WindowLayoutPickerLogicTests {
    private func logic(
        names: [String] = ["dev", "meeting", "Design", "review"],
        maxVisibleRows: Int = 3
    ) -> WindowLayoutPickerLogic {
        .init(
            items: names.map { .init(name: $0) },
            maxVisibleRows: maxVisibleRows)
    }

    @Test("空クエリでは全件を表示する")
    func emptyQueryShowsAll() {
        let logic = logic()
        #expect(logic.filtered.count == 4)
        #expect(logic.visibleItems.map(\.name) == ["dev", "meeting", "Design"])
        #expect(logic.selectedItem?.name == "dev")
    }

    @Test("name の部分一致でフィルタされる(大文字小文字無視)")
    func filtersByNameCaseInsensitive() {
        var logic = logic()
        logic.append("DE")
        #expect(logic.filtered.map(\.name) == ["dev", "Design"])
    }

    @Test("description も検索対象になる")
    func filtersByDescription() {
        var logic = WindowLayoutPickerLogic(
            items: [
                .init(name: "開発", description: "dev layout"),
                .init(name: "会議", description: nil),
            ],
            maxVisibleRows: 5)
        logic.append("dev")
        #expect(logic.filtered.map(\.name) == ["開発"])
    }

    @Test("不一致なら0件で selectedItem は nil")
    func noMatch() {
        var logic = logic()
        logic.append("zzz")
        #expect(logic.filtered.isEmpty)
        #expect(logic.selectedItem == nil)
        #expect(logic.visibleItems.isEmpty)
    }

    @Test("0件のとき move しても壊れない")
    func moveOnEmptyIsSafe() {
        var logic = logic()
        logic.append("zzz")
        logic.moveDown()
        logic.moveUp()
        #expect(logic.selectedItem == nil)
    }

    @Test("文字追加・Backspace で選択とスクロールが先頭にリセットされる")
    func inputResetsSelection() {
        var logic = logic()
        logic.moveDown()
        logic.moveDown()
        logic.moveDown()
        #expect(logic.selectedIndex == 3)
        #expect(logic.scrollOffset == 1)

        logic.append("e")
        #expect(logic.selectedIndex == 0)
        #expect(logic.scrollOffset == 0)

        logic.moveDown()
        logic.deleteBackward()
        #expect(logic.selectedIndex == 0)
        #expect(logic.scrollOffset == 0)
        #expect(logic.query.isEmpty)
    }

    @Test("クエリ差し替えで選択とスクロールが先頭にリセットされる")
    func setQueryResetsSelection() {
        var logic = logic()
        logic.moveDown()
        logic.moveDown()
        #expect(logic.selectedIndex == 2)

        logic.setQuery("de")
        #expect(logic.query == "de")
        #expect(logic.filtered.map(\.name) == ["dev", "Design"])
        #expect(logic.selectedIndex == 0)
        #expect(logic.scrollOffset == 0)
    }

    @Test("選択移動は端でクランプされる(ラップしない)")
    func moveClampsAtEdges() {
        var logic = logic()
        logic.moveUp()
        #expect(logic.selectedIndex == 0)
        for _ in 0..<10 { logic.moveDown() }
        #expect(logic.selectedIndex == 3)
    }

    @Test("maxVisibleRows を超えると表示窓がスクロールする")
    func scrollWindowFollowsSelection() {
        var logic = logic()
        // 下移動: 窓の下端を越えたら前進
        logic.moveDown()
        logic.moveDown()
        #expect(logic.scrollOffset == 0)
        logic.moveDown()
        #expect(logic.scrollOffset == 1)
        #expect(logic.visibleItems.map(\.name) == ["meeting", "Design", "review"])

        // 上移動: 窓の上端を越えたら後退
        logic.moveUp()
        logic.moveUp()
        logic.moveUp()
        #expect(logic.scrollOffset == 0)
        #expect(logic.visibleItems.map(\.name) == ["dev", "meeting", "Design"])
    }
}
