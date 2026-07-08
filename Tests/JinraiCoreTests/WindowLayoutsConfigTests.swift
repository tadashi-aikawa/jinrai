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
                            "focus": true,
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
        #expect(layout.unlistedWindows == nil)
        #expect(
            layout.windows[0]
                == .init(
                    bundleID: "com.google.Chrome", titleGlob: "*GitHub*",
                    screenUUID: "37D8832A-2D66-02CA-B9F7-8F30A301B230",
                    area: "halfLeft", launch: false, focus: true))
        #expect(layout.windows[1].launch == true)
        #expect(layout.windows[1].focus == false)
        #expect(layout.windows[1].titleGlob == nil)
        #expect(layout.windows[1].screenUUID == nil)
    }

    @Test("windowWaitTimeout のデフォルトは10秒")
    func windowWaitTimeoutDefault() throws {
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": validLayout()]])
        #expect(config.windowWaitTimeout == 10)
    }

    @Test("unlistedWindows 未指定は nil(何もしない)")
    func unlistedWindowsDefaultsToNil() throws {
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": validLayout()]])
        #expect(config.layouts[0].unlistedWindows == nil)
    }

    @Test("unlistedWindows: \"close\" をパースできる")
    func unlistedWindowsCloseParse() throws {
        var layout = validLayout()
        layout["unlistedWindows"] = "close"
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        #expect(config.layouts[0].unlistedWindows == .close)
    }

    @Test("unlistedWindows: { screen?, area } をパースできる")
    func unlistedWindowsPlaceParse() throws {
        var layout = validLayout()
        layout["unlistedWindows"] = [
            "screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230", "area": "full",
        ]
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        #expect(
            config.layouts[0].unlistedWindows
                == .place(screenUUID: "37D8832A-2D66-02CA-B9F7-8F30A301B230", area: "full"))

        var noScreen = validLayout()
        noScreen["unlistedWindows"] = ["area": "full"]
        let config2 = try WindowLayoutsConfigBuilder.build(["layouts": ["a": noScreen]])
        #expect(config2.layouts[0].unlistedWindows == .place(screenUUID: nil, area: "full"))
    }

    @Test("unlistedWindows の不正値はエラー")
    func invalidUnlistedWindowsThrows() {
        // "close" 以外の文字列
        var badString = validLayout()
        badString["unlistedWindows"] = "closeall"
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": badString]])
        }
        // area 欠落
        var noArea = validLayout()
        noArea["unlistedWindows"] = ["screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": noArea]])
        }
        // 未知エリア
        var unknownArea = validLayout()
        unknownArea["unlistedWindows"] = ["area": "unknownArea"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": unknownArea]])
        }
        // freeArea 禁止
        var freeArea = validLayout()
        freeArea["unlistedWindows"] = ["area": "freeArea"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": freeArea]])
        }
        // 不正な型
        var badType = validLayout()
        badType["unlistedWindows"] = true
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": badType]])
        }
    }

    @Test("廃止された closeUnlistedWindows は移行先を示すエラー")
    func removedCloseUnlistedWindowsThrows() {
        for value in [true, false] {
            var layout = validLayout()
            layout["closeUnlistedWindows"] = value
            #expect {
                try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
            } throws: { error in
                "\(error)".contains("unlistedWindows")
            }
        }
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

    @Test("hotkey もピッカーも無い到達不能なレイアウトはエラー")
    func unreachableLayoutThrows() {
        var layout = validLayout()
        layout["hotkey"] = nil
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("ピッカーの hotkey があればレイアウト個別の hotkey は省略できる")
    func pickerHotkeyAllowsHotkeyOmission() throws {
        var layout = validLayout()
        layout["hotkey"] = nil
        let config = try WindowLayoutsConfigBuilder.build([
            "hotkey": ["modifiers": ["ctrl", "alt"], "key": "l"],
            "layouts": ["a": layout],
        ])
        #expect(config.pickerHotkey == .init(modifiers: ["ctrl", "alt"], key: "l"))
        #expect(config.layouts[0].hotkey == nil)
    }

    @Test("Window Hintsからの導線があればレイアウト個別の hotkey は省略できる")
    func windowHintsKeyAllowsHotkeyOmission() throws {
        var layout = validLayout()
        layout["hotkey"] = nil
        let config = try WindowLayoutsConfigBuilder.build(
            ["layouts": ["a": layout]], windowHintsKey: "l")
        #expect(config.windowHintsKey == "L")
        #expect(config.pickerHotkey == nil)
        #expect(config.layouts[0].hotkey == nil)
    }

    @Test("description をパースし、空文字はエラー")
    func descriptionValidation() throws {
        var layout = validLayout()
        layout["description"] = "開発用の配置"
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        #expect(config.layouts[0].description == "開発用の配置")

        layout["description"] = ""
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": layout]])
        }
    }

    @Test("ピッカーとレイアウトのホットキー重複はエラー")
    func pickerHotkeyConflictThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "hotkey": ["modifiers": ["ctrl", "alt"], "key": "1"],
                "layouts": ["a": validLayout(key: "1")],
            ])
        }
    }

    @Test("appearance のデフォルト値と上書き")
    func appearanceDefaultsAndOverride() throws {
        let defaults = try WindowLayoutsConfigBuilder.build(["layouts": ["a": validLayout()]])
        #expect(defaults.pickerWidth == 480)
        #expect(defaults.rowHeight == 32)
        #expect(defaults.maxVisibleRows == 8)
        #expect(defaults.cornerRadius == 12)

        let overridden = try WindowLayoutsConfigBuilder.build([
            "layouts": ["a": validLayout()],
            "appearance": ["pickerWidth": 600, "maxVisibleRows": 5],
        ])
        #expect(overridden.pickerWidth == 600)
        #expect(overridden.maxVisibleRows == 5)
    }

    @Test("appearance.pickerWidth が0以下ならエラー")
    func nonPositivePickerWidthThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": ["a": validLayout()],
                "appearance": ["pickerWidth": 0],
            ])
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

    @Test("windows と unlistedWindows が両方ないレイアウトはエラー")
    func layoutWithoutWindowsAndUnlistedWindowsThrows() {
        // windows が空配列
        var emptyWindows = validLayout()
        emptyWindows["windows"] = [[String: Any]]()
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": emptyWindows]])
        }
        // windows 省略
        var noWindows = validLayout()
        noWindows["windows"] = nil
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": noWindows]])
        }
    }

    @Test("unlistedWindows があれば windows は省略できる")
    func windowsOptionalWithUnlistedWindows() throws {
        // windows 省略 + unlistedWindows: "close"
        var closeLayout = validLayout()
        closeLayout["windows"] = nil
        closeLayout["unlistedWindows"] = "close"
        let config = try WindowLayoutsConfigBuilder.build(["layouts": ["a": closeLayout]])
        #expect(config.layouts[0].windows.isEmpty)
        #expect(config.layouts[0].unlistedWindows == .close)

        // windows 空配列 + unlistedWindows: { area }
        var placeLayout = validLayout()
        placeLayout["windows"] = [[String: Any]]()
        placeLayout["unlistedWindows"] = ["area": "full"]
        let config2 = try WindowLayoutsConfigBuilder.build(["layouts": ["a": placeLayout]])
        #expect(config2.layouts[0].windows.isEmpty)
        #expect(config2.layouts[0].unlistedWindows == .place(screenUUID: nil, area: "full"))
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

    @Test("focus=true は1レイアウトに1件だけ指定できる")
    func duplicateFocusThrows() {
        var layout = validLayout()
        layout["windows"] = [
            ["bundleID": "a.b", "area": "halfLeft", "focus": true],
            ["bundleID": "c.d", "area": "halfRight", "focus": true],
        ]
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

    @Test("RootConfig 経由で window_hints の Window Layouts 遷移キーが渡る")
    func rootConfigWiresWindowHintsKey() throws {
        let text = """
            {
                "windowHints": { "navigation": { "windowLayouts": { "key": "l" } } },
                "windowLayouts": {
                    "layouts": {
                        "dev": {
                            "windows": [{ "bundleID": "a.b", "area": "halfLeft" }]
                        }
                    }
                }
            }
            """
        let config = try RootConfigBuilder.build(text: text)
        #expect(config.windowLayouts?.windowHintsKey == "L")
        #expect(config.windowLayouts?.layouts[0].hotkey == nil)
    }
}
