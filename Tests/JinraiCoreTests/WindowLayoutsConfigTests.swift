import Testing

@testable import JinraiCore

@Suite("WindowLayoutsConfigBuilder")
struct WindowLayoutsConfigTests {
    /// 正常系のレイアウト1件分
    private func validLayout(key: String = "1") -> [String: Any] {
        [
            "hotkey": ["modifiers": ["ctrl", "alt"], "key": key],
            "windows": [["bundleID": "com.google.Chrome", "area": "halfLeft"]],
        ]
    }

    @Test("フルパース(titleGlob / screen / launch / windowWaitTimeout)")
    func fullParse() throws {
        let config = try WindowLayoutsConfigBuilder.build([
            "windowWaitTimeout": 5,
            "layouts": [
                "dev": [
                    "hotkey": ["modifiers": ["ctrl", "alt"], "key": "1"],
                    "windows": [
                        [
                            "bundleID": "com.google.Chrome", "titleGlob": "*GitHub*",
                            "screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230",
                            "area": "halfLeft",
                        ],
                        ["bundleID": "md.obsidian", "area": "1200x900Center", "launch": true],
                    ],
                ]
            ],
        ])
        #expect(config.windowWaitTimeout == 5)
        #expect(config.layouts.count == 1)
        let layout = config.layouts[0]
        #expect(layout.name == "dev")
        #expect(layout.hotkey == .init(modifiers: ["ctrl", "alt"], key: "1"))
        #expect(
            layout.windows[0]
                == .init(
                    bundleID: "com.google.Chrome", titleGlob: "*GitHub*",
                    screenUUID: "37D8832A-2D66-02CA-B9F7-8F30A301B230",
                    area: "halfLeft", launch: false))
        #expect(layout.windows[1].launch == true)
        #expect(layout.windows[1].titleGlob == nil)
        #expect(layout.windows[1].screenUUID == nil)
    }

    @Test("windowWaitTimeout のデフォルトは10秒")
    func windowWaitTimeoutDefault() throws {
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": validLayout()]])
        #expect(config.windowWaitTimeout == 10)
    }

    @Test("layouts は名前昇順に整列される")
    func layoutsSortedByName() throws {
        let config = try WindowLayoutsConfigBuilder.build([
            "layouts": ["meeting": validLayout(key: "2"), "dev": validLayout(key: "1")]
        ])
        #expect(config.layouts.map(\.name) == ["dev", "meeting"])
    }

    @Test("layouts が空・未指定ならエラー")
    func emptyLayoutsThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [String: Any]()])
        }
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([:])
        }
    }

    @Test("hotkey.key が無いレイアウトはエラー")
    func missingHotkeyThrows() {
        var layout = validLayout()
        layout["hotkey"] = nil
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("レイアウト間のホットキー重複はエラー(modifiers の順序・大小文字は無視)")
    func duplicateHotkeyThrows() {
        var other = validLayout()
        other["hotkey"] = ["modifiers": ["alt", "Ctrl"], "key": "1"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": ["a": validLayout(), "b": other]
            ])
        }
    }

    @Test("windows が空ならエラー")
    func emptyWindowsThrows() {
        var layout = validLayout()
        layout["windows"] = [[String: Any]]()
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("bundleID は必須")
    func bundleIDRequired() {
        var layout = validLayout()
        layout["windows"] = [["area": "halfLeft"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("area は必須かつ既知のエリア名")
    func areaValidation() {
        var noArea = validLayout()
        noArea["windows"] = [["bundleID": "a.b"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": noArea]])
        }
        var unknownArea = validLayout()
        unknownArea["windows"] = [["bundleID": "a.b", "area": "unknownArea"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": unknownArea]])
        }
    }

    @Test("area に freeArea は使えない")
    func freeAreaThrows() {
        var layout = validLayout()
        layout["windows"] = [["bundleID": "a.b", "area": "freeArea"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("titleGlob の空文字はエラー")
    func emptyTitleGlobThrows() {
        var layout = validLayout()
        layout["windows"] = [["bundleID": "a.b", "area": "halfLeft", "titleGlob": ""]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("windowWaitTimeout が0以下ならエラー")
    func nonPositiveTimeoutThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": ["a": validLayout()], "windowWaitTimeout": 0,
            ])
        }
    }

    @Test("RootConfig 経由でセクションが有効になる")
    func rootConfigSection() throws {
        let text = """
            {
                "windowLayouts": {
                    "layouts": {
                        "dev": {
                            "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
                            "windows": [{ "bundleID": "a.b", "area": "halfLeft" }]
                        }
                    }
                }
            }
            """
        let config = try RootConfigBuilder.build(text: text)
        #expect(config.windowLayouts?.layouts.count == 1)
    }
}
