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

    public static func build(_ options: [String: Any] = [:]) throws -> FocusBackConfig {
        let merged = ConfigDict(
            DeepMerge.merge(defaults: defaults, overrides: options), context: "focusBack")
        return FocusBackConfig(
            hotkeyModifiers: merged.stringArray("hotkey.modifiers") ?? [],
            hotkeyKey: merged.string("hotkey.key"),
            urlEventName: merged.string("urlEvent.name"),
            centerCursor: merged.bool("behavior.cursor.onSelect") ?? true
        )
    }
}
