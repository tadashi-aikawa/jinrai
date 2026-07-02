import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("HintKeyAssignment")
struct HintKeyAssignmentTests {
    func entry(
        _ id: UInt32, app: String, title: String = "", bundleID: String? = nil
    ) -> HintKeyAssignment.Entry {
        HintKeyAssignment.Entry(
            window: WindowInfo(id: id, bundleID: bundleID, appName: app, title: title),
            appKey: bundleID ?? app,
            appTitle: app,
            title: title
        )
    }

    @Test("単独アプリはアプリ名イニシャル1文字のキー")
    func singleWindowGetsInitial() {
        let hints = HintKeyAssignment.assign(entries: [entry(1, app: "Safari")])
        #expect(hints.count == 1)
        #expect(hints[0].key == "S")
    }

    @Test("同一アプリの複数ウィンドウは接頭辞+サフィックス")
    func multipleWindowsGetSuffixes() {
        let hints = HintKeyAssignment.assign(entries: [
            entry(1, app: "Safari", title: "one"),
            entry(2, app: "Safari", title: "two"),
        ])
        #expect(hints.map(\.key) == ["SA", "SS"])
    }

    @Test("イニシャルが衝突する別アプリはアプリ名の他の文字を使う")
    func conflictingInitialsResolved() {
        let hints = HintKeyAssignment.assign(entries: [
            entry(1, app: "Safari"),
            entry(2, app: "Slack"),
        ])
        let keys = hints.map(\.key).sorted()
        #expect(keys.contains("S"))
        #expect(keys.contains("L"))  // Slack の2文字目
    }

    @Test("イニシャルが hintChars にないアプリは fallback 接頭辞")
    func nonLatinAppUsesFallback() {
        let hints = HintKeyAssignment.assign(entries: [entry(1, app: "電卓")])
        #expect(hints[0].key == "A")
    }

    @Test("prefixOverrides: bundleID 一致で固定接頭辞")
    func overrideByBundleID() {
        let hints = HintKeyAssignment.assign(
            entries: [entry(1, app: "Google Chrome", bundleID: "com.google.Chrome")],
            overrides: [.init(bundleID: "com.google.Chrome", prefix: "C")]
        )
        #expect(hints[0].key == "C")
    }

    @Test("prefixOverrides: titleGlob 一致で固定接頭辞")
    func overrideByTitleGlob() {
        let hints = HintKeyAssignment.assign(
            entries: [
                entry(1, app: "Ghostty", title: "vim - main.swift"),
                entry(2, app: "Ghostty", title: "zsh"),
            ],
            overrides: [.init(titleGlob: "vim *", prefix: "V")]
        )
        let vimHint = hints.first { $0.entry.window.id == 1 }
        #expect(vimHint?.key == "V")
    }

    @Test("キーは prefix-free(あるキーが別キーの先頭にならない)")
    func keysArePrefixFree() {
        // 多数のアプリでキー空間を圧迫しても prefix-free を保つ
        var entries: [HintKeyAssignment.Entry] = []
        for (i, name) in ["Safari", "Slack", "Spotify", "Stickies", "System Settings"]
            .enumerated()
        {
            entries.append(entry(UInt32(i + 1), app: name))
            entries.append(entry(UInt32(100 + i), app: name, title: "second"))
        }
        let hints = HintKeyAssignment.assign(entries: entries)
        let keys = hints.map(\.key)
        #expect(Set(keys).count == keys.count)  // ユニーク
        for a in keys {
            for b in keys where a != b {
                #expect(!b.hasPrefix(a), "キー \(a) が \(b) の接頭辞になっている")
            }
        }
    }

    @Test("予約文字は hintChars から除外される")
    func reservedCharsExcluded() {
        let hints = HintKeyAssignment.assign(
            entries: [entry(1, app: "Safari")],
            reservedChars: ["s"]
        )
        #expect(hints[0].key != "S")
    }

    @Test("glob: * と ? のマッチ")
    func globMatching() {
        #expect(HintKeyAssignment.globMatch("vim *", "vim - main.swift"))
        #expect(HintKeyAssignment.globMatch("*.swift", "main.swift"))
        #expect(HintKeyAssignment.globMatch("a?c", "abc"))
        #expect(!HintKeyAssignment.globMatch("a?c", "abbc"))
        #expect(!HintKeyAssignment.globMatch("Vim *", "vim x"))  // 大小区別
    }
}

@Suite("HintInputMatcher")
struct HintInputMatcherTests {
    let keys = ["S", "CA", "CS"]

    @Test("完全一致で選択")
    func exactMatchSelects() {
        #expect(
            HintInputMatcher.advance(currentInput: "", char: "s", keys: keys)
                == .selected("S"))
    }

    @Test("接頭辞一致で入力継続")
    func prefixMatchContinues() {
        #expect(
            HintInputMatcher.advance(currentInput: "", char: "c", keys: keys)
                == .partial("C"))
        #expect(
            HintInputMatcher.advance(currentInput: "C", char: "a", keys: keys)
                == .selected("CA"))
    }

    @Test("一致しない入力は最後の1文字で再試行")
    func retriesWithLastChar() {
        #expect(
            HintInputMatcher.advance(currentInput: "C", char: "s", keys: ["CA", "SD"])
                == .partial("S"))
    }

    @Test("どれにも一致しなければリセット")
    func resetsWhenNoMatch() {
        #expect(
            HintInputMatcher.advance(currentInput: "", char: "x", keys: keys) == .reset)
    }

    @Test("Backspace で1文字戻る")
    func backspaceDropsLast() {
        #expect(HintInputMatcher.backspace(currentInput: "CA") == "C")
        #expect(HintInputMatcher.backspace(currentInput: "") == "")
    }
}
