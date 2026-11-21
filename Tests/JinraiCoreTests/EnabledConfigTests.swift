import Foundation
import Testing

@testable import JinraiCore

@Suite("enabled")
struct EnabledConfigTests {
    @Test("enabled: false のセクションは無いものとして扱う")
    func disabledSectionIsNil() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "focusBack": { "enabled": false, "hotkey": { "modifiers": ["alt"], "key": "w" } },
                "focusBorder": { "enabled": true },
                "displayMirroring": { "enabled": false },
            }
            """)
        #expect(config.focusBack == nil)
        #expect(config.focusBorder != nil)
        #expect(config.displayMirroring == nil)
    }

    @Test("enabled: false でも中身は検査する")
    func disabledSectionIsStillValidated() {
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                { "windowMover": { "enabled": false, "commands": { "noSuchCommand": {} } } }
                """)
        }
    }

    @Test("enabled が真偽値でなければエラー")
    func rejectsNonBoolean() {
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: #"{ "focusBorder": { "enabled": 0 } }"#)
        }
    }

    @Test("無効な Application Hints / Window Layouts は必須のリストが空でもよい")
    func disabledAllowsEmptyRequiredLists() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "applicationHints": { "enabled": false },
                "windowLayouts": { "enabled": false, "layouts": [] },
            }
            """)
        #expect(config.applicationHints == nil)
        #expect(config.windowLayouts == nil)
    }

    @Test("有効な Application Hints は apps が空ならエラー")
    func enabledRequiresApps() {
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: #"{ "applicationHints": { "apps": [] } }"#)
        }
    }

    @Test("無効な Window Layouts は呼び出せないレイアウトを咎めない")
    func disabledLayoutsSkipReachability() throws {
        let config = try RootConfigBuilder.build(text: """
            { "windowLayouts": { "enabled": false, "layouts": [{ "name": "A", "unlistedWindows": { "area": "full" } }] } }
            """)
        #expect(config.windowLayouts == nil)
    }

    @Test("Window Hints を切ると、Window Hints からしか呼べないレイアウトはエラー")
    func disablingWindowHintsMakesLayoutsUnreachable() throws {
        let base = """
            {
                "windowHints": { %@ "navigation": { "windowLayouts": { "key": "p" } } },
                "windowLayouts": { "layouts": [{ "name": "A", "unlistedWindows": { "area": "full" } }] },
            }
            """
        _ = try RootConfigBuilder.build(text: base.replacingOccurrences(of: "%@", with: ""))
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(
                text: base.replacingOccurrences(of: "%@", with: #""enabled": false,"#))
        }
    }

    @Test("遷移先が無い遷移キーは閉じる")
    func navigationKeysToMissingTargetsAreClosed() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": {
                    "navigation": {
                        "areaHints": { "key": "space" },
                        "applicationHints": { "key": "n" },
                        "windowLayouts": { "key": "p" },
                    },
                },
                "applicationHints": { "enabled": false, "apps": [{ "bundleID": "com.apple.Safari", "key": "S" }] },
            }
            """)
        #expect(config.windowHints?.applicationHintsKey == nil)
        #expect(config.windowHints?.windowLayoutsKey == nil)
        // Window Mover も Area Hints も無いので Area Hints へは遷移できない
        #expect(config.windowHints?.areaHintsKey == nil)
    }

    @Test("Area Hints のセクションが無くても Window Mover があれば遷移できる(従来どおり)")
    func areaHintsReachableThroughWindowMover() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": { "navigation": { "areaHints": { "key": "space" } } },
                "windowMover": {},
            }
            """)
        #expect(config.windowHints?.areaHintsKey == "space")
    }

    @Test("Area Hints を明示的に切ると、Window Mover があっても遷移キーは閉じる")
    func explicitlyDisabledAreaHintsClosesNavigation() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": { "navigation": { "areaHints": { "key": "space" } } },
                "windowMover": {},
                "areaHints": { "enabled": false },
            }
            """)
        #expect(config.areaHints == nil)
        #expect(config.windowHints?.areaHintsKey == nil)
    }

    @Test("無効でも apps / layouts の型が違えばエラー")
    func disabledStillRejectsWrongListType() {
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: #"{ "applicationHints": { "enabled": false, "apps": {} } }"#)
        }
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(
                text: #"{ "windowLayouts": { "enabled": false, "layouts": ["invalid"] } }"#)
        }
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: #"{ "applicationHints": { "enabled": false, "apps": null } }"#)
        }
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: #"{ "windowLayouts": { "enabled": false, "layouts": null } }"#)
        }
    }

    @Test("Window Hints を切ると、Application Hints から Window Hints への戻りキーも閉じる")
    func disabledWindowHintsClosesReturnKey() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": { "enabled": false, "navigation": { "applicationHints": { "key": "n" } } },
                "applicationHints": { "apps": [{ "bundleID": "com.apple.Safari", "key": "S" }] },
            }
            """)
        #expect(config.applicationHints?.windowHintsKey == nil)
    }

    @Test("Area Hints を明示的に切ると、JINRAI Mode の入口も閉じる")
    func disabledAreaHintsClosesJinraiMode() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": {
                    "navigation": {
                        "applicationHints": { "key": "n", "jinraiMode": true },
                        "windowLayouts": { "key": "p", "jinraiMode": true },
                    },
                },
                "windowMover": {},
                "areaHints": { "enabled": false },
                "applicationHints": { "apps": [{ "bundleID": "com.apple.Safari", "key": "S" }] },
                "windowLayouts": { "layouts": [{ "name": "A", "unlistedWindows": { "area": "full" } }] },
                "jinraiMode": { "triggers": { "windowHints": { "key": "return" }, "applicationHints": { "key": "return" } } },
            }
            """)
        #expect(config.windowHints?.jinraiModeKey == nil)
        #expect(config.windowHints?.applicationHintsJinraiMode == false)
        #expect(config.windowHints?.windowLayoutsJinraiMode == false)
        #expect(config.applicationHints?.jinraiModeKey == nil)
        // 遷移そのものは残る
        #expect(config.windowHints?.applicationHintsKey == "n")
    }

    @Test("Area Hints のセクションが無いだけなら JINRAI Mode は従来どおり")
    func absentAreaHintsKeepsJinraiMode() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": {},
                "windowMover": {},
                "jinraiMode": { "triggers": { "windowHints": { "key": "return" } } },
            }
            """)
        #expect(config.windowHints?.jinraiModeKey == "return")
    }

    @Test("無効な Area Hints でも JINRAI Mode のトリガとの衝突は検査する")
    func disabledAreaHintsStillValidatesTrigger() {
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                {
                    "areaHints": { "enabled": false, "defaultScreen": { "halfLeft": "J" } },
                    "jinraiMode": { "triggers": { "areaHints": { "key": "j" } } },
                }
                """)
        }
    }

    @Test("Focus Back が無効なら、Window Hints の Focus Back のキーを閉じる")
    func disabledFocusBackFreesNavigationKey() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "focusBack": { "enabled": false },
                "windowHints": { "navigation": { "focusBack": { "key": "w" } } },
            }
            """)
        #expect(config.windowHints?.navigationFocusBackKey == nil)
    }

    @Test("Window Hints を切っても、書かれた遷移キーとアプリのキーの衝突は検査する")
    func disabledWindowHintsStillChecksConflicts() {
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                {
                    "windowHints": { "enabled": false, "navigation": { "applicationHints": { "key": "S" } } },
                    "applicationHints": { "apps": [{ "bundleID": "com.apple.Safari", "key": "S" }] },
                }
                """)
        }
    }

    @Test("プロファイルで enabled: true だけを書いて、基本の apps のまま有効にできる")
    func profileReenablesWithBaseList() throws {
        let uuid = "BE98B626-FF4E-47A3-9D0E-A741818FD269"
        let text = """
            {
                "applicationHints": { "enabled": false, "apps": [{ "bundleID": "com.apple.Safari", "key": "S" }] },
                "profiles": [{ "displays": ["\(uuid)"], "overrides": { "applicationHints": { "enabled": true } } }],
            }
            """
        #expect(try RootConfigBuilder.build(text: text).applicationHints == nil)
        #expect(
            try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuid]).applicationHints?
                .apps.count == 1)
    }

    @Test("プロファイルで enabled を切り替えられる")
    func profilesCanToggleEnabled() throws {
        let uuid = "BE98B626-FF4E-47A3-9D0E-A741818FD269"
        let text = """
            {
                "focusBorder": {},
                "profiles": [{ "displays": ["\(uuid)"], "overrides": { "focusBorder": { "enabled": false } } }],
            }
            """
        #expect(try RootConfigBuilder.build(text: text).focusBorder != nil)
        #expect(
            try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuid]).focusBorder
                == nil)
    }
}
