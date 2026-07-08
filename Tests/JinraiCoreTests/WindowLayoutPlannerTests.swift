import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("WindowLayoutPlanner")
struct WindowLayoutPlannerTests {
    private let mainScreen = WindowLayoutPlanner.ScreenInput(
        uuid: "MAIN-UUID", visibleFrame: CGRect(x: 0, y: 25, width: 1600, height: 875),
        isMain: true)
    private let subScreen = WindowLayoutPlanner.ScreenInput(
        uuid: "SUB-UUID", visibleFrame: CGRect(x: 1600, y: 0, width: 1920, height: 1080),
        isMain: false)

    private func entry(
        bundleID: String = "com.google.Chrome", titleGlob: String? = nil,
        screen: String? = nil, area: String = "halfLeft", launch: Bool = false,
        focus: Bool = false
    ) -> WindowLayoutsConfig.WindowEntry {
        .init(bundleID: bundleID, titleGlob: titleGlob, screenUUID: screen, area: area,
              launch: launch, focus: focus)
    }

    @Test("マッチしうるエントリが1つだけなら全ウィンドウを同じ位置へ配置する(全取り)")
    func uniqueEntryTakesAllMatches() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry()],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "Front"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "Middle"),
                WindowInfo(id: 3, pid: 100, bundleID: "com.google.Chrome", title: "Back"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        // Pass 1 の最前面1枚に続き、Pass 2 で残りが Z順に追加される
        #expect(plan.placements.map(\.windowID) == [1, 2, 3])
        #expect(plan.placements.map(\.entryIndex) == [0, 0, 0])
        #expect(plan.placements.allSatisfy { $0.frame == plan.placements[0].frame })
        #expect(plan.focusEntryIndex == 0)
    }

    @Test("複数エントリにマッチしうるウィンドウは競合として全取りしない")
    func conflictingWindowNotTakenByPass2() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(), entry(area: "halfRight")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
                WindowInfo(id: 3, pid: 100, bundleID: "com.google.Chrome", title: "C"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        // 従来どおり前面から1枚ずつ。3枚目は両エントリにマッチしうるので触らない
        #expect(plan.placements.map(\.windowID) == [1, 2])
    }

    @Test("titleGlob が重なるウィンドウは全取りせず、重ならないウィンドウだけ全取りする")
    func globOverlapConflict() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(titleGlob: "*GitHub*"), entry(area: "halfRight")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "PR - GitHub"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "Gmail"),
                WindowInfo(id: 3, pid: 100, bundleID: "com.google.Chrome", title: "Wiki - GitHub"),
                WindowInfo(id: 4, pid: 100, bundleID: "com.google.Chrome", title: "Calendar"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        // Pass 1: entry0 が 1(GitHub)、entry1 が 2(Gmail)。
        // Pass 2: 3(GitHub)は両エントリにマッチしうるので競合、4(Calendar)は entry1 のみなので全取り
        #expect(plan.placements.map(\.windowID) == [1, 2, 4])
        #expect(plan.placements.map(\.entryIndex) == [0, 1, 1])
    }

    @Test("focus=true のエントリに複数マッチしても最前面の placement が先頭に来る")
    func focusPlacementIsFrontmostOnMultiMatch() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(focus: true)],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "Front"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "Back"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.focusEntryIndex == 0)
        // Feature 側は first(where: entryIndex == focusEntryIndex) でフォーカス先を選ぶ
        #expect(plan.placements.first(where: { $0.entryIndex == 0 })?.windowID == 1)
    }

    @Test("最小化ウィンドウは全取りの対象にならない")
    func minimizedWindowsNotTakenByPass2() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry()],
            onScreenWindows: [],
            minimizedWindows: [
                WindowInfo(id: 5, pid: 100, bundleID: "com.google.Chrome", title: "Min1"),
                WindowInfo(id: 6, pid: 100, bundleID: "com.google.Chrome", title: "Min2"),
            ],
            screens: [mainScreen])
        #expect(plan.placements.map(\.windowID) == [5])
    }

    @Test("全取り分も claim され unlistedWindows に残らない")
    func pass2PlacementsAreClaimed() {
        let windows = [
            WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
            WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
            WindowInfo(id: 3, pid: 101, bundleID: "md.obsidian", title: "C"),
        ]
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry()],
            onScreenWindows: windows,
            minimizedWindows: [],
            screens: [mainScreen])
        let unlisted = WindowLayoutPlanner.unlistedWindows(
            from: windows, keeping: Set(plan.placements.map(\.windowID)))
        #expect(unlisted.map(\.id) == [3])
    }

    @Test("titleGlob でウィンドウを絞り込む")
    func titleGlobFilters() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(titleGlob: "*GitHub*")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "Gmail"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "PR - GitHub"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.placements.map(\.windowID) == [2])
    }

    @Test("マッチしないエントリはスキップされ他エントリに影響しない")
    func unmatchedEntrySkipped() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(bundleID: "not.running"), entry()],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A")
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.placements.map(\.entryIndex) == [1])
        #expect(plan.pendingLaunchIndices.isEmpty)
        #expect(plan.focusEntryIndex == 1)
    }

    @Test("先行エントリが確保したウィンドウは後続にマッチしない")
    func claimedWindowExcluded() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(), entry(area: "halfRight")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.placements.map(\.windowID) == [1, 2])
    }

    @Test("オンスクリーンに無ければ最小化ウィンドウへフォールバック(needsUnminimize)")
    func minimizedFallback() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry()],
            onScreenWindows: [],
            minimizedWindows: [
                WindowInfo(id: 5, pid: 100, bundleID: "com.google.Chrome", title: "Min")
            ],
            screens: [mainScreen])
        #expect(plan.placements.count == 1)
        #expect(plan.placements[0].windowID == 5)
        #expect(plan.placements[0].needsUnminimize)
    }

    @Test("screen UUID でディスプレイを解決し、未指定・未接続はウィンドウの現在位置へフォールバック")
    func screenResolution() {
        // サブディスプレイ上のウィンドウ frame
        let onSub = CGRect(x: 1700, y: 100, width: 800, height: 600)
        let plan = WindowLayoutPlanner.makePlan(
            entries: [
                entry(screen: "sub-uuid", area: "full"),  // 大小文字は無視して一致
                entry(titleGlob: "B", screen: "GONE-UUID", area: "full"),  // 未接続 → 現在位置
                entry(titleGlob: "C", area: "full"),  // screen 未指定 → 現在位置
                entry(titleGlob: "D", area: "full"),  // 現在位置も不明(frame ゼロ)→ メイン
            ],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B", frame: onSub),
                WindowInfo(id: 3, pid: 100, bundleID: "com.google.Chrome", title: "C", frame: onSub),
                WindowInfo(id: 4, pid: 100, bundleID: "com.google.Chrome", title: "D"),
            ],
            minimizedWindows: [],
            screens: [mainScreen, subScreen])
        #expect(plan.placements[0].frame == subScreen.visibleFrame)
        #expect(plan.placements[1].frame == subScreen.visibleFrame)
        #expect(plan.placements[2].frame == subScreen.visibleFrame)
        #expect(plan.placements[3].frame == mainScreen.visibleFrame)
    }

    @Test("screen 未指定ならウィンドウが現在いる(交差面積が最大の)ディスプレイへ配置する")
    func omittedScreenUsesCurrentDisplay() {
        // 両画面をまたぐが、サブ側の面積が大きいウィンドウ
        let straddling = CGRect(x: 1400, y: 100, width: 800, height: 600)
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(area: "full")],
            onScreenWindows: [
                WindowInfo(
                    id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A", frame: straddling)
            ],
            minimizedWindows: [],
            screens: [mainScreen, subScreen])
        #expect(plan.placements[0].frame == subScreen.visibleFrame)
    }

    @Test("ウィンドウが1枚も存在せず launch=true のエントリだけが起動待ちに回る")
    func pendingLaunch() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [
                entry(bundleID: "no.window.launch", launch: true),
                entry(bundleID: "no.window.no.launch"),
                entry(bundleID: "has.window", titleGlob: "no-match", launch: true),
            ],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "has.window", title: "A")
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.placements.isEmpty)
        // ウィンドウが存在して titleGlob 不一致の場合は launch=true でもスキップ
        #expect(plan.pendingLaunchIndices == [0])
        #expect(plan.focusEntryIndex == nil)
    }

    @Test("起動済みでもウィンドウが0枚なら launch=true で起動待ちに回る")
    func pendingLaunchForRunningAppWithoutWindows() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(bundleID: "running.no.window", launch: true)],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "other.app", title: "A")
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        // Planner はプロセスの起動有無を見ない(スナップショットにウィンドウが無ければ launch)
        #expect(plan.pendingLaunchIndices == [0])
    }

    @Test("最小化ウィンドウしか無いアプリは launch 対象にならない")
    func minimizedWindowSuppressesLaunch() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(titleGlob: "no-match", launch: true)],
            onScreenWindows: [],
            minimizedWindows: [
                WindowInfo(id: 5, pid: 100, bundleID: "com.google.Chrome", title: "Min")
            ],
            screens: [mainScreen])
        #expect(plan.pendingLaunchIndices.isEmpty)
    }

    @Test("focusEntryIndex は配列で最後にマッチしたエントリ")
    func focusIsLastMatched() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(), entry(bundleID: "not.running"), entry(titleGlob: "B")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.focusEntryIndex == 2)
        #expect(plan.preferredFocusEntryIndex == nil)
        #expect(plan.fallbackFocusEntryIndex == 2)
    }

    @Test("focus=true のエントリが最後にマッチしたエントリより優先される")
    func explicitFocusWins() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(focus: true), entry(titleGlob: "B")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.focusEntryIndex == 0)
        #expect(plan.preferredFocusEntryIndex == 0)
        #expect(plan.fallbackFocusEntryIndex == 1)
    }

    @Test("focus=true のエントリがマッチしない場合は最後にマッチしたエントリへフォールバック")
    func explicitFocusFallsBackWhenUnmatched() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(bundleID: "not.running", focus: true), entry(titleGlob: "B")],
            onScreenWindows: [
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B")
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.focusEntryIndex == 1)
        #expect(plan.preferredFocusEntryIndex == 0)
        #expect(plan.fallbackFocusEntryIndex == 1)
    }

    @Test("unlistedWindows は確保済みID以外を返す")
    func unlistedWindowsExcludesKeptIDs() {
        let targets = WindowLayoutPlanner.unlistedWindows(
            from: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 101, bundleID: "dev.warp.Warp-Stable", title: "B"),
                WindowInfo(id: 3, pid: 102, bundleID: "md.obsidian", title: "C"),
            ],
            keeping: [1, 3])
        #expect(targets.map(\.id) == [2])
    }

    @Test("エリア名から配置 frame を算出する(halfLeft)")
    func areaFrameComputed() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(area: "halfLeft")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A")
            ],
            minimizedWindows: [],
            screens: [mainScreen])
        #expect(plan.placements[0].frame == CGRect(x: 0, y: 25, width: 800, height: 875))
    }
}
