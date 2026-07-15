import Foundation

/// config.jsonc 全体。各機能はセクションが存在するときだけ有効(元 setup(config) と同じ)。
public struct RootConfig {
    /// 直前にアクティブだったウィンドウへ戻る(セクション記述で有効)
    public var focusBack: FocusBackConfig?
    /// フォーカスしたウィンドウを枠線で強調(セクション記述で有効)
    public var focusBorder: FocusBorderConfig?
    /// キーヒントからウィンドウを選択(セクション記述で有効)
    public var windowHints: WindowHintsConfig?
    /// アクティブウィンドウをホットキーで移動・リサイズ(セクション記述で有効)
    public var windowMover: WindowMoverConfig?
    /// エリアとキーを表示してウィンドウの移動先を選択(セクション記述で有効)
    public var areaHints: AreaHintsConfig?
    /// 登録アプリの起動・新規ウィンドウ作成(セクション記述で有効。apps 必須)
    public var applicationHints: ApplicationHintsConfig?
    /// 定義済みレイアウトをホットキーで一括適用(セクション記述で有効。layouts 必須)
    public var windowLayouts: WindowLayoutsConfig?
    /// セクションなしでもデフォルト値を持つ(元 init.lua の normalizeJinraiMode)
    public var jinraiMode: JinraiModeConfig = .default

    public init(
        focusBack: FocusBackConfig? = nil,
        focusBorder: FocusBorderConfig? = nil,
        windowHints: WindowHintsConfig? = nil,
        windowMover: WindowMoverConfig? = nil,
        areaHints: AreaHintsConfig? = nil,
        applicationHints: ApplicationHintsConfig? = nil,
        windowLayouts: WindowLayoutsConfig? = nil
    ) {
        self.focusBack = focusBack
        self.focusBorder = focusBorder
        self.windowHints = windowHints
        self.windowMover = windowMover
        self.areaHints = areaHints
        self.applicationHints = applicationHints
        self.windowLayouts = windowLayouts
    }
}

public enum RootConfigBuilder {
    /// JSONC テキストから RootConfig を組み立てる。
    /// connectedDisplayUUIDs は profiles(接続ディスプレイ別オーバーライド)の判定に使う
    public static func build(text: String, connectedDisplayUUIDs: [String] = []) throws
        -> RootConfig
    {
        let root = try JSONC.parseObject(text)
        return try build(root, connectedDisplayUUIDs: connectedDisplayUUIDs)
    }

    public static func build(_ root: [String: Any], connectedDisplayUUIDs: [String] = [])
        throws -> RootConfig
    {
        let displayAliases = try DisplayAliasResolver.aliases(from: root)
        let rootWithResolvedProfileDisplays = try DisplayAliasResolver.resolveProfileDisplays(
            in: root, aliases: displayAliases)
        // profiles を先に解決し、以降の各セクション Builder はオーバーライド済みの
        // dict だけを見る(どのセクションでも一律にオーバーライド可能)
        let appliedRoot = try ProfilesResolver.apply(
            root: rootWithResolvedProfileDisplays, connectedDisplayUUIDs: connectedDisplayUUIDs)
        let root = try DisplayAliasResolver.resolveDisplayReferences(
            in: appliedRoot, aliases: displayAliases)
        var config = RootConfig()

        // macosNativeTabs セクションは廃止(タブ切替は Space 所属の有無で自動判別)。
        // 旧設定が残っていても読み込みは失敗させず無視する

        if let section = root["focusBack"] as? [String: Any] {
            config.focusBack = try FocusBackConfigBuilder.build(section)
        }
        if let section = root["focusBorder"] as? [String: Any] {
            config.focusBorder = try FocusBorderConfigBuilder.build(section)
        }
        if let section = root["windowHints"] as? [String: Any] {
            config.windowHints = try WindowHintsConfigBuilder.build(section)
        }
        if let section = root["windowMover"] as? [String: Any] {
            config.windowMover = try WindowMoverConfigBuilder.build(section)
        }
        if let section = root["areaHints"] as? [String: Any] {
            config.areaHints = try AreaHintsConfigBuilder.build(section)
        }
        if let section = root["applicationHints"] as? [String: Any] {
            // Window Hints からの遷移キー(navigation.applicationHints.key)を渡す
            let windowHintsSection = root["windowHints"] as? [String: Any]
            let appHintsKey =
                ((windowHintsSection?["navigation"] as? [String: Any])?["applicationHints"]
                    as? [String: Any])?["key"] as? String
            config.applicationHints = try ApplicationHintsConfigBuilder.build(
                section, windowHintsKey: appHintsKey)
        }

        if let section = root["windowLayouts"] as? [String: Any] {
            // Window Hints からの遷移キー(navigation.windowLayouts.key)を渡す
            let windowHintsSection = root["windowHints"] as? [String: Any]
            let windowLayoutsKey =
                ((windowHintsSection?["navigation"] as? [String: Any])?["windowLayouts"]
                    as? [String: Any])?["key"] as? String
            config.windowLayouts = try WindowLayoutsConfigBuilder.build(
                section, windowHintsKey: windowLayoutsKey)
        }

        if let section = root["jinraiMode"] as? [String: Any] {
            config.jinraiMode = try JinraiModeConfigBuilder.build(section)
        }
        // トリガキーを各機能の config へ配布(元 init.lua の internal.jinraiMode 注入)
        config.windowHints?.jinraiModeKey = config.jinraiMode.windowHintsTriggerKey
        config.areaHints?.jinraiModeKey = config.jinraiMode.areaHintsTriggerKey
        config.applicationHints?.jinraiModeKey = config.jinraiMode.applicationHintsTriggerKey
        if let areaHints = config.areaHints {
            try AreaHintsConfigBuilder.validateJinraiModeKey(
                config.jinraiMode.areaHintsTriggerKey, in: areaHints)
        }
        return config
    }
}
