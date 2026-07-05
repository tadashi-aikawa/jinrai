import Foundation

/// セマンティックバージョン(アップデート判定用の純粋ロジック)。
/// `v0.1.2` / `0.1.2` を受け付け、`0.0.0-development` のような
/// prerelease サフィックス付きは「開発ビルド」として比較対象外にする。
public struct SemanticVersion: Equatable, Comparable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// `v` プレフィックスの有無は問わない。prerelease サフィックス付きや
    /// 数値3要素で解釈できない文字列は nil(開発ビルド扱い)
    public init?(_ string: String) {
        var body = string
        if body.hasPrefix("v") {
            body = String(body.dropFirst())
        }
        // "-development" 等の prerelease 付きは開発ビルドとみなす
        guard !body.contains("-") else { return nil }
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2])
        else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}
