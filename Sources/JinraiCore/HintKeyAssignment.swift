import Foundation

/// ヒントキー割当(元 window_hints.lua L635-897, L3279-)。
/// アプリ名イニシャルの接頭辞 + グループ内サフィックスでキーを決め、
/// prefix-free(あるキーが別キーの先頭にならない)に調整する。
public enum HintKeyAssignment {
    public static var defaultHintChars: [String] {
        [
            "A", "S", "D", "F", "G", "H", "J", "K", "L",
            "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
            "Z", "X", "C", "V", "B", "N", "M",
        ]
    }

    /// 割当対象(collectEntries の結果 1 ウィンドウ分)
    public struct Entry {
        public var window: WindowInfo
        /// アプリの同一性キー(bundleID ?? アプリ名)
        public var appKey: String
        public var appTitle: String
        public var title: String

        public init(window: WindowInfo, appKey: String, appTitle: String, title: String) {
            self.window = window
            self.appKey = appKey
            self.appTitle = appTitle
            self.title = title
        }
    }

    /// prefixOverrides ルール(bundleID / titleGlob の AND 条件)
    public struct PrefixOverride: Sendable {
        public var bundleID: String?
        public var titleGlob: String?
        public var prefix: String

        public init(bundleID: String? = nil, titleGlob: String? = nil, prefix: String) {
            self.bundleID = bundleID
            self.titleGlob = titleGlob
            self.prefix = prefix
        }
    }

    public struct Hint {
        public var entry: Entry
        public var key: String
    }

    // MARK: - glob マッチ(* と ?、大小区別あり)

    public static func globMatch(_ glob: String, _ text: String) -> Bool {
        let pattern = Array(glob)
        let target = Array(text)

        func match(_ p: Int, _ t: Int) -> Bool {
            if p == pattern.count { return t == target.count }
            switch pattern[p] {
            case "*":
                // 空にもマッチ
                for skip in t...target.count {
                    if match(p + 1, skip) { return true }
                }
                return false
            case "?":
                guard t < target.count else { return false }
                return match(p + 1, t + 1)
            default:
                guard t < target.count, target[t] == pattern[p] else { return false }
                return match(p + 1, t + 1)
            }
        }
        return match(0, 0)
    }

    // MARK: - 接頭辞決定

    static func normalizePrefixChar(_ value: String, allowed: Set<String>) -> String? {
        guard let first = value.first else { return nil }
        let c = String(first).uppercased()
        return allowed.contains(c) ? c : nil
    }

    static func resolveOverridePrefix(
        bundleID: String?, windowTitle: String, overrides: [PrefixOverride]
    ) -> String? {
        for rule in overrides {
            let bundleMatched = rule.bundleID == nil || rule.bundleID == bundleID
            guard bundleMatched else { continue }
            let titleMatched = rule.titleGlob.map { globMatch($0, windowTitle) } ?? true
            if titleMatched {
                return rule.prefix.uppercased()
            }
        }
        return nil
    }

    /// index(0始まり)→ サフィックス文字列(元 keySuffixFor)。
    /// 26進数のように増える: A, S, D, ..., M, AA, AS, ...
    static func keySuffix(for index: Int, hintChars: [String]) -> String {
        let base = hintChars.count
        var n = index
        var code = ""
        while true {
            let rem = n % base
            code = hintChars[rem] + code
            n = n / base - 1
            if n < 0 { break }
        }
        return code
    }

    /// ヒントキーの表示順比較(hintChars の並び順を優先)
    static func comparePrefixes(_ a: String, _ b: String, order: [String: Int]) -> Bool {
        guard a != b else { return false }
        let aChars = Array(a)
        let bChars = Array(b)
        for i in 0..<max(aChars.count, bChars.count) {
            let ac = i < aChars.count ? String(aChars[i]) : ""
            let bc = i < bChars.count ? String(bChars[i]) : ""
            if ac != bc {
                if ac.isEmpty { return true }
                if bc.isEmpty { return false }
                if let ai = order[ac], let bi = order[bc], ai != bi {
                    return ai < bi
                }
                return ac < bc
            }
        }
        return aChars.count < bChars.count
    }

    static func isStrictPrefix(_ a: String, _ b: String) -> Bool {
        a.count < b.count && b.hasPrefix(a)
    }

    static func keysConflict(_ a: String, _ b: String) -> Bool {
        a == b || isStrictPrefix(a, b) || isStrictPrefix(b, a)
    }

