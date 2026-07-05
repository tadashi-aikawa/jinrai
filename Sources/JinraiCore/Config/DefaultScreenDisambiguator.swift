import Foundation

/// defaultScreen 由来のエリアマッピングのキーが他ディスプレイのキーと衝突すると
/// 最初のディスプレイしか選択できないため、衝突するマッピングへ
/// 数字プレフィックス(2, 3, …)を付けて解消する。
/// screens(UUID明示設定)由来のマッピングは変更しない
public enum DefaultScreenDisambiguator {
    /// 表示順の (mapping, isDefault: defaultScreen 由来か) を受け取り、実効マッピング列を返す。
    /// defaultScreen 由来のマッピングは、それまでに確定したキー
    /// (予約キー + 明示設定の全キー + 先行ディスプレイの実効キー)と衝突する場合だけプレフィックスされる
    public static func disambiguate(
        mappings: [(mapping: [String: String], isDefault: Bool)],
        reservedKeys: Set<String>
    ) -> [[String: String]] {
        var existingKeys = reservedKeys
        for entry in mappings where !entry.isDefault {
            existingKeys.formUnion(entry.mapping.values)
        }

        var result: [[String: String]] = []
        var nextDigit = 2
        for entry in mappings {
            guard entry.isDefault else {
                result.append(entry.mapping)
                continue
            }
            let conflicted = entry.mapping.values.contains { key in
                existingKeys.contains { conflicts(key, $0) }
            }
            guard conflicted else {
                existingKeys.formUnion(entry.mapping.values)
                result.append(entry.mapping)
                continue
            }
            let prefix = pickPrefix(from: &nextDigit, mapping: entry.mapping, existingKeys: existingKeys)
            let prefixed = entry.mapping.mapValues { "\(prefix)\($0)" }
            existingKeys.formUnion(prefixed.values)
            result.append(prefixed)
        }
        return result
    }

    /// 既存キーと衝突しない最小の数字プレフィックスを選ぶ。
    /// 2〜9 が尽きた場合は衝突覚悟でそのまま連番を使う
    private static func pickPrefix(
        from nextDigit: inout Int,
        mapping: [String: String], existingKeys: Set<String>
    ) -> String {
        if nextDigit <= 9 {
            for digit in nextDigit...9 {
                let conflicted = mapping.values.contains { key in
                    existingKeys.contains { conflicts("\(digit)\(key)", $0) }
                }
                if !conflicted {
                    nextDigit = digit + 1
                    return String(digit)
                }
            }
        }
        defer { nextDigit += 1 }
        return String(nextDigit)
    }

    /// AreaHintsConfigBuilder.validateKeyConflicts と同じ規則(完全一致 or 接頭辞包含)
    private static func conflicts(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b) || b.hasPrefix(a)
    }
}
