import Foundation

/// 設定上のキー表現を、文字列シーケンスと特殊キー名に分けて比較する。
public struct ConfigKeyDescriptor: Equatable, Sendable {
    private static let namedKeyAliases: [String: String] = {
        var aliases: [String: String] = [
            "return": "return", "enter": "return",
            "tab": "tab",
            "space": "space",
            "delete": "delete", "backspace": "delete",
            "forwarddelete": "forwarddelete",
            "escape": "escape",
            "left": "left", "right": "right",
            "up": "up", "down": "down",
            "home": "home", "end": "end",
            "pageup": "pageup", "pagedown": "pagedown",
        ]
        for number in 1...20 {
            aliases["f\(number)"] = "f\(number)"
        }
        return aliases
    }()

    public let normalized: String
    public let display: String
    public let isNamedKey: Bool

    public static func sequence(_ raw: String) -> ConfigKeyDescriptor {
        let normalized = raw.uppercased()
        return .init(normalized: normalized, display: normalized, isNamedKey: false)
    }

    public static func keyName(_ raw: String) -> ConfigKeyDescriptor {
        let lowercased = raw.lowercased()
        if let named = namedKeyAliases[lowercased] {
            return .init(normalized: named, display: named.uppercased(), isNamedKey: true)
        }
        return sequence(raw)
    }

    public static func typedSequence(forKeyName raw: String) -> String? {
        let descriptor = keyName(raw)
        return descriptor.isNamedKey ? nil : descriptor.normalized
    }

    public static func matches(configuredKeyName: String?, inputKeyName: String?) -> Bool {
        guard let configuredKeyName, let inputKeyName else { return false }
        return keyName(configuredKeyName) == keyName(inputKeyName)
    }

    public func conflicts(with other: ConfigKeyDescriptor) -> Bool {
        if isNamedKey || other.isNamedKey {
            return isNamedKey && other.isNamedKey && normalized == other.normalized
        }
        return normalized == other.normalized
            || normalized.hasPrefix(other.normalized)
            || other.normalized.hasPrefix(normalized)
    }
}
