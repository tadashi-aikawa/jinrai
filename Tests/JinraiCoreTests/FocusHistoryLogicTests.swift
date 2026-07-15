import Testing

@testable import JinraiCore

@Suite("FocusHistoryLogic")
struct FocusHistoryLogicTests {
    struct FakeWindow {
        var id: UInt32
        var appKey: String
        var visible = true
    }

    func makeLogic(
        visibility: @escaping (FakeWindow) -> Bool = { $0.visible },
        onAnySpace: @escaping (FakeWindow) -> Bool = { _ in true }
    ) -> FocusHistoryLogic<FakeWindow> {
        FocusHistoryLogic(
            windowID: { $0.id },
            appKey: { $0.appKey },
            isVisible: visibility,
            isOnAnySpace: onAnySpace
        )
    }

    @Test("直前のウィンドウへ交互にトグルできる")
    func togglesBetweenWindows() {
        let logic = makeLogic()
        let a = FakeWindow(id: 1, appKey: "app.a")
        let b = FakeWindow(id: 2, appKey: "app.b")
        logic.updateWindowState(a)
        logic.updateWindowState(b)

        #expect(logic.focusBack(focused: b)?.id == 1)
        #expect(logic.focusBack(focused: a)?.id == 2)
        #expect(logic.focusBack(focused: b)?.id == 1)
    }

    @Test("previousWindow は履歴を消費しない")
    func previousWindowDoesNotConsume() {
        let logic = makeLogic()
        let a = FakeWindow(id: 1, appKey: "app.a")
        let b = FakeWindow(id: 2, appKey: "app.b")
        logic.updateWindowState(a)
        logic.updateWindowState(b)

        #expect(logic.previousWindow()?.id == 1)
        #expect(logic.previousWindow()?.id == 1)
    }

    @Test("不可視のウィンドウはスキップされる")
    func skipsInvisibleWindows() {
        var visibleIDs: Set<UInt32> = [1, 2, 3]
        let logic = makeLogic(visibility: { visibleIDs.contains($0.id) })
        let a = FakeWindow(id: 1, appKey: "app.a")
        let b = FakeWindow(id: 2, appKey: "app.b")
        let c = FakeWindow(id: 3, appKey: "app.c")
        logic.updateWindowState(a)
        logic.updateWindowState(b)
        logic.updateWindowState(c)

        visibleIDs.remove(2)  // b が閉じられた
        #expect(logic.focusBack(focused: c)?.id == 1)
    }

    @Test("同一ウィンドウへの連続フォーカスは履歴に積まない")
    func ignoresSameWindowRefocus() {
        let logic = makeLogic()
        let a = FakeWindow(id: 1, appKey: "app.a")
        let b = FakeWindow(id: 2, appKey: "app.b")
        logic.updateWindowState(a)
        logic.updateWindowState(b)
        logic.updateWindowState(b)

        #expect(logic.focusBack(focused: b)?.id == 1)
    }

    @Test("同一アプリ内のネイティブタブ切替は履歴に積まない")
    func nativeTabsSwitchNotPromoted() {
        // 非選択タブのウィンドウは Space 所属を失う(実機挙動)
        var onSpaceIDs: Set<UInt32> = [1, 10, 11]
        let logic = makeLogic(onAnySpace: { onSpaceIDs.contains($0.id) })
        let other = FakeWindow(id: 1, appKey: "app.other")
        let tab1 = FakeWindow(id: 10, appKey: "app.terminal")
        let tab2 = FakeWindow(id: 11, appKey: "app.terminal")
        logic.updateWindowState(other)
        logic.updateWindowState(tab1)
        onSpaceIDs.remove(10)  // タブ切替で tab1 が Space 所属を失う
        logic.updateWindowState(tab2)  // タブ切替 → tab1 は履歴に積まれない

        #expect(logic.focusBack(focused: tab2)?.id == 1)
    }

    @Test("同一アプリ内でも別ウィンドウへの切替は履歴に積む")
    func sameAppSeparateWindowPromoted() {
        // 別ウィンドウは切替後も Space 所属を保つ → タブ切替ではない
        let logic = makeLogic(onAnySpace: { _ in true })
        let other = FakeWindow(id: 1, appKey: "app.other")
        let win1 = FakeWindow(id: 10, appKey: "app.terminal")
        let win2 = FakeWindow(id: 11, appKey: "app.terminal")
        logic.updateWindowState(other)
        logic.updateWindowState(win1)
        logic.updateWindowState(win2)

        #expect(logic.focusBack(focused: win2)?.id == 10)
    }

    @Test("記録時に積まれてしまった隠れタブも focusBack 時に除外される")
    func staleHiddenTabSkippedOnFocusBack() {
        // Space 所属の反映が AX 通知より遅れると、タブ切替でも遷移元が積まれてしまう。
        // その場合でも focusBack 時点の判定(反映済み)で候補から除外される
        var onSpaceIDs: Set<UInt32> = [1, 10, 11]
        let logic = makeLogic(onAnySpace: { onSpaceIDs.contains($0.id) })
        let other = FakeWindow(id: 1, appKey: "app.other")
        let tab1 = FakeWindow(id: 10, appKey: "app.terminal")
        let tab2 = FakeWindow(id: 11, appKey: "app.terminal")
        logic.updateWindowState(other)
        logic.updateWindowState(tab1)
        logic.updateWindowState(tab2)  // CGS 未反映で tab1 が積まれてしまう
        onSpaceIDs.remove(10)  // focusBack 時点では tab1 は Space 所属を失っている

        #expect(logic.focusBack(focused: tab2)?.id == 1)
    }

    @Test("別アプリへの切替は遷移元の Space 所属に関わらず履歴に積む")
    func crossAppAlwaysPromoted() {
        // 記録時: Space 所属が取れなくても別アプリへの切替なら積む
        var onSpace = false
        let logic = makeLogic(onAnySpace: { _ in onSpace })
        let w1 = FakeWindow(id: 1, appKey: "app.a")
        let w2 = FakeWindow(id: 2, appKey: "app.b")
        logic.updateWindowState(w1)
        logic.updateWindowState(w2)

        onSpace = true  // 取り出し時は Space 所属あり
        #expect(logic.focusBack(focused: w2)?.id == 1)
    }

    @Test("履歴は最大20件で古いものから捨てられる")
    func historyCapped() {
        let logic = makeLogic()
        for id in UInt32(1)...30 {
            logic.updateWindowState(FakeWindow(id: id, appKey: "app.\(id)"))
        }
        // 30 が current。履歴は 10〜29 の20件
        var popped: [UInt32] = []
        var focused = FakeWindow(id: 30, appKey: "app.30")
        while let target = logic.focusBack(focused: focused) {
            popped.append(target.id)
            focused = target
            if popped.count > 40 { break }
        }
        #expect(popped.first == 29)
        // focusBack は current を毎回積み直すため 29 と 30 の交互トグルに収束する
        #expect(popped.count > 20)
    }

    @Test("withSwitching 中のフォーカスイベントは無視される")
    func switchingSuppressesUpdates() {
        let logic = makeLogic()
        let a = FakeWindow(id: 1, appKey: "app.a")
        let b = FakeWindow(id: 2, appKey: "app.b")
        logic.updateWindowState(a)
        logic.withSwitching {
            logic.updateWindowState(b)  // 無視される
        }
        #expect(logic.previousWindow() == nil)
    }
}
