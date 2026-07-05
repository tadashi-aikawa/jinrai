import Foundation

/// Application Hints(アプリランチャー)の設定(元 application_hints_config.lua)
public struct ApplicationHintsConfig: Sendable {
    public struct AppEntry: Sendable {
        /// 起動するアプリの bundle ID(apps[].bundleID)
        public var bundleID: String
        /// 選択キー(1-2文字、大文字化済み)
        public var key: String
        /// 表示名の上書き(nil ならアプリ名を自動解決)
        public var name: String?
        /// 新規ウィンドウ作成のホットキー(起動済みアプリに送出。デフォルト cmd+n)
        public var newWindowModifiers: [String]
        /// 新規ウィンドウ作成のキー(apps[].newWindow.hotkey.key)
        public var newWindowKey: String
        /// 宣言的な新規ウィンドウ URL(元 callback の代替。指定時は最優先で open)
        public var newWindowURL: String?
    }

    /// Application Hints を直接開くホットキーの修飾キー(hotkey.modifiers)
    public var hotkeyModifiers: [String]
    /// Application Hints を直接開くキー(hotkey.key。nil で無効)
    public var hotkeyKey: String?
    /// 新規ウィンドウが現れるまで待つ最大時間(秒。windowWaitTimeout)
    public var windowWaitTimeout: Double
    /// 対象アプリの一覧(apps。1件以上必須)
    public var apps: [AppEntry]

    /// 1行に表示するアプリ数(appearance.columns)
    public var columns: Int
    /// アプリ項目の幅(appearance.itemWidth)
    public var itemWidth: Double
    /// アプリ項目の高さ(appearance.itemHeight)
    public var itemHeight: Double
    /// アプリ項目同士の間隔(appearance.gap)
    public var gap: Double
    /// アプリアイコンの大きさ(appearance.iconSize)
    public var iconSize: Double
    /// アプリ項目背景の角丸(appearance.cornerRadius)
    public var cornerRadius: Double
    /// 通常時の背景色(appearance.bgColor)
    public var bgColor: ConfigColor
    /// 候補から外れた項目の背景色(appearance.dimmedBgColor)
    public var dimmedBgColor: ConfigColor
    /// 通常時の文字色(appearance.textColor)
    public var textColor: ConfigColor
    /// 候補から外れた項目の文字色(appearance.dimmedTextColor)
    public var dimmedTextColor: ConfigColor
    /// OPEN または NEW の状態表示色(appearance.stateColor)
    public var stateColor: ConfigColor
    /// 入力済みプレフィックス文字の色(Window Hints の hint.key.keyHighlightColor 相当)
    public var keyHighlightColor: ConfigColor

    /// Window Hints へ戻る遷移キー(init 相当の結線で注入)
    public var windowHintsKey: String?
    /// 表示中に JinraiMode を開始するキー(jinraiMode.triggers.applicationHints.key)
    public var jinraiModeKey: String?
}

