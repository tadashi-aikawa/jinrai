import Foundation

/// Focus Back の設定(元 focus_back_config.lua)
public struct FocusBackConfig: Equatable, Sendable {
    /// Focus Back を実行するホットキーの修飾キー(hotkey.modifiers)
    public var hotkeyModifiers: [String]
    /// Focus Back を実行するキー(hotkey.key。nil で無効)
    public var hotkeyKey: String?
    /// jinrai://<名前> の URL から実行する場合の名前(urlEvent.name)
    public var urlEventName: String?
    /// 切り替え後にカーソルをウィンドウ中央へ移動するか(behavior.cursor.onSelect)
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
