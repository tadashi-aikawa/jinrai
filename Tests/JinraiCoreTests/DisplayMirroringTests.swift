import Testing

@testable import JinraiCore

@Suite("DisplayMirroringPlanner")
struct DisplayMirroringPlannerTests {
    private let builtin: UInt32 = 1
    private let projector: UInt32 = 2
    private let monitor: UInt32 = 3

    @Test("1台以下なら切り替えない")
    func unavailable() {
        #expect(DisplayMirroringPlanner.plan([]) == .unavailable)
        #expect(
            DisplayMirroringPlanner.plan([
                DisplayMirrorState(id: builtin, isBuiltin: true, isMain: true)
            ]) == .unavailable)
    }

    @Test("拡張表示なら内蔵ディスプレイを外部へ映す")
    func mirrorFromBuiltin() {
        let plan = DisplayMirroringPlanner.plan([
            DisplayMirrorState(id: projector, isBuiltin: false, isMain: true),
            DisplayMirrorState(id: builtin, isBuiltin: true, isMain: false),
        ])
        #expect(plan == .mirror(source: builtin, targets: [projector]))
    }

    @Test("3台以上なら外部をすべて内蔵ディスプレイのミラーにする")
    func mirrorAllExternals() {
        let plan = DisplayMirroringPlanner.plan([
            DisplayMirrorState(id: builtin, isBuiltin: true, isMain: true),
            DisplayMirrorState(id: projector, isBuiltin: false, isMain: false),
            DisplayMirrorState(id: monitor, isBuiltin: false, isMain: false),
        ])
        #expect(plan == .mirror(source: builtin, targets: [projector, monitor]))
    }

    @Test("内蔵ディスプレイが無ければメインを映す")
    func mirrorFromMainWithoutBuiltin() {
        let plan = DisplayMirroringPlanner.plan([
            DisplayMirrorState(id: projector, isBuiltin: false, isMain: false),
            DisplayMirrorState(id: monitor, isBuiltin: false, isMain: true),
        ])
        #expect(plan == .mirror(source: monitor, targets: [projector]))
    }

    @Test("1台でもミラーしていれば、ミラーしているものだけ解除して拡張表示に戻す")
    func extendWhenMirroring() {
        let plan = DisplayMirroringPlanner.plan([
            DisplayMirrorState(id: builtin, isBuiltin: true, isMain: true),
            DisplayMirrorState(
                id: projector, isBuiltin: false, isMain: false, mirrorSource: builtin),
            DisplayMirrorState(id: monitor, isBuiltin: false, isMain: false),
        ])
        #expect(plan == .extend(displays: [projector]))
    }
}

@Suite("DisplayMirroringConfigBuilder")
struct DisplayMirroringConfigTests {
    @Test("デフォルト値: ホットキーなし, URLイベントなし")
    func defaults() throws {
        let config = try DisplayMirroringConfigBuilder.build()
        #expect(config.hotkeyModifiers == [])
        #expect(config.hotkeyKey == nil)
        #expect(config.urlEventName == nil)
    }

    @Test("上書きできる")
    func overrides() throws {
        let config = try DisplayMirroringConfigBuilder.build([
            "hotkey": ["modifiers": ["ctrl", "alt"], "key": "m"],
            "urlEvent": ["name": "display-mirroring"],
        ])
        #expect(config.hotkeyModifiers == ["ctrl", "alt"])
        #expect(config.hotkeyKey == "m")
        #expect(config.urlEventName == "display-mirroring")
    }

    @Test("セクションを書けば有効になり、profiles で上書きできる")
    func rootSection() throws {
        #expect(try RootConfigBuilder.build(text: "{}").displayMirroring == nil)
        #expect(
            try RootConfigBuilder.build(text: #"{ "displayMirroring": {} }"#).displayMirroring
                != nil)
        let config = try RootConfigBuilder.build(
            text: #"""
                {
                  "profiles": [
                    {
                      "displays": ["11111111-2222-3333-4444-555555555555"],
                      "overrides": { "displayMirroring": { "hotkey": { "key": "m" } } }
                    }
                  ]
                }
                """#,
            connectedDisplayUUIDs: ["11111111-2222-3333-4444-555555555555"])
        #expect(config.displayMirroring?.hotkeyKey == "m")
    }
}
