import Testing

@testable import JinraiCore

@Suite("DefaultScreenDisambiguator")
struct DefaultScreenDisambiguatorTests {
    let defaultMapping = ["halfLeft": "H", "halfRight": "L", "full": "F"]

    @Test("defaultScreen 2枚: 1枚目は無変更、2枚目は数字プレフィックス付き")
    func prefixesSecondDefaultScreen() {
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(defaultMapping, true), (defaultMapping, true)],
            reservedKeys: [])
        #expect(result[0] == defaultMapping)
        #expect(result[1] == ["halfLeft": "2H", "halfRight": "2L", "full": "2F"])
    }

    @Test("defaultScreen 3枚: 出現順に 2, 3 を付与")
    func prefixesThirdDefaultScreen() {
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(defaultMapping, true), (defaultMapping, true), (defaultMapping, true)],
            reservedKeys: [])
        #expect(result[1]["halfLeft"] == "2H")
        #expect(result[2]["halfLeft"] == "3H")
    }

    @Test("UUID設定とdefaultScreenの混在: UUID分は無変更で番号は出現順")
    func mixedConfiguredAndDefault() {
        let configured = ["full": "A"]
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(configured, false), (defaultMapping, true), (defaultMapping, true)],
            reservedKeys: [])
        #expect(result[0] == configured)
        #expect(result[1] == defaultMapping)
        #expect(result[2]["halfLeft"] == "2H")
    }

    @Test("defaultScreen 1枚のみなら無変更")
    func singleDefaultScreenUnchanged() {
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(["full": "A"], false), (defaultMapping, true)],
            reservedKeys: [])
        #expect(result[1] == defaultMapping)
    }

    @Test("UUID設定とdefaultScreenのキーが同じ場合、defaultScreen側だけプレフィックスされる")
    func prefixesSingleDefaultConflictingWithConfigured() {
        // UUID設定("default"分岐等)と defaultScreen に同じキーを書いたケース
        let jKeys = ["full": "JD", "halfLeft": "JW", "freeArea": "JF"]
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(jKeys, false), (jKeys, true)],
            reservedKeys: [])
        #expect(result[0] == jKeys)
        #expect(result[1] == ["full": "2JD", "halfLeft": "2JW", "freeArea": "2JF"])
    }

    @Test("defaultScreenが先頭でも明示設定と衝突すればdefaultScreen側がプレフィックスされる")
    func prefixesLeadingDefaultConflictingWithConfigured() {
        let jKeys = ["full": "JD", "halfLeft": "JW"]
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(jKeys, true), (jKeys, false)],
            reservedKeys: [])
        #expect(result[0] == ["full": "2JD", "halfLeft": "2JW"])
        #expect(result[1] == jKeys)
    }

    @Test("予約キーと衝突する数字はスキップする")
    func skipsConflictingDigit() {
        // アクションキー "2" は "2H" の接頭辞になるため 3 を使う
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(defaultMapping, true), (defaultMapping, true)],
            reservedKeys: ["2"])
        #expect(result[1]["halfLeft"] == "3H")
    }

    @Test("プレフィックス後のキーが既存キーと接頭辞衝突する場合もスキップする")
    func skipsPrefixConflictWithExistingKey() {
        // 1枚目(UUID設定)に "2H" があるため、2枚目のdefaultScreenは 3 を使う
        let configured = ["quarterTopLeft": "2H"]
        let result = DefaultScreenDisambiguator.disambiguate(
            mappings: [(configured, false), (defaultMapping, true), (defaultMapping, true)],
            reservedKeys: [])
        #expect(result[2]["halfLeft"] == "3H")
    }
}
