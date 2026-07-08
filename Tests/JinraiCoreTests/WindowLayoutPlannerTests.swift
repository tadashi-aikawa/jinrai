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

    @Test("前面順で最初にマッチした1枚だけ配置する")
    func matchesFirstInFrontOrder() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry()],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "Front"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "Back"),
            ],
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
            screens: [mainScreen])
        #expect(plan.placements.map(\.windowID) == [1])
        #expect(plan.focusEntryIndex == 0)
    }

    @Test("titleGlob でウィンドウを絞り込む")
    func titleGlobFilters() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(titleGlob: "*GitHub*")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "Gmail"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "PR - GitHub"),
            ],
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
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
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
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
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
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
            runningBundleIDs: ["com.google.Chrome"], screens: [mainScreen])
        #expect(plan.placements.count == 1)
        #expect(plan.placements[0].windowID == 5)
        #expect(plan.placements[0].needsUnminimize)
    }

    @Test("screen UUID でディスプレイを解決し、未接続はメインへフォールバック")
    func screenResolution() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [
                entry(screen: "sub-uuid", area: "full"),  // 大小文字は無視して一致
                entry(titleGlob: "B", screen: "GONE-UUID", area: "full"),
                entry(titleGlob: "C", area: "full"),  // screen 未指定
            ],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
                WindowInfo(id: 3, pid: 100, bundleID: "com.google.Chrome", title: "C"),
            ],
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
            screens: [mainScreen, subScreen])
        #expect(plan.placements[0].frame == subScreen.visibleFrame)
        #expect(plan.placements[1].frame == mainScreen.visibleFrame)
        #expect(plan.placements[2].frame == mainScreen.visibleFrame)
    }

    @Test("未起動かつ launch=true のエントリだけが起動待ちに回る")
    func pendingLaunch() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [
                entry(bundleID: "not.running.launch", launch: true),
                entry(bundleID: "not.running.no.launch"),
                entry(bundleID: "running.but.no.match", launch: true),
            ],
            onScreenWindows: [], minimizedWindows: [],
            runningBundleIDs: ["running.but.no.match"],
            screens: [mainScreen])
        #expect(plan.placements.isEmpty)
        // 起動済みでマッチしない場合は launch=true でもスキップ
        #expect(plan.pendingLaunchIndices == [0])
        #expect(plan.focusEntryIndex == nil)
    }

    @Test("focusEntryIndex は配列で最後にマッチしたエントリ")
    func focusIsLastMatched() {
        let plan = WindowLayoutPlanner.makePlan(
            entries: [entry(), entry(bundleID: "not.running"), entry(titleGlob: "B")],
            onScreenWindows: [
                WindowInfo(id: 1, pid: 100, bundleID: "com.google.Chrome", title: "A"),
                WindowInfo(id: 2, pid: 100, bundleID: "com.google.Chrome", title: "B"),
            ],
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
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
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
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
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
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
            minimizedWindows: [], runningBundleIDs: ["com.google.Chrome"],
            screens: [mainScreen])
        #expect(plan.placements[0].frame == CGRect(x: 0, y: 25, width: 800, height: 875))
    }
}
