import Foundation

/// macOS ネイティブタブ利用アプリの設定(元 init.lua の macosNativeTabs 正規化)
public struct MacosNativeTabsConfig: Equatable, Sendable {
    public var apps: [String]
    public var stateSyncInterval: Double

    public static let `default` = MacosNativeTabsConfig(
        apps: ["com.mitchellh.ghostty", "com.apple.finder"],
        stateSyncInterval: 0.5
    )
}

/// config.json 全体。各機能はセクションが存在するときだけ有効(元 setup(config) と同じ)。
public struct RootConfig {
    public var macosNativeTabs: MacosNativeTabsConfig
    public var focusBack: FocusBackConfig?
    public var focusBorder: FocusBorderConfig?
    public var windowHints: WindowHintsConfig?
    public var windowMover: WindowMoverConfig?

    public init(
        macosNativeTabs: MacosNativeTabsConfig = .default,
        focusBack: FocusBackConfig? = nil,
        focusBorder: FocusBorderConfig? = nil,
        windowHints: WindowHintsConfig? = nil,
        windowMover: WindowMoverConfig? = nil
    ) {
        self.macosNativeTabs = macosNativeTabs
        self.focusBack = focusBack
        self.focusBorder = focusBorder
        self.windowHints = windowHints
        self.windowMover = windowMover
    }
}

public enum RootConfigBuilder {
    /// JSONC テキストから RootConfig を組み立てる
    public static func build(text: String) throws -> RootConfig {
        let root = try JSONC.parseObject(text)
        return try build(root)
    }

    public static func build(_ root: [String: Any]) throws -> RootConfig {
        var config = RootConfig()

        if let tabs = root["macos_native_tabs"] as? [String: Any] {
            var normalized = MacosNativeTabsConfig.default
            if let apps = tabs["apps"] as? [String] {
                // デフォルトのアプリ一覧にユーザー指定を追記(元 mergeAppList)
                for app in apps where !normalized.apps.contains(app) {
                    normalized.apps.append(app)
                }
            }
            if let interval = (tabs["stateSyncInterval"] as? NSNumber)?.doubleValue {
                normalized.stateSyncInterval = interval
            }
            config.macosNativeTabs = normalized
        }

        if let section = root["focus_back"] as? [String: Any] {
            config.focusBack = try FocusBackConfigBuilder.build(section)
        }
        if let section = root["focus_border"] as? [String: Any] {
            config.focusBorder = try FocusBorderConfigBuilder.build(section)
        }
        if let section = root["window_hints"] as? [String: Any] {
            config.windowHints = try WindowHintsConfigBuilder.build(section)
        }
        if let section = root["window_mover"] as? [String: Any] {
            config.windowMover = try WindowMoverConfigBuilder.build(section)
        }
        return config
    }
}
