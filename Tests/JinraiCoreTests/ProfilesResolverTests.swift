import Foundation
import Testing

@testable import JinraiCore

@Suite("ProfilesResolver")
struct ProfilesResolverTests {
    private let uuidA = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
    private let uuidB = "11111111-2222-3333-4444-555555555555"

    private func configText(profiles: String) -> String {
        """
        {
            "jinraiMode": {
                "combo": {
                    "character": { "enabled": false },
                    "text": { "enabled": false, "alpha": 0.5 }
                }
            },
            "profiles": \(profiles)
        }
        """
    }

    @Test("接続中UUIDにマッチしたプロファイルが適用される")
    func appliesMatchedProfile() throws {
        let text = configText(
            profiles: """
                [{
                    "displays": ["\(uuidA)"],
                    "overrides": {
                        "jinraiMode": {
                            "combo": {
                                "character": { "enabled": true },
                                "text": { "enabled": true }
                            }
                        }
                    }
                }]
                """)
        let config = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidA])
        #expect(config.jinraiMode.comboCharacter.enabled)
        #expect(config.jinraiMode.comboText.enabled)
    }

    @Test("接続中UUIDにマッチしなければベース設定のまま")
    func skipsUnmatchedProfile() throws {
        let text = configText(
            profiles: """
                [{
                    "displays": ["\(uuidA)"],
                    "overrides": {
                        "jinraiMode": { "combo": { "character": { "enabled": true } } }
                    }
                }]
                """)
        let config = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidB])
        #expect(!config.jinraiMode.comboCharacter.enabled)
    }

    @Test("displays のいずれか1つでも接続中なら適用される(OR)")
    func matchesAnyOfDisplays() throws {
        let text = configText(
            profiles: """
                [{
                    "displays": ["\(uuidA)", "\(uuidB)"],
                    "overrides": {
                        "jinraiMode": { "combo": { "character": { "enabled": true } } }
                    }
                }]
                """)
        let config = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidB])
        #expect(config.jinraiMode.comboCharacter.enabled)
    }

    @Test("複数プロファイルがマッチしたら定義順に deep merge され後勝ち")
    func laterProfileWins() throws {
        let text = configText(
            profiles: """
                [
                    {
                        "displays": ["\(uuidA)"],
                        "overrides": {
                            "jinraiMode": { "combo": { "character": { "enabled": true } } }
                        }
                    },
                    {
                        "displays": ["\(uuidB)"],
                        "overrides": {
                            "jinraiMode": { "combo": { "character": { "enabled": false } } }
                        }
                    }
                ]
                """)
        let config = try RootConfigBuilder.build(
            text: text, connectedDisplayUUIDs: [uuidA, uuidB])
        #expect(!config.jinraiMode.comboCharacter.enabled)
    }

    @Test("部分的な上書きでは他のキーはベース値が保持される")
    func deepMergeKeepsUntouchedKeys() throws {
        let text = configText(
            profiles: """
                [{
                    "displays": ["\(uuidA)"],
                    "overrides": {
                        "jinraiMode": { "combo": { "character": { "enabled": true } } }
                    }
                }]
                """)
        let config = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidA])
        #expect(config.jinraiMode.comboCharacter.enabled)
        #expect(!config.jinraiMode.comboText.enabled)
        #expect(config.jinraiMode.comboText.alpha == 0.5)
    }

    @Test("UUID の大文字小文字は無視して比較される")
    func matchesCaseInsensitively() throws {
        let text = configText(
            profiles: """
                [{
                    "displays": ["\(uuidA.lowercased())"],
                    "overrides": {
                        "jinraiMode": { "combo": { "character": { "enabled": true } } }
                    }
                }]
                """)
        let config = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidA])
        #expect(config.jinraiMode.comboCharacter.enabled)
    }

    @Test("displayAliases の別名で接続中ディスプレイにマッチする")
    func matchesDisplayAlias() throws {
        let text = """
            {
                "displayAliases": { "desk": "\(uuidA)" },
                "jinraiMode": {
                    "combo": {
                        "character": { "enabled": false },
                        "text": { "enabled": false }
                    }
                },
                "profiles": [{
                    "displays": ["desk"],
                    "overrides": {
                        "jinraiMode": { "combo": { "character": { "enabled": true } } }
                    }
                }]
            }
            """
        let config = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidA])
        #expect(config.jinraiMode.comboCharacter.enabled)
    }

    @Test("profiles なし・空配列は後方互換(ベース設定のまま)")
    func backwardCompatible() throws {
        let noProfiles = """
            { "jinraiMode": { "combo": { "character": { "enabled": true } } } }
            """
        let config1 = try RootConfigBuilder.build(text: noProfiles, connectedDisplayUUIDs: [uuidA])
        #expect(config1.jinraiMode.comboCharacter.enabled)

        let config2 = try RootConfigBuilder.build(
            text: configText(profiles: "[]"), connectedDisplayUUIDs: [uuidA])
        #expect(!config2.jinraiMode.comboCharacter.enabled)
    }

    @Test("jinraiMode 以外のセクションもオーバーライドできる")
    func overridesOtherSections() throws {
        let text = """
            {
                "windowHints": { "hint": { "chars": ["A", "S", "D", "F"] } },
                "profiles": [{
                    "displays": ["\(uuidA)"],
                    "overrides": { "windowHints": { "hint": { "chars": ["Q", "W", "E", "R"] } } }
                }]
            }
            """
        let matched = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidA])
        let unmatched = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidB])
        #expect(matched.windowHints?.hintChars != unmatched.windowHints?.hintChars)
    }

    @Test("ベースにないセクションを overrides で有効化できる")
    func enablesSectionViaOverrides() throws {
        let text = """
            {
                "profiles": [{
                    "displays": ["\(uuidA)"],
                    "overrides": { "focusBorder": {} }
                }]
            }
            """
        let matched = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [uuidA])
        let unmatched = try RootConfigBuilder.build(text: text, connectedDisplayUUIDs: [])
        #expect(matched.focusBorder != nil)
        #expect(unmatched.focusBorder == nil)
    }

    @Test("profiles が配列でなければエラー")
    func rejectsNonArrayProfiles() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: #"{ "profiles": {} }"#)
        }
    }

    @Test("displays が空・欠落ならエラー")
    func rejectsInvalidDisplays() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(
                text: #"{ "profiles": [{ "displays": [], "overrides": {} }] }"#)
        }
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(text: #"{ "profiles": [{ "overrides": {} }] }"#)
        }
    }

    @Test("overrides が欠落・非オブジェクトならエラー")
    func rejectsInvalidOverrides() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(
                text: #"{ "profiles": [{ "displays": ["X"] }] }"#)
        }
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(
                text: #"{ "profiles": [{ "displays": ["X"], "overrides": [] }] }"#)
        }
    }

    @Test("overrides の中の profiles はエラー")
    func rejectsNestedProfiles() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(
                text: #"{ "profiles": [{ "displays": ["X"], "overrides": { "profiles": [] } }] }"#)
        }
    }

    @Test("overrides の中の displayAliases はエラー")
    func rejectsNestedDisplayAliases() {
        #expect(throws: ConfigError.self) {
            _ = try RootConfigBuilder.build(
                text: """
                    {
                        "displayAliases": { "desk": "\(uuidA)" },
                        "profiles": [{
                            "displays": ["desk"],
                            "overrides": { "displayAliases": { "other": "\(uuidB)" } }
                        }]
                    }
                    """)
        }
    }
}