    static func findExpandedKey(
        baseKey: String, otherKeys: [String], hintChars: [String]
    ) -> String {
        var index = 0
        while true {
            let candidate = baseKey + keySuffix(for: index, hintChars: hintChars)
            if !otherKeys.contains(where: { keysConflict(candidate, $0) }) {
                return candidate
            }
            index += 1
        }
    }

    // MARK: - 割当本体

    /// entries は表示順(appTitle → title → x → y でソート済み)を想定。
    /// reservedChars はナビゲーションキー等に予約された文字(hintChars から除外)。
    public static func assign(
        entries: [Entry],
        hintChars: [String] = defaultHintChars,
        overrides: [PrefixOverride] = [],
        reservedChars: Set<String> = []
    ) -> [Hint] {
        let chars = hintChars.map { $0.uppercased() }
            .filter { !reservedChars.contains($0.lowercased()) && !reservedChars.contains($0) }
        guard !chars.isEmpty else { return [] }
        let allowed = Set(chars)
        let order = Dictionary(
            uniqueKeysWithValues: chars.enumerated().map { ($1, $0) })
        let fallback = chars[0]

        // 1. 接頭辞決定(override → アプリ名イニシャル → fallback)
        struct Prefixed {
            var entry: Entry
            var basePrefix: String
            var isOverride: Bool
            var prefix: String = ""
        }
        var prefixed: [Prefixed] = entries.map { entry in
            if let override = resolveOverridePrefix(
                bundleID: entry.window.bundleID, windowTitle: entry.title, overrides: overrides)
            {
                return Prefixed(entry: entry, basePrefix: override, isOverride: true)
            }
            let base =
                normalizePrefixChar(entry.appTitle, allowed: allowed) ?? fallback
            return Prefixed(entry: entry, basePrefix: base, isOverride: false)
        }

        // 2. アプリ間の接頭辞衝突解消(元 assignUniquePrefixes)
        var used = Set<String>()
        var appPrefixMap: [String: String] = [:]
        for i in prefixed.indices {
            if prefixed[i].isOverride {
                let chosen = prefixed[i].basePrefix
                used.insert(chosen)
                prefixed[i].prefix = chosen
                continue
            }
            let appKey = prefixed[i].entry.appKey
            if let existing = appPrefixMap[appKey] {
                prefixed[i].prefix = existing
                continue
            }
            var chosen = prefixed[i].basePrefix
            var candidates = [chosen]
            for ch in prefixed[i].entry.appTitle {
                if let normalized = normalizePrefixChar(String(ch), allowed: allowed),
                    !candidates.contains(normalized)
                {
                    candidates.append(normalized)
                }
            }
            if let free = candidates.first(where: { !used.contains($0) }) {
                chosen = free
            }
            appPrefixMap[appKey] = chosen
            used.insert(chosen)
            prefixed[i].prefix = chosen
        }

        // 3. 接頭辞グループ内でキーを割当(元 buildHintEntries)
        var grouped: [String: [Prefixed]] = [:]
        for item in prefixed {
            grouped[item.prefix, default: []].append(item)
        }
        let sortedPrefixes = grouped.keys.sorted { comparePrefixes($0, $1, order: order) }

        var hints: [Hint] = []
        for prefix in sortedPrefixes {
            guard let group = grouped[prefix] else { continue }
            for (index, item) in group.enumerated() {
                let key =
                    group.count == 1
                    ? prefix
                    : prefix + keySuffix(for: index, hintChars: chars)
                hints.append(Hint(entry: item.entry, key: key))
            }
        }

        // 4. prefix-free 化(元 makeKeysPrefixFree)
        let maxIterations = max(1, hints.count * 32)
        for _ in 0..<maxIterations {
            var changed = false
            for i in hints.indices {
                let key = hints[i].key
                let hasConflict = hints.indices.contains { j in
                    j != i && isStrictPrefix(key, hints[j].key)
                }
                if hasConflict {
                    let otherKeys = hints.indices.filter { $0 != i }.map { hints[$0].key }
                    hints[i].key = findExpandedKey(
                        baseKey: key, otherKeys: otherKeys, hintChars: chars)
                    changed = true
                }
            }
            if !changed {
                return hints.sorted { comparePrefixes($0.key, $1.key, order: order) }
            }
        }
        return hints
    }
}
