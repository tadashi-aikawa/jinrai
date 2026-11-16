import Foundation

/// Display Mirroring の設定
public struct DisplayMirroringConfig: Equatable, Sendable {
    /// ミラーリングと拡張表示を切り替えるホットキーの修飾キー(hotkey.modifiers)
    public var hotkeyModifiers: [String]
    /// ミラーリングと拡張表示を切り替えるキー(hotkey.key。nil で無効)
    public var hotkeyKey: String?
    /// jinrai://<名前> の URL から実行する場合の名前(urlEvent.name)
    public var urlEventName: String?
}

public enum DisplayMirroringConfigBuilder {
    public static func build(_ options: [String: Any] = [:]) throws -> DisplayMirroringConfig {
        let merged = ConfigDict(options, context: "displayMirroring")
        return DisplayMirroringConfig(
            hotkeyModifiers: merged.stringArray("hotkey.modifiers") ?? [],
            hotkeyKey: merged.string("hotkey.key"),
            urlEventName: merged.string("urlEvent.name")
        )
    }
}
