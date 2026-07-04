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

/// config.jsonc 全体。各機能はセクションが存在するときだけ有効(元 setup(config) と同じ)。
public struct RootConfig {
    public var macosNativeTabs: MacosNativeTabsConfig
    public var focusBack: FocusBackConfig?
    public var focusBorder: FocusBorderConfig?
    public var windowHints: WindowHintsConfig?
    public var windowMover: WindowMoverConfig?
    public var applicationHints: ApplicationHintsConfig?
    /// セクションなしでもデフォルト値を持つ(元 init.lua の normalizeJinraiMode)
    public var jinraiMode: JinraiModeConfig = .default

    public init(
        macosNativeTabs: MacosNativeTabsConfig = .default,
        focusBack: FocusBackConfig? = nil,
        focusBorder: FocusBorderConfig? = nil,
        windowHints: WindowHintsConfig? = nil,
        windowMover: WindowMoverConfig? = nil,
        applicationHints: ApplicationHintsConfig? = nil
    ) {
        self.macosNativeTabs = macosNativeTabs
        self.focusBack = focusBack
        self.focusBorder = focusBorder
        self.windowHints = windowHints
        self.windowMover = windowMover
        self.applicationHints = applicationHints
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
        if let section = root["application_hints"] as? [String: Any] {
            // Window Hints からの遷移キー(navigation.applicationHints.key)を渡す
            let windowHintsSection = root["window_hints"] as? [String: Any]
            let appHintsKey =
                ((windowHintsSection?["navigation"] as? [String: Any])?["applicationHints"]
                    as? [String: Any])?["key"] as? String
            config.applicationHints = try ApplicationHintsConfigBuilder.build(
                section, windowHintsKey: appHintsKey)
        }

        if let section = root["jinrai_mode"] as? [String: Any] {
            config.jinraiMode = try JinraiModeConfigBuilder.build(section)
        }
        // トリガキーを各機能の config へ配布(元 init.lua の internal.jinraiMode 注入)
        config.windowHints?.jinraiModeKey = config.jinraiMode.windowHintsTriggerKey
        config.windowMover?.jinraiModeKey = config.jinraiMode.windowMoverTriggerKey
        config.applicationHints?.jinraiModeKey = config.jinraiMode.applicationHintsTriggerKey
        return config
    }
}
