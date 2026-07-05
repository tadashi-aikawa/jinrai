import Testing

@testable import JinraiCore

@Suite("SemanticVersion")
struct SemanticVersionTests {
    @Test("基本的なパース")
    func basicParse() {
        #expect(SemanticVersion("1.2.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
        #expect(SemanticVersion("v1.2.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
        #expect(SemanticVersion("0.0.1") == SemanticVersion(major: 0, minor: 0, patch: 1))
    }

    @Test("開発ビルドや不正な文字列は nil")
    func invalidReturnsNil() {
        #expect(SemanticVersion("0.0.0-development") == nil)
        #expect(SemanticVersion("1.2.3-beta.1") == nil)
        #expect(SemanticVersion("1.2") == nil)
        #expect(SemanticVersion("1.2.3.4") == nil)
        #expect(SemanticVersion("abc") == nil)
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("1.x.3") == nil)
    }

    @Test("大小比較")
    func comparison() {
        #expect(SemanticVersion("1.0.0")! < SemanticVersion("2.0.0")!)
        #expect(SemanticVersion("1.0.0")! < SemanticVersion("1.1.0")!)
        #expect(SemanticVersion("1.1.0")! < SemanticVersion("1.1.1")!)
        #expect(SemanticVersion("0.9.9")! < SemanticVersion("0.10.0")!)
        #expect(!(SemanticVersion("1.2.3")! < SemanticVersion("1.2.3")!))
    }

    @Test("description は v なし表記")
    func descriptionFormat() {
        #expect(SemanticVersion("v1.2.3")!.description == "1.2.3")
    }
}
