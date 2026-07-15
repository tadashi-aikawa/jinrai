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
        syncTargets: Set<String> = [],
        visibility: @escaping (FakeWindow) -> Bool = { $0.visible },
        listed: @escaping (FakeWindow) -> Bool = { _ in true }
    ) -> FocusHistoryLogic<FakeWindow> {
        FocusHistoryLogic(
            syncTargetApps: syncTargets,
            windowID: { $0.id },
            appKey: { $0.appKey },
            isVisible: visibility,
            isListedInApp: listed
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

    @Test("ネイティブタブアプリの同一アプリ内タブ切替は履歴に積まない")
    func nativeTabsSwitchNotPromoted() {
        // 非選択タブのウィンドウはアプリのウィンドウ一覧から消える(実機挙動)
        var listedIDs: Set<UInt32> = [1, 10, 11]
        let logic = makeLogic(
            syncTargets: ["com.mitchellh.ghostty"], listed: { listedIDs.contains($0.id) })
        let other = FakeWindow(id: 1, appKey: "app.other")
        let tab1 = FakeWindow(id: 10, appKey: "com.mitchellh.ghostty")
        let tab2 = FakeWindow(id: 11, appKey: "com.mitchellh.ghostty")
        logic.updateWindowState(other)
        logic.updateWindowState(tab1)
        listedIDs.remove(10)  // タブ切替で tab1 が列挙から消える
        logic.updateWindowState(tab2)  // タブ切替 → tab1 は履歴に積まれない

        #expect(logic.focusBack(focused: tab2)?.id == 1)
    }

    @Test("ネイティブタブアプリでも別ウィンドウへの切替は履歴に積む")
    func nativeTabsSeparateWindowPromoted() {
        // 別ウィンドウは切替後もウィンドウ一覧に残る → タブ切替ではない
        let logic = makeLogic(syncTargets: ["com.mitchellh.ghostty"], listed: { _ in true })
        let other = FakeWindow(id: 1, appKey: "app.other")
        let win1 = FakeWindow(id: 10, appKey: "com.mitchellh.ghostty")
        let win2 = FakeWindow(id: 11, appKey: "com.mitchellh.ghostty")
        logic.updateWindowState(other)
        logic.updateWindowState(win1)
        logic.updateWindowState(win2)

        #expect(logic.focusBack(focused: win2)?.id == 10)
    }

    @Test("ネイティブタブ対象外アプリの同一アプリ内切替は通常どおり履歴に積む")
    func nonSyncTargetSameAppPromoted() {
        let logic = makeLogic(syncTargets: ["com.mitchellh.ghostty"])
        let w1 = FakeWindow(id: 1, appKey: "app.other")
        let w2 = FakeWindow(id: 2, appKey: "app.other")
        logic.updateWindowState(w1)
        logic.updateWindowState(w2)

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
