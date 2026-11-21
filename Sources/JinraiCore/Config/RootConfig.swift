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
    /// ミラーリングと拡張表示をホットキーで切り替え(セクション記述で有効)
    public var displayMirroring: DisplayMirroringConfig?
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

        // enabled: false のセクションは、セクションが無いときと同じ扱いにする。
        // 中身の検査はする(スイッチを戻したときに壊れていないことを保証するため)。
        // profiles 適用後の root を見るので、ディスプレイ構成ごとに切り替えられる
        if let section = root["focusBack"] as? [String: Any] {
            let built = try FocusBackConfigBuilder.build(section)
            if try isEnabled(section, "focusBack") { config.focusBack = built }
        }
        if let section = root["focusBorder"] as? [String: Any] {
            let built = try FocusBorderConfigBuilder.build(section)
            if try isEnabled(section, "focusBorder") { config.focusBorder = built }
        }
        let windowHintsSection = root["windowHints"] as? [String: Any]
        if let section = windowHintsSection {
            let built = try WindowHintsConfigBuilder.build(section)
            if try isEnabled(section, "windowHints") { config.windowHints = built }
        }
        let areaHintsSection = root["areaHints"] as? [String: Any]
        let areaHintsDisabled = try areaHintsSection.map { try !isEnabled($0, "areaHints") } ?? false
        if let section = root["windowMover"] as? [String: Any] {
            let built = try WindowMoverConfigBuilder.build(section)
            if try isEnabled(section, "windowMover") { config.windowMover = built }
        }
        // 無効でも組んだ結果は残し、JINRAI Mode のトリガとの衝突の検査に使う
        var builtAreaHints: AreaHintsConfig?
        if let section = areaHintsSection {
            let built = try AreaHintsConfigBuilder.build(section)
            builtAreaHints = built
            if !areaHintsDisabled { config.areaHints = built }
        }

        // Window Hints からの遷移キー。
        // キーの衝突は、書かれたキーを Window Hints の有効・無効によらず検査する(戻したときに壊れないため)。
        // レイアウトに届くかの判定には、有効な Window Hints の遷移だけを数える
        let windowHintsEnabled = config.windowHints != nil
        func windowHintsNavigationKey(_ name: String) -> String? {
            ((windowHintsSection?["navigation"] as? [String: Any])?[name]
                as? [String: Any])?["key"] as? String
        }
        if let section = root["applicationHints"] as? [String: Any] {
            let enabled = try isEnabled(section, "applicationHints")
            let built = try ApplicationHintsConfigBuilder.build(
                section, windowHintsKey: windowHintsNavigationKey("applicationHints"),
                requireApps: enabled)
            if enabled { config.applicationHints = built }
        }
        if let section = root["windowLayouts"] as? [String: Any] {
            let enabled = try isEnabled(section, "windowLayouts")
            let built = try WindowLayoutsConfigBuilder.build(
                section,
                windowHintsKey: windowHintsEnabled ? windowHintsNavigationKey("windowLayouts") : nil,
                requireReachable: enabled)
            if enabled { config.windowLayouts = built }
        }

        if let section = root["displayMirroring"] as? [String: Any] {
            let built = try DisplayMirroringConfigBuilder.build(section)
            if try isEnabled(section, "displayMirroring") { config.displayMirroring = built }
        }


        if let section = root["jinraiMode"] as? [String: Any] {
            config.jinraiMode = try JinraiModeConfigBuilder.build(section)
        }
        // トリガキーを各機能の config へ配布(元 init.lua の internal.jinraiMode 注入)
        config.windowHints?.jinraiModeKey = config.jinraiMode.windowHintsTriggerKey
        config.areaHints?.jinraiModeKey = config.jinraiMode.areaHintsTriggerKey
        config.applicationHints?.jinraiModeKey = config.jinraiMode.applicationHintsTriggerKey
        if let areaHints = config.areaHints ?? builtAreaHints {
            try AreaHintsConfigBuilder.validateJinraiModeKey(
                config.jinraiMode.areaHintsTriggerKey, in: areaHints)
        }

        // 遷移先が無い(無効・未設定)遷移キーは閉じる。押しても Hints を閉じず、ヒントの文字にも使える。
        // キーの衝突の検査は上で済ませてから閉じる(書かれたキーの誤りは遷移先の有無によらず知らせる)。
        // Area Hints はセクションが無くても Window Mover があれば既定の設定で開ける(従来どおり)。
        // 明示的に enabled: false にしたときだけ閉じる
        if config.applicationHints == nil { config.windowHints?.applicationHintsKey = nil }
        if config.windowLayouts == nil { config.windowHints?.windowLayoutsKey = nil }
        if areaHintsDisabled || (config.areaHints == nil && config.windowMover == nil) {
            config.windowHints?.areaHintsKey = nil
        }
        if config.windowHints == nil {
            config.areaHints?.windowHintsKey = nil
            config.applicationHints?.windowHintsKey = nil
        }
        if config.focusBack == nil { config.windowHints?.navigationFocusBackKey = nil }
        // JINRAI Mode は Area Hints を挟んで続く操作なので、Area Hints を明示的に止めたら入口も閉じる
        // (閉じないと、Window Mover が補う既定の Area Hints が JINRAI Mode から開いてしまう)
        if areaHintsDisabled {
            config.windowHints?.jinraiModeKey = nil
            config.windowHints?.applicationHintsJinraiMode = false
            config.windowHints?.windowLayoutsJinraiMode = false
            config.applicationHints?.jinraiModeKey = nil
        }
        return config
    }

    /// 機能のセクションの enabled(省略時は true)
    static func isEnabled(_ section: [String: Any], _ name: String) throws -> Bool {
        guard let value = section["enabled"] else { return true }
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID()
        else {
            throw ConfigError("[jinrai.\(name)] enabled は true か false で指定します")
        }
        return number.boolValue
    }
}
