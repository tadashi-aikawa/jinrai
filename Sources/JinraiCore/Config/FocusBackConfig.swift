import Foundation

/// Focus Back の設定(元 focus_back_config.lua)
public struct FocusBackConfig: Equatable, Sendable {
    public var hotkeyModifiers: [String]
    public var hotkeyKey: String?
    public var urlEventName: String?
    public var centerCursor: Bool
}

public enum FocusBackConfigBuilder {
    static var defaults: [String: Any] { [
        "hotkey": [
            "modifiers": ["option"],
            "key": "w",
        ],
        "behavior": [
            "cursor": ["onSelect": true]
        ],
    ] }

    static let legacyFlatKeys: Set<String> = [
        "hotkeyModifiers", "hotkeyKey", "centerCursor", "focusHistory",
    ]

    public static func build(_ options: [String: Any] = [:]) throws -> FocusBackConfig {
        let raw = ConfigDict(options, context: "focus_back")
        try raw.rejectLegacyKeys(legacyFlatKeys)
        if raw.value("behavior.centerCursor") != nil {
            throw ConfigError(
                "[jinrai.focus_back] legacy nested key 'behavior.centerCursor' is no longer supported; use 'behavior.cursor.onSelect'"
            )
        }
        let merged = ConfigDict(
            DeepMerge.merge(defaults: defaults, overrides: options), context: "focus_back")
        return FocusBackConfig(
            hotkeyModifiers: merged.stringArray("hotkey.modifiers") ?? [],
            hotkeyKey: merged.string("hotkey.key"),
            urlEventName: merged.string("urlEvent.name"),
            centerCursor: merged.bool("behavior.cursor.onSelect") ?? true
        )
    }
}
