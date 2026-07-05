import Testing

@testable import JinraiCore

@Suite("ApplicationHintsConfigBuilder")
struct ApplicationHintsConfigTests {
    @Test("apps が空ならエラー")
    func emptyAppsThrows() {
        #expect(throws: ConfigError.self) {
            try ApplicationHintsConfigBuilder.build(["apps": [[String: Any]]()])
        }
        #expect(throws: ConfigError.self) {
            try ApplicationHintsConfigBuilder.build([:])
        }
    }

    @Test("基本的なアプリ登録とデフォルト値")
    func basicAppsAndDefaults() throws {
        let config = try ApplicationHintsConfigBuilder.build([
            "apps": [
                ["bundleID": "com.google.Chrome", "key": "E"],
                ["bundleID": "com.tinyspeck.slackmacgap", "key": "S"],
            ]
        ])
        #expect(config.apps.count == 2)
        #expect(config.apps[0].key == "E")
        // newWindow 未指定はデフォルト cmd+n
        #expect(config.apps[0].newWindowModifiers == ["cmd"])
        #expect(config.apps[0].newWindowKey == "n")
        #expect(config.columns == 3)
        #expect(config.itemWidth == 220)
        #expect(config.windowWaitTimeout == 10)
    }

    @Test("キーは大文字化される")
    func keyUppercased() throws {
        let config = try ApplicationHintsConfigBuilder.build([
            "apps": [["bundleID": "a.b", "key": "g"]]
        ])
        #expect(config.apps[0].key == "G")
    }

    @Test("キーは1〜2文字")
    func keyLength() {
        #expect(throws: ConfigError.self) {
            try ApplicationHintsConfigBuilder.build([
                "apps": [["bundleID": "a.b", "key": "ABC"]]
            ])
        }
    }

    @Test("bundleID は必須")
    func bundleIDRequired() {
        #expect(throws: ConfigError.self) {
            try ApplicationHintsConfigBuilder.build([
                "apps": [["key": "G"]]
            ])
        }
    }

    @Test("apps 間のキー衝突(重複・接頭辞包含)はエラー")
    func appKeyConflict() {
        #expect(throws: ConfigError.self) {
            try ApplicationHintsConfigBuilder.build([
                "apps": [
                    ["bundleID": "a.b", "key": "G"],
                    ["bundleID": "c.d", "key": "GG"],  // G の接頭辞包含
                ]
            ])
        }
    }

    @Test("windowHintsKey とのキー衝突はエラー")
    func windowHintsKeyConflict() {
        #expect(throws: ConfigError.self) {
            try ApplicationHintsConfigBuilder.build(
                ["apps": [["bundleID": "a.b", "key": "N"]]],
                windowHintsKey: "n")
        }
    }

    @Test("newWindow.hotkey で送出キーを上書きできる")
    func newWindowHotkey() throws {
        let config = try ApplicationHintsConfigBuilder.build([
            "apps": [
                [
                    "bundleID": "com.mitchellh.ghostty", "key": "G",
                    "newWindow": ["hotkey": ["modifiers": ["ctrl"], "key": "n"]],
                ]
            ]
        ])
        #expect(config.apps[0].newWindowModifiers == ["ctrl"])
        #expect(config.apps[0].newWindowKey == "n")
    }

    @Test("newWindow.url を宣言的に指定できる")
    func newWindowURL() throws {
        let config = try ApplicationHintsConfigBuilder.build([
            "apps": [
                [
                    "bundleID": "md.obsidian", "key": "O", "name": "Various Complements",
                    "newWindow": ["url": "obsidian://open?path=/foo"],
                ]
            ]
        ])
        #expect(config.apps[0].newWindowURL == "obsidian://open?path=/foo")
        #expect(config.apps[0].name == "Various Complements")
    }

    @Test("appearance.columns を上書きできる")
    func columnsOverride() throws {
        let config = try ApplicationHintsConfigBuilder.build([
            "apps": [["bundleID": "a.b", "key": "G"]],
            "appearance": ["columns": 4],
        ])
        #expect(config.columns == 4)
    }

    @Test("RootConfig 経由で window_hints の遷移キーが渡り衝突検証される")
    func rootConfigWiresWindowHintsKey() {
        let text = """
            {
                "windowHints": { "navigation": { "applicationHints": { "key": "n" } } },
                "applicationHints": { "apps": [{ "bundleID": "a.b", "key": "N" }] }
            }
            """
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: text)
        }
    }
}
