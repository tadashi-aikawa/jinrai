import Testing

@testable import JinraiCore

@Suite("WindowLayoutsConfigBuilder")
struct WindowLayoutsConfigTests {
    /// 正常系のレイアウト1件分
    private func validLayout(name: String = "a", key: String = "1") -> [String: Any] {
        [
            "name": name,
            "hotkey": ["modifiers": ["ctrl", "alt"], "key": key],
            "windows": [["bundleID": "com.google.Chrome", "area": "halfLeft"]],
        ]
    }

    @Test("フルパース(titleGlob / screen / launch / windowWaitTimeout)")
    func fullParse() throws {
        let config = try WindowLayoutsConfigBuilder.build([
            "windowWaitTimeout": 5,
            "layouts": [
                [
                    "name": "dev",
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
                    area: "halfLeft", launch: .none, focus: true))
        #expect(layout.windows[1].launch == .app)
        #expect(layout.windows[1].focus == false)
        #expect(layout.windows[1].titleGlob == nil)
        #expect(layout.windows[1].screenUUID == nil)
    }

    @Test("launch: { newWindow: { url } } をパースできる")
    func launchNewWindowURLParse() throws {
        var layout = validLayout()
        layout["windows"] = [
            [
                "bundleID": "md.obsidian", "titleGlob": "*MyVault*", "area": "halfRight",
                "launch": ["newWindow": ["url": "obsidian://open?path=/path/to/MyVault"]],
            ]
        ]
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(
            config.layouts[0].windows[0].launch
                == .newWindowURL("obsidian://open?path=/path/to/MyVault"))
    }

    @Test("launch: false / 省略は .none")
    func launchDefaultsToNone() throws {
        var layout = validLayout()
        layout["windows"] = [
            ["bundleID": "a", "area": "full"],
            ["bundleID": "b", "area": "full", "launch": false],
        ]
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(config.layouts[0].windows[0].launch == .none)
        #expect(config.layouts[0].windows[1].launch == .none)
    }

    @Test("launch の不正値はエラー")
    func invalidLaunchThrows() {
        // newWindow 欠落
        var noNewWindow = validLayout()
        noNewWindow["windows"] = [["bundleID": "a", "area": "full", "launch": [String: Any]()]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noNewWindow]])
        }
        // url 欠落
        var noURL = validLayout()
        noURL["windows"] = [
            ["bundleID": "a", "area": "full", "launch": ["newWindow": [String: Any]()]]
        ]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noURL]])
        }
        // url が空
        var emptyURL = validLayout()
        emptyURL["windows"] = [
            ["bundleID": "a", "area": "full", "launch": ["newWindow": ["url": ""]]]
        ]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [emptyURL]])
        }
        // URL として解釈できない
        var brokenURL = validLayout()
        brokenURL["windows"] = [
            ["bundleID": "a", "area": "full", "launch": ["newWindow": ["url": "ob sidian://x y"]]]
        ]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [brokenURL]])
        }
        // 不正な型
        var badType = validLayout()
        badType["windows"] = [["bundleID": "a", "area": "full", "launch": "yes"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [badType]])
        }
    }

    @Test("windowWaitTimeout のデフォルトは10秒")
    func windowWaitTimeoutDefault() throws {
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [validLayout()]])
        #expect(config.windowWaitTimeout == 10)
    }

    @Test("unlistedWindows 未指定は nil(何もしない)")
    func unlistedWindowsDefaultsToNil() throws {
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [validLayout()]])
        #expect(config.layouts[0].unlistedWindows == nil)
    }

    @Test("unlistedWindows: \"close\" をパースできる")
    func unlistedWindowsCloseParse() throws {
        var layout = validLayout()
        layout["unlistedWindows"] = "close"
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(config.layouts[0].unlistedWindows == .close)
    }

    @Test("unlistedWindows: { screen?, area } をパースできる")
    func unlistedWindowsPlaceParse() throws {
        var layout = validLayout()
        layout["unlistedWindows"] = [
            "screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230", "area": "full",
        ]
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(
            config.layouts[0].unlistedWindows
                == .place(screenUUID: "37D8832A-2D66-02CA-B9F7-8F30A301B230", area: "full"))

        var noScreen = validLayout()
        noScreen["unlistedWindows"] = ["area": "full"]
        let config2 = try WindowLayoutsConfigBuilder.build(["layouts": [noScreen]])
        #expect(config2.layouts[0].unlistedWindows == .place(screenUUID: nil, area: "full"))
    }

    @Test("unlistedWindows の不正値はエラー")
    func invalidUnlistedWindowsThrows() {
        // "close" 以外の文字列
        var badString = validLayout()
        badString["unlistedWindows"] = "closeall"
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [badString]])
        }
        // area 欠落
        var noArea = validLayout()
        noArea["unlistedWindows"] = ["screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noArea]])
        }
        // 未知エリア
        var unknownArea = validLayout()
        unknownArea["unlistedWindows"] = ["area": "unknownArea"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [unknownArea]])
        }
        // freeArea 禁止
        var freeArea = validLayout()
        freeArea["unlistedWindows"] = ["area": "freeArea"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [freeArea]])
        }
        // 不正な型
        var badType = validLayout()
        badType["unlistedWindows"] = true
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [badType]])
        }
    }

    @Test("closeWindows をパースできる(bundleID のみ / titleGlob 付き)")
    func closeWindowsParse() throws {
        var layout = validLayout()
        layout["closeWindows"] = [
            ["bundleID": "com.tinyspeck.slackmacgap"],
            ["bundleID": "md.obsidian", "titleGlob": "*Scratch*"],
        ]
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(
            config.layouts[0].closeWindows == [
                .init(bundleID: "com.tinyspeck.slackmacgap", titleGlob: nil),
                .init(bundleID: "md.obsidian", titleGlob: "*Scratch*"),
            ])
    }

    @Test("closeWindows 未指定は空配列")
    func closeWindowsDefaultsToEmpty() throws {
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [validLayout()]])
        #expect(config.layouts[0].closeWindows.isEmpty)
    }

    @Test("closeWindows の bundleID は必須で、titleGlob の空文字はエラー")
    func closeWindowsValidation() {
        // bundleID 欠落
        var noBundleID = validLayout()
        noBundleID["closeWindows"] = [["titleGlob": "*"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noBundleID]])
        }
        // bundleID 空文字
        var emptyBundleID = validLayout()
        emptyBundleID["closeWindows"] = [["bundleID": ""]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [emptyBundleID]])
        }
        // titleGlob 空文字
        var emptyGlob = validLayout()
        emptyGlob["closeWindows"] = [["bundleID": "a.b", "titleGlob": ""]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [emptyGlob]])
        }
    }

    @Test("closeWindows と windows の同一 bundleID が両方 titleGlob なしならエラー")
    func closeWindowsConflictWithWindowsThrows() throws {
        // 両方 titleGlob なし → 矛盾エラー
        var conflict = validLayout()
        conflict["closeWindows"] = [["bundleID": "com.google.Chrome"]]
        #expect {
            try WindowLayoutsConfigBuilder.build(["layouts": [conflict]])
        } throws: { error in
            "\(error)".contains("titleGlob")
        }

        // 片方に titleGlob があれば OK
        var globOnClose = validLayout()
        globOnClose["closeWindows"] = [["bundleID": "com.google.Chrome", "titleGlob": "*Meet*"]]
        _ = try WindowLayoutsConfigBuilder.build(["layouts": [globOnClose]])

        // 別 bundleID なら OK
        var different = validLayout()
        different["closeWindows"] = [["bundleID": "com.tinyspeck.slackmacgap"]]
        _ = try WindowLayoutsConfigBuilder.build(["layouts": [different]])
    }

    @Test("closeWindows があれば windows は省略できる")
    func windowsOptionalWithCloseWindows() throws {
        var layout = validLayout()
        layout["windows"] = nil
        layout["closeWindows"] = [["bundleID": "com.tinyspeck.slackmacgap"]]
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(config.layouts[0].windows.isEmpty)
        #expect(config.layouts[0].closeWindows.count == 1)

        // closeWindows が空配列なら「何もしないレイアウト」としてエラー
        var emptyClose = validLayout()
        emptyClose["windows"] = nil
        emptyClose["closeWindows"] = [[String: Any]]()
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [emptyClose]])
        }
    }

    @Test("廃止された closeUnlistedWindows は移行先を示すエラー")
    func removedCloseUnlistedWindowsThrows() {
        for value in [true, false] {
            var layout = validLayout()
            layout["closeUnlistedWindows"] = value
            #expect {
                try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
            } throws: { error in
                "\(error)".contains("unlistedWindows")
            }
        }
    }

    @Test("layouts は設定記載順を保持する")
    func layoutsPreserveDefinitionOrder() throws {
        let config = try WindowLayoutsConfigBuilder.build([
            "layouts": [
                validLayout(name: "zebra", key: "1"),
                validLayout(name: "alpha", key: "2"),
                validLayout(name: "meeting", key: "3"),
            ]
        ])
        #expect(config.layouts.map(\.name) == ["zebra", "alpha", "meeting"])
    }

    @Test("layouts が空・未指定・配列以外ならエラー")
    func emptyLayoutsThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [[String: Any]]()])
        }
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([:])
        }
        // 旧形式(レイアウト名をキーにしたオブジェクト)はエラー
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": ["a": validLayout()]])
        }
    }

    @Test("name が欠落・空ならエラー")
    func missingNameThrows() {
        var noName = validLayout()
        noName["name"] = nil
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noName]])
        }
        var emptyName = validLayout()
        emptyName["name"] = ""
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [emptyName]])
        }
    }

    @Test("name の重複はエラー")
    func duplicateNameThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": [validLayout(name: "a", key: "1"), validLayout(name: "a", key: "2")]
            ])
        }
    }

    @Test("hotkey もピッカーも無い到達不能なレイアウトはエラー")
    func unreachableLayoutThrows() {
        var layout = validLayout()
        layout["hotkey"] = nil
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        }
    }

    @Test("ピッカーの hotkey があればレイアウト個別の hotkey は省略できる")
    func pickerHotkeyAllowsHotkeyOmission() throws {
        var layout = validLayout()
        layout["hotkey"] = nil
        let config = try WindowLayoutsConfigBuilder.build([
            "hotkey": ["modifiers": ["ctrl", "alt"], "key": "l"],
            "layouts": [layout],
        ])
        #expect(config.pickerHotkey == .init(modifiers: ["ctrl", "alt"], key: "l"))
        #expect(config.layouts[0].hotkey == nil)
    }

    @Test("Window Hintsからの導線があればレイアウト個別の hotkey は省略できる")
    func windowHintsKeyAllowsHotkeyOmission() throws {
        var layout = validLayout()
        layout["hotkey"] = nil
        let config = try WindowLayoutsConfigBuilder.build(
            ["layouts": [layout]], windowHintsKey: "l")
        #expect(config.windowHintsKey == "L")
        #expect(config.pickerHotkey == nil)
        #expect(config.layouts[0].hotkey == nil)
    }

    @Test("description をパースし、空文字はエラー")
    func descriptionValidation() throws {
        var layout = validLayout()
        layout["description"] = "開発用の配置"
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        #expect(config.layouts[0].description == "開発用の配置")

        layout["description"] = ""
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        }
    }

    @Test("ピッカーとレイアウトのホットキー重複はエラー")
    func pickerHotkeyConflictThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "hotkey": ["modifiers": ["ctrl", "alt"], "key": "1"],
                "layouts": [validLayout(key: "1")],
            ])
        }
    }

    @Test("appearance のデフォルト値と上書き")
    func appearanceDefaultsAndOverride() throws {
        let defaults = try WindowLayoutsConfigBuilder.build(["layouts": [validLayout()]])
        #expect(defaults.pickerWidth == 480)
        #expect(defaults.rowHeight == 32)
        #expect(defaults.maxVisibleRows == 8)
        #expect(defaults.cornerRadius == 12)

        let overridden = try WindowLayoutsConfigBuilder.build([
            "layouts": [validLayout()],
            "appearance": ["pickerWidth": 600, "maxVisibleRows": 5],
        ])
        #expect(overridden.pickerWidth == 600)
        #expect(overridden.maxVisibleRows == 5)
    }

    @Test("appearance.pickerWidth が0以下ならエラー")
    func nonPositivePickerWidthThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": [validLayout()],
                "appearance": ["pickerWidth": 0],
            ])
        }
    }

    @Test("レイアウト間のホットキー重複はエラー(modifiers の順序・大小文字は無視)")
    func duplicateHotkeyThrows() {
        var other = validLayout(name: "b")
        other["hotkey"] = ["modifiers": ["alt", "Ctrl"], "key": "1"]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": [validLayout(name: "a"), other]
            ])
        }
    }

    @Test("windows / closeWindows / unlistedWindows が全部ないレイアウトはエラー")
    func layoutWithoutWindowsAndUnlistedWindowsThrows() {
        // windows が空配列
        var emptyWindows = validLayout()
        emptyWindows["windows"] = [[String: Any]]()
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [emptyWindows]])
        }
        // windows 省略
        var noWindows = validLayout()
        noWindows["windows"] = nil
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noWindows]])
        }
    }

    @Test("unlistedWindows があれば windows は省略できる")
    func windowsOptionalWithUnlistedWindows() throws {
        // windows 省略 + unlistedWindows: "close"
        var closeLayout = validLayout()
        closeLayout["windows"] = nil
        closeLayout["unlistedWindows"] = "close"
        let config = try WindowLayoutsConfigBuilder.build(["layouts": [closeLayout]])
        #expect(config.layouts[0].windows.isEmpty)
        #expect(config.layouts[0].unlistedWindows == .close)

        // windows 空配列 + unlistedWindows: { area }
        var placeLayout = validLayout()
        placeLayout["windows"] = [[String: Any]]()
        placeLayout["unlistedWindows"] = ["area": "full"]
        let config2 = try WindowLayoutsConfigBuilder.build(["layouts": [placeLayout]])
        #expect(config2.layouts[0].windows.isEmpty)
        #expect(config2.layouts[0].unlistedWindows == .place(screenUUID: nil, area: "full"))
    }

    @Test("bundleID は必須")
    func bundleIDRequired() {
        var layout = validLayout()
        layout["windows"] = [["area": "halfLeft"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        }
    }

    @Test("area は必須かつ既知のエリア名")
    func areaValidation() {
        var noArea = validLayout()
        noArea["windows"] = [["bundleID": "a.b"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [noArea]])
        }
        var unknownArea = validLayout()
        unknownArea["windows"] = [["bundleID": "a.b", "area": "unknownArea"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [unknownArea]])
        }
    }

    @Test("area に freeArea は使えない")
    func freeAreaThrows() {
        var layout = validLayout()
        layout["windows"] = [["bundleID": "a.b", "area": "freeArea"]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        }
    }

    @Test("titleGlob の空文字はエラー")
    func emptyTitleGlobThrows() {
        var layout = validLayout()
        layout["windows"] = [["bundleID": "a.b", "area": "halfLeft", "titleGlob": ""]]
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
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
            try WindowLayoutsConfigBuilder.build(["layouts": [layout]])
        }
    }

    @Test("windowWaitTimeout が0以下ならエラー")
    func nonPositiveTimeoutThrows() {
        #expect(throws: ConfigError.self) {
            try WindowLayoutsConfigBuilder.build([
                "layouts": [validLayout()], "windowWaitTimeout": 0,
            ])
        }
    }

    @Test("RootConfig 経由でセクションが有効になる")
    func rootConfigSection() throws {
        let text = """
            {
                "windowLayouts": {
                    "layouts": [
                        {
                            "name": "dev",
                            "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
                            "windows": [{ "bundleID": "a.b", "area": "halfLeft" }]
                        }
                    ]
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
                    "layouts": [
                        {
                            "name": "dev",
                            "windows": [{ "bundleID": "a.b", "area": "halfLeft" }]
                        }
                    ]
                }
            }
            """
        let config = try RootConfigBuilder.build(text: text)
        #expect(config.windowLayouts?.windowHintsKey == "L")
        #expect(config.windowLayouts?.layouts[0].hotkey == nil)
    }
}
