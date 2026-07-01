import Foundation
import Testing

@testable import JinraiCore

@Suite("JSONC")
struct JSONCTests {
    @Test("行コメントと末尾カンマを除去できる")
    func stripCommentsAndTrailingCommas() throws {
        let text = """
            {
                // フォーカスバック設定
                "focus_back": {
                    "hotkey": { "modifiers": ["alt"], "key": "w", },
                },
                /* ブロックコメント */
                "focus_border": {},
            }
            """
        let dict = try JSONC.parseObject(text)
        #expect(dict["focus_back"] != nil)
        #expect(dict["focus_border"] != nil)
    }

    @Test("文字列内の // やカンマは保護される")
    func preservesStringContents() throws {
        let text = #"{ "url": "https://example.com", "note": "a, b // c" }"#
        let dict = try JSONC.parseObject(text)
        #expect(dict["url"] as? String == "https://example.com")
        #expect(dict["note"] as? String == "a, b // c")
    }

    @Test("トップレベルが配列ならエラー")
    func rejectsNonObject() {
        #expect(throws: ConfigError.self) {
            try JSONC.parseObject("[1, 2]")
        }
    }
}

@Suite("DeepMerge")
struct DeepMergeTests {
    @Test("ネストした辞書はキー単位でマージされる")
    func mergesNestedDicts() {
        let defaults: [String: Any] = [
            "a": ["x": 1, "y": 2],
            "b": true,
        ]
        let overrides: [String: Any] = ["a": ["y": 20]]
        let merged = DeepMerge.merge(defaults: defaults, overrides: overrides)
        let a = merged["a"] as? [String: Any]
        #expect((a?["x"] as? NSNumber)?.intValue == 1)
        #expect((a?["y"] as? NSNumber)?.intValue == 20)
        #expect(merged["b"] as? Bool == true)
    }

    @Test("配列はマージせず置換する")
    func replacesArrays() {
        let defaults: [String: Any] = ["chars": ["A", "S", "D"]]
        let overrides: [String: Any] = ["chars": ["Q"]]
        let merged = DeepMerge.merge(defaults: defaults, overrides: overrides)
        #expect(merged["chars"] as? [String] == ["Q"])
    }
}

@Suite("FocusBackConfigBuilder")
struct FocusBackConfigTests {
    @Test("デフォルト値: option+w, カーソル追従あり")
    func defaults() throws {
        let config = try FocusBackConfigBuilder.build()
        #expect(config.hotkeyModifiers == ["option"])
        #expect(config.hotkeyKey == "w")
        #expect(config.urlEventName == nil)
        #expect(config.centerCursor)
    }

    @Test("上書きできる")
    func overrides() throws {
        let config = try FocusBackConfigBuilder.build([
            "hotkey": ["modifiers": ["cmd", "shift"], "key": "b"],
            "behavior": ["cursor": ["onSelect": false]],
            "urlEvent": ["name": "focus-back"],
        ])
        #expect(config.hotkeyModifiers == ["cmd", "shift"])
        #expect(config.hotkeyKey == "b")
        #expect(config.urlEventName == "focus-back")
        #expect(!config.centerCursor)
    }

    @Test("レガシーフラットキーはエラー")
    func rejectsLegacyFlatKeys() {
        #expect(throws: ConfigError.self) {
            try FocusBackConfigBuilder.build(["hotkeyKey": "w"])
        }
    }

    @Test("レガシーネストキー behavior.centerCursor はエラー")
    func rejectsLegacyNestedKey() {
        #expect(throws: ConfigError.self) {
            try FocusBackConfigBuilder.build(["behavior": ["centerCursor": true]])
        }
    }
}

@Suite("FocusBorderConfigBuilder")
struct FocusBorderConfigTests {
    @Test("デフォルト値")
    func defaults() throws {
        let config = try FocusBorderConfigBuilder.build()
        #expect(config.borderWidth == 10)
        #expect(config.borderColor == ConfigColor(red: 0.40, green: 0.68, blue: 0.98, alpha: 0.95))
        #expect(config.outlineWidth == 2)
        #expect(config.duration == 0.5)
        #expect(config.fadeSteps == 18)
        #expect(config.spaceSwitchDelay == 0.30)
        #expect(config.minWindowSize == 480)
        #expect(config.logo == nil)
    }

    @Test("logo を指定するとデフォルト値で補完される")
    func logoDefaults() throws {
        let config = try FocusBorderConfigBuilder.build(["visual": ["logo": [:]]])
        #expect(config.logo?.size == 480)
        #expect(config.logo?.alpha == 0.95)
        #expect(config.logo?.source == nil)
    }

    @Test("レガシーフラットキーはエラー")
    func rejectsLegacyFlatKeys() {
        #expect(throws: ConfigError.self) {
            try FocusBorderConfigBuilder.build(["borderWidth": 4])
        }
    }
}

@Suite("RootConfigBuilder")
struct RootConfigTests {
    @Test("セクションが存在する機能だけ有効になる")
    func sectionPresenceEnablesFeatures() throws {
        let config = try RootConfigBuilder.build(text: #"{ "focus_back": {} }"#)
        #expect(config.focusBack != nil)
        #expect(config.focusBorder == nil)
        #expect(config.windowHintsRaw == nil)
    }

    @Test("macos_native_tabs はデフォルトにユーザー指定を追記する")
    func macosNativeTabsMerge() throws {
        let config = try RootConfigBuilder.build(text: """
            { "macos_native_tabs": { "apps": ["com.example.app"], "stateSyncInterval": 1.0 } }
            """)
        #expect(
            config.macosNativeTabs.apps == [
                "com.mitchellh.ghostty", "com.apple.finder", "com.example.app",
            ])
        #expect(config.macosNativeTabs.stateSyncInterval == 1.0)
    }

    @Test("セクションなしでもデフォルトの macos_native_tabs を持つ")
    func defaultsWithoutSection() throws {
        let config = try RootConfigBuilder.build(text: "{}")
        #expect(config.macosNativeTabs == .default)
    }
}
