import Foundation

/// 接続中ディスプレイに応じた設定オーバーライド(profiles)の解決。
/// 各プロファイルは displays の UUID がいずれか1つでも接続中なら適用され、
/// マッチしたものが定義順に deep merge される(後勝ち)。
public enum ProfilesResolver {
    /// root dict から "profiles" を取り出し、マッチしたプロファイルの overrides を
    /// 定義順に deep merge した新しい root dict を返す。
    /// 戻り値に "profiles" キーは残さない(下流の Builder は profiles を関知しない)。
    public static func apply(
        root: [String: Any], connectedDisplayUUIDs: [String]
    ) throws -> [String: Any] {
        var resolved = root
        guard let rawProfiles = resolved.removeValue(forKey: "profiles") else {
            return resolved
        }
        guard let profiles = rawProfiles as? [Any] else {
            throw ConfigError("[jinrai.profiles] profiles は配列である必要があります")
        }
        let connected = Set(connectedDisplayUUIDs.map { $0.uppercased() })
        for (index, rawProfile) in profiles.enumerated() {
            let context = "profiles[\(index)]"
            guard let profile = rawProfile as? [String: Any] else {
                throw ConfigError("[jinrai.\(context)] オブジェクトである必要があります")
            }
            guard let displays = profile["displays"] as? [String], !displays.isEmpty else {
                throw ConfigError(
                    "[jinrai.\(context)] displays はディスプレイUUID(文字列)の配列が1件以上必要です")
            }
            guard let overrides = profile["overrides"] as? [String: Any] else {
                throw ConfigError("[jinrai.\(context)] overrides はオブジェクトが必須です")
            }
            if overrides["profiles"] != nil {
                throw ConfigError("[jinrai.\(context)] overrides の中に profiles は書けません")
            }
            let matched = displays.contains { connected.contains($0.uppercased()) }
            if matched {
                resolved = DeepMerge.merge(defaults: resolved, overrides: overrides)
            }
        }
        return resolved
    }
}
