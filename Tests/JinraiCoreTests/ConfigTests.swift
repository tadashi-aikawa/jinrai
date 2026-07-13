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
                "focusBack": {
                    "hotkey": { "modifiers": ["alt"], "key": "w", },
                },
                /* ブロックコメント */
                "focusBorder": {},
            }
            """
        let dict = try JSONC.parseObject(text)
        #expect(dict["focusBack"] != nil)
        #expect(dict["focusBorder"] != nil)
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
    @Test("デフォルト値: ホットキーなし, カーソル追従あり")
    func defaults() throws {
        let config = try FocusBackConfigBuilder.build()
        #expect(config.hotkeyModifiers == [])
        #expect(config.hotkeyKey == nil)
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

}

@Suite("WindowHintsConfigBuilder")
struct WindowHintsConfigTests {
    @Test("hotkey 未指定なら nil(登録されない)")
    func hotkeyDefaultsToNil() throws {
        let config = try WindowHintsConfigBuilder.build()
        #expect(config.hotkeyModifiers == [])
        #expect(config.hotkeyKey == nil)
    }

    @Test("spotlight alpha はデフォルト値を持つ")
    func spotlightAlphaDefault() throws {
        let config = try WindowHintsConfigBuilder.build()
        #expect(config.focusedSpotlightAlpha == 0.5)
    }

    @Test("spotlight alpha を上書きできる")
    func spotlightAlphaOverride() throws {
        let config = try WindowHintsConfigBuilder.build([
            "focusedWindowSpotlight": ["alpha": 0.42]
        ])
        #expect(config.focusedSpotlightAlpha == 0.42)
    }

    @Test("preview.maxFillRatio はデフォルト値を持つ")
    func previewMaxFillRatioDefault() throws {
        let config = try WindowHintsConfigBuilder.build()
        #expect(config.previewMaxFillRatio == 0.5)
    }

    @Test("preview.maxFillRatio を上書きできる")
    func previewMaxFillRatioOverride() throws {
        let config = try WindowHintsConfigBuilder.build([
            "occlusion": ["preview": ["maxFillRatio": 0.3]]
        ])
        #expect(config.previewMaxFillRatio == 0.3)
    }

    @Test("navigation.windowLayouts.key をパースする")
    func parsesWindowLayoutsNavigationKey() throws {
        let config = try WindowHintsConfigBuilder.build([
            "navigation": ["windowLayouts": ["key": "l", "jinraiMode": true]]
        ])
        #expect(config.windowLayoutsKey == "l")
        #expect(config.windowLayoutsJinraiMode)
    }

    @Test("direction.direct はデフォルトで無効")
    func directDirectionDefault() throws {
        let config = try WindowHintsConfigBuilder.build()
        #expect(config.directDirectionHotkeys == nil)
    }

    @Test("direction.direct は modifiers と keys でパースされ、キーは小文字化される")
    func directDirectionParse() throws {
        let config = try WindowHintsConfigBuilder.build([
            "navigation": [
                "direction": [
                    "direct": [
                        "modifiers": ["ctrl", "alt"],
                        "keys": [
                            "left": "h", "down": "j", "up": "k", "right": "L",
                            "upLeft": "y",
                        ],
                    ]
                ]
            ]
        ])
        let direct = try #require(config.directDirectionHotkeys)
        #expect(direct.modifiers == ["ctrl", "alt"])
        #expect(direct.keys[.left] == "h")
        #expect(direct.keys[.right] == "l")
        #expect(direct.keys[.upLeft] == "y")
    }

    @Test("direction.direct の keys が空なら無効になる")
    func directDirectionEmptyKeys() throws {
        let config = try WindowHintsConfigBuilder.build([
            "navigation": [
                "direction": [
                    "direct": ["modifiers": ["ctrl", "alt"], "keys": [String: Any]()]
                ]
            ]
        ])
        #expect(config.directDirectionHotkeys == nil)
    }

    @Test("direction.direct で keys があるのに modifiers がなければエラー")
    func directDirectionMissingModifiers() {
        #expect(throws: ConfigError.self) {
            try WindowHintsConfigBuilder.build([
                "navigation": [
                    "direction": ["direct": ["keys": ["left": "h"]]]
                ]
            ])
        }
    }

    @Test("direction.direct の不正な方向名はエラー")
    func directDirectionUnknownDirection() {
        #expect(throws: ConfigError.self) {
            try WindowHintsConfigBuilder.build([
                "navigation": [
                    "direction": [
                        "direct": ["modifiers": ["ctrl"], "keys": ["lefty": "h"]]
                    ]
                ]
            ])
        }
    }

    @Test("direction.direct のキー重複はエラー")
    func directDirectionDuplicateKey() {
        #expect(throws: ConfigError.self) {
            try WindowHintsConfigBuilder.build([
                "navigation": [
                    "direction": [
                        "direct": [
                            "modifiers": ["ctrl"],
                            "keys": ["left": "h", "right": "H"],
                        ]
                    ]
                ]
            ])
        }
    }

    @Test("direction.direct の fn 修飾キーはエラー")
    func directDirectionFnModifier() {
        #expect(throws: ConfigError.self) {
            try WindowHintsConfigBuilder.build([
                "navigation": [
                    "direction": [
                        "direct": ["modifiers": ["fn"], "keys": ["left": "h"]]
                    ]
                ]
            ])
        }
    }
}

@Suite("WindowMoverConfigBuilder")
struct WindowMoverConfigTests {
    @Test("freeArea の隠れウィンドウ除外設定はデフォルトで有効")
    func freeAreaExcludeHiddenWindowsDefault() throws {
        let config = try WindowMoverConfigBuilder.build()
        #expect(config.excludeHiddenWindows)
    }

    @Test("freeArea の隠れウィンドウ除外設定を無効にできる")
    func freeAreaExcludeHiddenWindowsOverride() throws {
        let config = try WindowMoverConfigBuilder.build([
            "behavior": ["freeArea": ["excludeHiddenWindows": false]]
        ])
        #expect(!config.excludeHiddenWindows)
    }

    @Test("commands のホットキーを収集する")
    func collectsCommandHotkeys() throws {
        let config = try WindowMoverConfigBuilder.build([
            "commands": [
                "cycleLeft": ["hotkey": ["modifiers": ["ctrl", "alt"], "key": "h"]]
            ]
        ])
        #expect(config.commandHotkeys["cycleLeft"]?.key == "h")
    }

    @Test("不明なコマンド名はエラー")
    func rejectsUnknownCommand() {
        #expect(throws: ConfigError.self) {
            try WindowMoverConfigBuilder.build([
                "commands": [
                    "moveToSelectedArea": ["hotkey": ["modifiers": [], "key": "s"]]
                ]
            ])
        }
    }
}

@Suite("AreaHintsConfigBuilder")
struct AreaHintsConfigTests {
    @Test("spotlight alpha はデフォルト値を持つ")
    func spotlightAlphaDefault() throws {
        let config = try AreaHintsConfigBuilder.build()
        #expect(config.activeWindowSpotlightAlpha == 0.5)
    }

    @Test("spotlight alpha を上書きできる")
    func spotlightAlphaOverride() throws {
        let config = try AreaHintsConfigBuilder.build([
            "activeWindowSpotlight": ["alpha": 0.36]
        ])
        #expect(config.activeWindowSpotlightAlpha == 0.36)
    }

    @Test("アクティブ枠はデフォルト値を持つ")
    func activeWindowHighlightDefault() throws {
        let config = try AreaHintsConfigBuilder.build()
        #expect(
            config.activeWindowHighlightColor
                == ConfigColor(red: 0.95, green: 0.68, blue: 0.40, alpha: 0.95))
        #expect(config.activeWindowHighlightWidth == 13)
        #expect(config.activeWindowHighlightCornerRadius == 12)
    }

    @Test("アクティブ枠を上書きできる")
    func activeWindowHighlightOverride() throws {
        let config = try AreaHintsConfigBuilder.build([
            "activeWindowHighlight": [
                "borderColor": ["red": 0.1, "green": 0.2, "blue": 0.3, "alpha": 0.4],
                "borderWidth": 8,
                "cornerRadius": 6,
            ]
        ])
        #expect(
            config.activeWindowHighlightColor
                == ConfigColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4))
        #expect(config.activeWindowHighlightWidth == 8)
        #expect(config.activeWindowHighlightCornerRadius == 6)
    }

    @Test("hotkey と jinraiMode.hotkey をパースする")
    func parsesHotkeys() throws {
        let config = try AreaHintsConfigBuilder.build([
            "hotkey": ["modifiers": ["ctrl", "alt"], "key": "s"],
            "jinraiMode": ["hotkey": ["modifiers": ["ctrl", "alt"], "key": "j"]],
        ])
        #expect(config.hotkey == .init(modifiers: ["ctrl", "alt"], key: "s"))
        #expect(config.jinraiModeHotkey == .init(modifiers: ["ctrl", "alt"], key: "j"))
    }

    @Test("hotkey 未指定なら nil")
    func hotkeyDefaultsToNil() throws {
        let config = try AreaHintsConfigBuilder.build()
        #expect(config.hotkey == nil)
        #expect(config.jinraiModeHotkey == nil)
    }

    @Test("screens のエリア名とキーを検証して設定表記を保持する")
    func parsesScreens() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": ["UUID-A": ["halfLeft": "s", "1920x1080Center": "m"]],
            "defaultScreen": ["full": "a"],
        ])
        let mapping = config.screens["UUID-A"]?.resolve(displayCount: 1)
        #expect(mapping?["halfLeft"] == "s")
        #expect(mapping?["1920x1080Center"] == "m")
        // フラット形式はディスプレイ数によらず同じマップを返す
        #expect(config.screens["UUID-A"]?.resolve(displayCount: 3) == mapping)
        #expect(config.defaultScreen?.resolve(displayCount: 2)?["full"] == "a")
    }

    @Test("screens はディスプレイ数で分岐できる(数一致 → default → nil)")
    func parsesScreensByDisplayCount() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": [
                "UUID-A": [
                    "1": ["halfLeft": "h"],
                    "2": ["halfLeft": "jh"],
                    "default": ["halfLeft": "z"],
                ]
            ]
        ])
        let variants = config.screens["UUID-A"]
        #expect(variants?.resolve(displayCount: 1)?["halfLeft"] == "h")
        #expect(variants?.resolve(displayCount: 2)?["halfLeft"] == "jh")
        #expect(variants?.resolve(displayCount: 3)?["halfLeft"] == "z")
    }

    @Test("default なしで一致するディスプレイ数がなければ nil")
    func resolvesNilWithoutMatchingDisplayCount() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": ["UUID-A": ["2": ["halfLeft": "h"]]]
        ])
        #expect(config.screens["UUID-A"]?.resolve(displayCount: 1) == nil)
    }

    @Test("defaultScreen もディスプレイ数で分岐できる")
    func parsesDefaultScreenByDisplayCount() throws {
        let config = try AreaHintsConfigBuilder.build([
            "defaultScreen": [
                "1": ["halfLeft": "h"],
                "2": ["halfLeft": "jh"],
            ]
        ])
        #expect(config.defaultScreen?.resolve(displayCount: 1)?["halfLeft"] == "h")
        #expect(config.defaultScreen?.resolve(displayCount: 2)?["halfLeft"] == "jh")
        #expect(config.defaultScreen?.resolve(displayCount: 3) == nil)
    }

    @Test("ディスプレイ数とエリア名の混在はエラー")
    func rejectsMixedDisplayCountAndAreaNames() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": [
                    "UUID-A": [
                        "1": ["halfLeft": "h"],
                        "halfRight": "l",
                    ] as [String: Any]
                ]
            ])
        }
    }

    @Test("ディスプレイ数 0 はエラー")
    func rejectsZeroDisplayCount() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["0": ["halfLeft": "h"]]]
            ])
        }
    }

    @Test("キー衝突は変種ごとに検証する(別変種間の同一キーは許可)")
    func validatesKeyConflictsPerVariant() throws {
        // 別変種間なら同じキーを使える
        let config = try AreaHintsConfigBuilder.build([
            "screens": [
                "UUID-A": [
                    "1": ["halfLeft": "h"],
                    "2": ["halfRight": "h"],
                ]
            ]
        ])
        #expect(config.screens["UUID-A"]?.resolve(displayCount: 2)?["halfRight"] == "h")

        // 変種内の接頭辞衝突はエラー
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": [
                    "UUID-A": ["1": ["halfLeft": "K", "halfRight": "KD"]]
                ]
            ])
        }
    }

    @Test("defaultScreen もアクションキーとの衝突を検証する")
    func validatesDefaultScreenKeyConflicts() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "defaultScreen": ["halfLeft": "C"],
                "actions": ["closeWindow": "C"],
            ])
        }
    }

    @Test("不明なエリア名はエラー")
    func rejectsUnknownArea() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["centerLeft": "S"]]
            ])
        }
    }

    @Test("不明なアクション名はエラー")
    func rejectsUnknownAction() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["explodeWindow": "X"]
            ])
        }
    }

    @Test("actions にエリア名を指定できる")
    func acceptsAreaNameActions() throws {
        let config = try AreaHintsConfigBuilder.build([
            "actions": [
                "halfLeft": "1",
                "quarterTopRight": "2",
                "freeArea": "3",
                "1920x1080Center": "4",
            ]
        ])
        #expect(config.actions["halfLeft"] == "1")
        #expect(config.actions["quarterTopRight"] == "2")
        #expect(config.actions["freeArea"] == "3")
        #expect(config.actions["1920x1080Center"] == "4")
    }

    @Test("screens 未設定でも actions 同士のキー衝突を検証する")
    func validatesActionOnlyKeyConflicts() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["halfLeft": "K", "halfRight": "KD"]
            ])
        }
    }

    @Test("windowHints 遷移キーとは大小文字を無視して衝突を検証する")
    func rejectsCaseInsensitiveWindowHintsKeyConflict() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["halfLeft": "u"],
                "navigation": ["windowHints": ["key": "U"]],
            ])
        }
        // 1打鍵判定は入力途中でも効くため、キー列に含まれるだけでも衝突
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeft": "kh"]],
                "navigation": ["windowHints": ["key": "H"]],
            ])
        }
    }

    @Test("特殊キー名の windowHints 遷移キーもその文字列で始まるキーとは衝突する")
    func rejectsNamedWindowHintsKeyLiteralConflict() {
        // 入力列の完全一致判定(input == hintsKey)が先に効き "tab" キーは到達不能
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["halfLeft": "tab"],
                "navigation": ["windowHints": ["key": "tab"]],
            ])
        }
        // 入力が名前("f1")に一致した時点で遷移が発動し "f1x" は到達不能
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["halfLeft": "f1x"],
                "navigation": ["windowHints": ["key": "f1"]],
            ])
        }
        // 名前の途中まででしかないキーは通る(space の入力列にキーが到達し得ない)
        #expect(throws: Never.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeft": "spa"]],
                "navigation": ["windowHints": ["key": "space"]],
            ])
        }
    }

    @Test("既知の接頭辞でも誤記のエリア名はエラー(actions / screens)")
    func rejectsMisspelledAreaName() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["halfLeftt": "U"]
            ])
        }
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeftt": "U"]]
            ])
        }
    }

    @Test("actions のキーは1〜3文字")
    func rejectsTooLongActionKey() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "actions": ["halfLeft": "ABCD"]
            ])
        }
    }

    @Test("エリア名アクションのキーもエリアキーとの衝突を検証する")
    func rejectsAreaNameActionKeyConflict() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeft": "C"]],
                "actions": ["halfRight": "C"],
            ])
        }
    }

    @Test("エリアキーとアクションキーの重複はエラー")
    func rejectsDuplicateKeys() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeft": "C"]],
                "actions": ["closeWindow": "C"],
            ])
        }
    }

    @Test("一方が他方の接頭辞になるキーはエラー")
    func rejectsPrefixConflict() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeft": "K", "halfRight": "KD"]]
            ])
        }
    }

    @Test("navigation.windowHints.key の space は S と衝突しない")
    func allowsSpaceWindowHintsKeyWithSAreaKey() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": ["UUID-A": ["full": "S"]],
            "navigation": ["windowHints": ["key": "space"]],
        ])
        #expect(config.windowHintsKey == "space")
    }

    @Test("navigation.windowHints.key の tab は T と衝突しない")
    func allowsTabWindowHintsKeyWithTAreaKey() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": ["UUID-A": ["full": "T"]],
            "navigation": ["windowHints": ["key": "tab"]],
        ])
        #expect(config.windowHintsKey == "tab")
    }

    @Test("大文字と小文字は別キーとして共存できる(Shift 区別)")
    func allowsCaseSensitiveKeys() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": ["UUID-A": ["halfLeft": "k", "halfRight": "K"]]
        ])
        let mapping = config.screens["UUID-A"]?.resolve(displayCount: 1)
        #expect(mapping?["halfLeft"] == "k")
        #expect(mapping?["halfRight"] == "K")
    }

    @Test("大文字キーの接頭辞衝突は検出する(K と KD)")
    func rejectsCaseSensitivePrefixConflict() {
        #expect(throws: ConfigError.self) {
            try AreaHintsConfigBuilder.build([
                "screens": ["UUID-A": ["halfLeft": "K", "halfRight": "KD"]]
            ])
        }
    }

    @Test("大文字と小文字が異なれば接頭辞衝突しない(K と kd)")
    func allowsDifferentCasePrefix() throws {
        let config = try AreaHintsConfigBuilder.build([
            "screens": ["UUID-A": ["halfLeft": "K", "halfRight": "kd"]]
        ])
        let mapping = config.screens["UUID-A"]?.resolve(displayCount: 1)
        #expect(mapping?["halfLeft"] == "K")
        #expect(mapping?["halfRight"] == "kd")
    }

    @Test("navigation.windowHints.key と labels.show をパースする")
    func parsesNavigationAndLabels() throws {
        let config = try AreaHintsConfigBuilder.build([
            "navigation": ["windowHints": ["key": "h"]],
            "labels": ["show": false],
        ])
        #expect(config.windowHintsKey == "h")
        #expect(config.showLabels == false)
    }
}

@Suite("RootConfigBuilder")
struct RootConfigTests {
    private let uuidA = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
    private let uuidB = "11111111-2222-3333-4444-555555555555"

    @Test("セクションが存在する機能だけ有効になる")
    func sectionPresenceEnablesFeatures() throws {
        let config = try RootConfigBuilder.build(text: #"{ "focusBack": {} }"#)
        #expect(config.focusBack != nil)
        #expect(config.focusBorder == nil)
        #expect(config.windowHints == nil)
    }

    @Test("macosNativeTabs はデフォルトにユーザー指定を追記する")
    func macosNativeTabsMerge() throws {
        let config = try RootConfigBuilder.build(text: """
            { "macosNativeTabs": { "apps": ["com.example.app"], "stateSyncInterval": 1.0 } }
            """)
        #expect(
            config.macosNativeTabs.apps == [
                "com.mitchellh.ghostty", "com.apple.finder", "com.example.app",
            ])
        #expect(config.macosNativeTabs.stateSyncInterval == 1.0)
    }

    @Test("セクションなしでもデフォルトの macosNativeTabs を持つ")
    func defaultsWithoutSection() throws {
        let config = try RootConfigBuilder.build(text: "{}")
        #expect(config.macosNativeTabs == .default)
    }

    @Test("areaHints セクションで Area Hints が有効になる")
    func areaHintsSection() throws {
        let config = try RootConfigBuilder.build(text: """
            { "areaHints": { "hotkey": { "modifiers": ["ctrl", "alt"], "key": "s" } } }
            """)
        #expect(config.areaHints?.hotkey?.key == "s")
        #expect(config.windowMover == nil)
    }

    @Test("初回起動テンプレートはパースでき、全機能が意図したキーマップで有効になる")
    func defaultConfigTemplateParses() throws {
        let config = try RootConfigBuilder.build(text: DefaultConfigTemplate.text)
        #expect(config.focusBorder != nil)

        #expect(config.focusBack?.hotkeyModifiers == ["alt"])
        #expect(config.focusBack?.hotkeyKey == "w")

        #expect(config.windowHints?.hotkeyModifiers == ["ctrl", "alt"])
        #expect(config.windowHints?.hotkeyKey == "f")

        let commands = try #require(config.windowMover?.commandHotkeys)
        #expect(
            Set(commands.keys) == [
                "cycleLeft", "cycleRight", "maximizeWindow", "moveToNextDisplay",
            ])

        let areas = config.areaHints?.defaultScreen?.resolve(displayCount: 1)
        #expect(areas?["halfLeft"] == "H")
        #expect(config.areaHints?.hotkey?.key == "s")

        #expect(config.applicationHints?.apps.count == 2)

        // JinraiMode トリガーが各ヒントへ注入される
        #expect(config.jinraiMode.windowHintsTriggerKey == "return")
        #expect(config.jinraiMode.areaHintsTriggerKey == "return")
    }

    @Test("displayAliases を areaHints.screens と windowLayouts.screen で使える")
    func displayAliasesResolveDisplayReferences() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "displayAliases": {
                    "macbook": "\(uuidA)",
                    "desk": "\(uuidB)"
                },
                "areaHints": {
                    "screens": {
                        "macbook": { "full": "F" }
                    }
                },
                "windowLayouts": {
                    "layouts": [
                        {
                            "name": "dev",
                            "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
                            "windows": [
                                { "bundleID": "com.google.Chrome", "screen": "desk", "area": "halfLeft" }
                            ]
                        }
                    ]
                }
            }
            """)
        #expect(config.areaHints?.screens[uuidA]?.resolve(displayCount: 1)?["full"] == "F")
        #expect(config.windowLayouts?.layouts[0].windows[0].screenUUID == uuidB)
    }

    @Test("displayAliases を windowLayouts の unlistedWindows.screen で使える")
    func displayAliasesResolveUnlistedWindowsScreen() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "displayAliases": {
                    "desk": "\(uuidB)"
                },
                "windowLayouts": {
                    "layouts": [
                        {
                            "name": "dev",
                            "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
                            "unlistedWindows": { "screen": "desk", "area": "full" },
                            "windows": [
                                { "bundleID": "com.google.Chrome", "area": "halfLeft" }
                            ]
                        }
                    ]
                }
            }
            """)
        #expect(
            config.windowLayouts?.layouts[0].unlistedWindows
                == .place(screenUUID: uuidB, area: "full"))
    }

    @Test("unlistedWindows.screen の未定義別名はエラー")
    func rejectsUnknownAliasInUnlistedWindowsScreen() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: """
                {
                    "windowLayouts": {
                        "layouts": [
                            {
                                "name": "dev",
                                "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
                                "unlistedWindows": { "screen": "unknown-alias", "area": "full" },
                                "windows": [
                                    { "bundleID": "com.google.Chrome", "area": "halfLeft" }
                                ]
                            }
                        ]
                    }
                }
                """)
        }
    }

    @Test("profiles の overrides 内でも displayAliases を解決する")
    func displayAliasesResolveProfileOverrides() throws {
        let config = try RootConfigBuilder.build(
            text: """
                {
                    "displayAliases": {
                        "macbook": "\(uuidA)",
                        "desk": "\(uuidB)"
                    },
                    "profiles": [{
                        "displays": ["desk"],
                        "overrides": {
                            "areaHints": {
                                "screens": {
                                    "macbook": { "full": "F" }
                                }
                            },
                            "windowLayouts": {
                                "layouts": [
                                    {
                                        "name": "dev",
                                        "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
                                        "windows": [
                                            { "bundleID": "com.google.Chrome", "screen": "desk", "area": "halfLeft" }
                                        ]
                                    }
                                ]
                            }
                        }
                    }]
                }
                """,
            connectedDisplayUUIDs: [uuidB])
        #expect(config.areaHints?.screens[uuidA]?.resolve(displayCount: 1)?["full"] == "F")
        #expect(config.windowLayouts?.layouts[0].windows[0].screenUUID == uuidB)
    }

    @Test("displayAliases の不正値と未定義別名はエラー")
    func rejectsInvalidDisplayAliases() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: #"{ "displayAliases": [] }"#)
        }
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: """
                { "displayAliases": { "desk": "not-a-uuid" } }
                """)
        }
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: """
                {
                    "displayAliases": { "\(uuidA)": "\(uuidB)" }
                }
                """)
        }
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: """
                { "profiles": [{ "displays": ["desk"], "overrides": {} }] }
                """)
        }
    }

    @Test("areaHints.screens で同じUUIDへ解決される指定はエラー")
    func rejectsDuplicateResolvedAreaHintScreens() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: """
                {
                    "displayAliases": { "macbook": "\(uuidA)" },
                    "areaHints": {
                        "screens": {
                            "macbook": { "full": "F" },
                            "\(uuidA)": { "halfLeft": "H" }
                        }
                    }
                }
                """)
        }
    }

    @Test("jinraiMode.triggers.areaHints は areaHints へ注入される")
    func areaHintsTriggerInjection() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "areaHints": {},
                "jinraiMode": { "triggers": { "areaHints": { "key": "return" } } }
            }
            """)
        #expect(config.areaHints?.jinraiModeKey == "return")
    }

    @Test("jinraiMode.triggers.areaHints.key とエリア・アクションキーの衝突はエラー")
    func rejectsJinraiModeTriggerKeyConflict() {
        // エリアキーと衝突(大小文字無視)
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                {
                    "areaHints": { "defaultScreen": { "halfLeft": "J" } },
                    "jinraiMode": { "triggers": { "areaHints": { "key": "j" } } }
                }
                """)
        }
        // アクションキーと衝突
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                {
                    "areaHints": { "actions": { "halfLeft": "j" } },
                    "jinraiMode": { "triggers": { "areaHints": { "key": "j" } } }
                }
                """)
        }
        // windowHints 遷移キーと衝突(jinraiMode 開始が先に効いて到達不能)
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                {
                    "areaHints": { "navigation": { "windowHints": { "key": "j" } } },
                    "jinraiMode": { "triggers": { "areaHints": { "key": "J" } } }
                }
                """)
        }
        // 複数文字の windowHints 遷移キーの入力途中の1打鍵を消費するのも衝突
        #expect(throws: ConfigError.self) {
            try RootConfigBuilder.build(text: """
                {
                    "areaHints": { "navigation": { "windowHints": { "key": "kj" } } },
                    "jinraiMode": { "triggers": { "areaHints": { "key": "j" } } }
                }
                """)
        }
        // 衝突しなければ通る(return は特殊キー)
        #expect(throws: Never.self) {
            try RootConfigBuilder.build(text: """
                {
                    "areaHints": { "defaultScreen": { "halfLeft": "J" } },
                    "jinraiMode": { "triggers": { "areaHints": { "key": "return" } } }
                }
                """)
        }
    }

}
