import Foundation

/// 設定エラー(元 Lua 実装の error() 相当。メッセージはユーザーに表示される)
public struct ConfigError: Error, CustomStringConvertible, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

/// デフォルト値と上書き値の deep merge(元 *_config.lua の deepMerge)。
/// 辞書同士はキー単位で再帰マージ、配列は置換、それ以外は上書き。
public enum DeepMerge {
    public static func merge(defaults: Any?, overrides: Any?) -> Any? {
        guard let defaultsDict = defaults as? [String: Any] else {
            return overrides ?? defaults
        }
        guard let overridesDict = overrides as? [String: Any] else {
            return overrides ?? defaults
        }
        var merged = defaultsDict
        for (key, value) in overridesDict {
            merged[key] = merge(defaults: defaultsDict[key], overrides: value)
        }
        return merged
    }

    public static func merge(defaults: [String: Any], overrides: [String: Any]) -> [String: Any] {
        (merge(defaults: defaults as Any, overrides: overrides as Any) as? [String: Any]) ?? defaults
    }
}

/// マージ済み [String: Any] からの型付き取り出しヘルパー
public struct ConfigDict {
    public let raw: [String: Any]
    private let context: String

    public init(_ raw: [String: Any], context: String) {
        self.raw = raw
        self.context = context
    }

    /// "visual.border.width" のようなドットパスで値を取り出す
    public func value(_ path: String) -> Any? {
        var current: Any? = raw
        for key in path.split(separator: ".") {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[String(key)]
        }
        if current is NSNull { return nil }
        return current
    }

    public func dict(_ path: String) -> [String: Any]? {
        value(path) as? [String: Any]
    }

    public func string(_ path: String) -> String? {
        value(path) as? String
    }

    public func double(_ path: String) -> Double? {
        (value(path) as? NSNumber)?.doubleValue
    }

    public func int(_ path: String) -> Int? {
        (value(path) as? NSNumber)?.intValue
    }

    public func bool(_ path: String) -> Bool? {
        value(path) as? Bool
    }

    public func stringArray(_ path: String) -> [String]? {
        value(path) as? [String]
    }

    public func color(_ path: String) -> ConfigColor? {
        guard let dict = dict(path) else { return nil }
        return ConfigColor(
            red: (dict["red"] as? NSNumber)?.doubleValue ?? 0,
            green: (dict["green"] as? NSNumber)?.doubleValue ?? 0,
            blue: (dict["blue"] as? NSNumber)?.doubleValue ?? 0,
            alpha: (dict["alpha"] as? NSNumber)?.doubleValue ?? 1
        )
    }

}

/// 色(各成分 0〜1)。描画層で NSColor / CGColor に変換する
public struct ConfigColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