public enum ApplicationHintsConfigBuilder {
    static var defaults: [String: Any] {
        [
            "windowWaitTimeout": 10,
            "appearance": [
                "itemWidth": 220,
                "itemHeight": 112,
                "gap": 12,
                "columns": 3,
                "iconSize": 64,
                "cornerRadius": 12,
                "bgColor": ["red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.80],
                "dimmedBgColor": ["red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.30],
                "textColor": ["red": 0.96, "green": 0.97, "blue": 1.00, "alpha": 1.00],
                "dimmedTextColor": ["red": 0.82, "green": 0.84, "blue": 0.88, "alpha": 0.30],
                "stateColor": ["red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 1.00],
                "keyHighlightColor": ["red": 0.84, "green": 0.84, "blue": 0.86, "alpha": 0.35],
            ],
        ]
    }

    /// 完全一致 or 一方が他方の接頭辞なら衝突(元 keysConflict)
    static func keysConflict(_ a: String, _ b: String) -> Bool {
        ConfigKeyDescriptor.sequence(a).conflicts(with: ConfigKeyDescriptor.sequence(b))
    }

    public static func build(
        _ options: [String: Any], windowHintsKey: String? = nil
    ) throws -> ApplicationHintsConfig {
        let merged = ConfigDict(
            DeepMerge.merge(defaults: defaults, overrides: options), context: "applicationHints")

        guard let rawApps = merged.value("apps") as? [[String: Any]], !rawApps.isEmpty else {
            throw ConfigError("[jinrai.applicationHints] apps は1件以上必要です")
        }

        var apps: [ApplicationHintsConfig.AppEntry] = []
        for (index, rawApp) in rawApps.enumerated() {
            guard let bundleID = rawApp["bundleID"] as? String, !bundleID.isEmpty else {
                throw ConfigError(
                    "[jinrai.applicationHints] apps[\(index)].bundleID は必須です")
            }
            guard let rawKey = rawApp["key"] as? String, !rawKey.isEmpty else {
                throw ConfigError("[jinrai.applicationHints] apps[\(index)].key は必須です")
            }
            let key = rawKey.uppercased()
            guard (1...2).contains(key.count) else {
                throw ConfigError(
                    "[jinrai.applicationHints] apps[\(index)].key は1〜2文字です: \(rawKey)")
            }

            var modifiers = ["cmd"]
            var newWindowKey = "n"
            var url: String?
            if let newWindow = rawApp["newWindow"] as? [String: Any] {
                url = newWindow["url"] as? String
                if let hotkey = newWindow["hotkey"] as? [String: Any] {
                    if let mods = hotkey["modifiers"] as? [String], !mods.isEmpty {
                        modifiers = mods
                    }
                    if let k = hotkey["key"] as? String, !k.isEmpty {
                        newWindowKey = k.lowercased()
                    }
                }
            }

            apps.append(
                .init(
                    bundleID: bundleID,
                    key: key,
                    name: rawApp["name"] as? String,
                    newWindowModifiers: modifiers,
                    newWindowKey: newWindowKey,
                    newWindowURL: url
                ))
        }

        // キー衝突検証: apps 間
        for i in apps.indices {
            for j in apps.indices where i < j {
                if keysConflict(apps[i].key, apps[j].key) {
                    throw ConfigError(
                        "[jinrai.applicationHints] キー '\(apps[i].key)' と '\(apps[j].key)' が衝突します"
                    )
                }
            }
        }
        // windowHintsKey との衝突
        if let windowHintsKey = windowHintsKey?.uppercased() {
            let windowHintsDescriptor = ConfigKeyDescriptor.keyName(windowHintsKey)
            for app in apps
            where ConfigKeyDescriptor.sequence(app.key).conflicts(with: windowHintsDescriptor) {
                throw ConfigError(
                    "[jinrai.applicationHints] キー '\(app.key)' が Window Hints 遷移キー '\(windowHintsKey)' と衝突します"
                )
            }
        }

        func positiveDouble(_ path: String, _ fallback: Double) throws -> Double {
            let value = merged.double(path) ?? fallback
            guard value > 0 else {
                throw ConfigError("[jinrai.applicationHints] \(path) は正の数が必要です")
            }
            return value
        }

        return ApplicationHintsConfig(
            hotkeyModifiers: merged.stringArray("hotkey.modifiers") ?? [],
            hotkeyKey: merged.string("hotkey.key"),
            windowWaitTimeout: try positiveDouble("windowWaitTimeout", 10),
            apps: apps,
            columns: max(1, merged.int("appearance.columns") ?? 3),
            itemWidth: try positiveDouble("appearance.itemWidth", 220),
            itemHeight: try positiveDouble("appearance.itemHeight", 112),
            gap: merged.double("appearance.gap") ?? 12,
            iconSize: try positiveDouble("appearance.iconSize", 64),
            cornerRadius: merged.double("appearance.cornerRadius") ?? 12,
            bgColor: merged.color("appearance.bgColor")
                ?? ConfigColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.80),
            dimmedBgColor: merged.color("appearance.dimmedBgColor")
                ?? ConfigColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.30),
            textColor: merged.color("appearance.textColor")
                ?? ConfigColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1.00),
            dimmedTextColor: merged.color("appearance.dimmedTextColor")
                ?? ConfigColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 0.30),
            stateColor: merged.color("appearance.stateColor")
                ?? ConfigColor(red: 0.40, green: 0.68, blue: 0.98, alpha: 1.00),
            keyHighlightColor: merged.color("appearance.keyHighlightColor")
                ?? ConfigColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 0.35),
            windowHintsKey: windowHintsKey?.uppercased(),
            jinraiModeKey: nil  // RootConfigBuilder が jinrai_mode.triggers から注入
        )
    }
}
