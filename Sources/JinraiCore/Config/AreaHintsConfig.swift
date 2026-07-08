import Foundation

/// Area Hints(エリア選択画面)の設定(元 window_mover.selectedArea)。
/// Window Hints / Application Hints と同格の「ヒント選択UI」としてトップレベルに置く。
public struct AreaHintsConfig: Sendable {
    public struct HotkeyBinding: Equatable, Sendable {
        /// ホットキーの修飾キー
        public var modifiers: [String]
        /// ホットキーのキー
        public var key: String
    }

    /// エリアマップ({ エリア名: 選択キー })を接続中のディスプレイ数で切り替える。
    /// フラットに書いた場合はディスプレイ数によらず fallback が使われる。
    public struct AreaMappingVariants: Equatable, Sendable {
        /// ディスプレイ数 → エリアマップ
        public var byDisplayCount: [Int: [String: String]]
        /// 一致するディスプレイ数がないときのマップ(フラット形式 or "default")
        public var fallback: [String: String]?

        public init(
            byDisplayCount: [Int: [String: String]] = [:],
            fallback: [String: String]? = nil
        ) {
            self.byDisplayCount = byDisplayCount
            self.fallback = fallback
        }

        public func resolve(displayCount: Int) -> [String: String]? {
            byDisplayCount[displayCount] ?? fallback
        }
    }

    /// エリア選択画面を開くホットキー
    public var hotkey: HotkeyBinding?
    /// JinraiMode として開くホットキー
    public var jinraiModeHotkey: HotkeyBinding?

    /// ディスプレイUUID → エリアマップ(ディスプレイ数分岐可)
    public var screens: [String: AreaMappingVariants]
    /// screens に設定がないディスプレイで使うマップ(ディスプレイ数分岐可)
    public var defaultScreen: AreaMappingVariants?
    /// アクション名(closeWindow 等)→ キー
    public var actions: [String: String]
    /// Window Hints へ遷移するキー(navigation.windowHints.key)
    public var windowHintsKey: String?
    /// エリアと選択キーのラベルを画面上に表示するか(false でもキー入力は有効)
    public var showLabels: Bool

    /// アクティブウィンドウ以外を覆う暗幕の透明度(activeWindowSpotlight.alpha)
    public var activeWindowSpotlightAlpha: Double
    /// アクティブウィンドウを示す枠線色(activeWindowHighlight.borderColor)
    public var activeWindowHighlightColor: ConfigColor
    /// アクティブウィンドウを示す枠線の太さ(activeWindowHighlight.borderWidth)
    public var activeWindowHighlightWidth: Double
    /// アクティブウィンドウを示す枠線の角丸(activeWindowHighlight.cornerRadius)
    public var activeWindowHighlightCornerRadius: Double

    /// エリア種類別の色
    public var styleColors: [String: ConfigColor]
    public var styleDimmedColors: [String: ConfigColor]
    /// 通常時のラベル背景色(appearance.state.normal.bgColor)
    public var normalBgColor: ConfigColor
    /// 通常時の選択キー文字色(appearance.state.normal.textColor)
    public var normalTextColor: ConfigColor
    /// 入力済み部分を示す文字色(appearance.state.normal.typedTextColor)
    public var typedTextColor: ConfigColor
    /// 候補から外れたラベルの背景色(appearance.state.dimmed.bgColor)
    public var dimmedBgColor: ConfigColor
    /// 候補から外れた選択キーの文字色(appearance.state.dimmed.textColor)
    public var dimmedTextColor: ConfigColor

    /// 表示中に JinraiMode を開始するキー(jinraiMode.triggers.areaHints.key。RootConfigBuilder が注入)
    public var jinraiModeKey: String?
}

public enum AreaHintsConfigBuilder {
    public static var actionNames: Set<String> {
        [
            "closeWindow", "minimizeWindow", "maximizeWindow",
            "quitApplication", "detachChromeTabToNewWindow",
        ]
    }

    public static func build(_ options: [String: Any] = [:]) throws -> AreaHintsConfig {
        let merged = ConfigDict(options, context: "areaHints")

        // screens: UUID → エリアマップ(フラット or ディスプレイ数分岐)
        var screens: [String: AreaHintsConfig.AreaMappingVariants] = [:]
        if let rawScreens = merged.dict("screens") {
            for (uuid, value) in rawScreens {
                guard let raw = value as? [String: Any] else {
                    throw ConfigError(
                        "[jinrai.areaHints] screens['\(uuid)'] must map area names to keys")
                }
                screens[uuid] = try parseMappingVariants(raw, context: "screens['\(uuid)']")
            }
        }
        var defaultScreen: AreaHintsConfig.AreaMappingVariants?
        if let raw = merged.dict("defaultScreen") {
            defaultScreen = try parseMappingVariants(raw, context: "defaultScreen")
        }

        var actions: [String: String] = [:]
        if let rawActions = merged.dict("actions") {
            for (name, value) in rawActions {
                guard actionNames.contains(name) else {
                    throw ConfigError("[jinrai.areaHints] unknown action '\(name)'")
                }
                if let key = value as? String, !key.isEmpty {
                    actions[name] = key
                }
            }
        }

        let windowHintsKey = merged.string("navigation.windowHints.key")

        // キー衝突の検証(エリアキー + アクションキー + windowHints キー)。変種ごとに行う
        func validateVariantConflicts(
            _ variants: AreaHintsConfig.AreaMappingVariants, context: String
        ) throws {
            var mappings: [(String, [String: String])] = variants.byDisplayCount
                .map { ("\(context)[\($0.key)]", $0.value) }
            if let fallback = variants.fallback {
                let label = variants.byDisplayCount.isEmpty ? context : "\(context)[default]"
                mappings.append((label, fallback))
            }
            for (variantContext, mapping) in mappings {
                var allKeys = Array(mapping.values.map { ConfigKeyDescriptor.caseSensitiveSequence($0) })
                allKeys.append(contentsOf: actions.values.map { ConfigKeyDescriptor.caseSensitiveSequence($0) })
                if let windowHintsKey {
                    allKeys.append(ConfigKeyDescriptor.keyName(windowHintsKey))
                }
                try validateKeyConflicts(allKeys, context: variantContext)
            }
        }
        for (uuid, variants) in screens {
            try validateVariantConflicts(variants, context: "screens['\(uuid)']")
        }
        if let defaultScreen {
            try validateVariantConflicts(defaultScreen, context: "defaultScreen")
        }

        let defaultStyles: [String: ConfigColor] = [
            "full": ConfigColor(red: 0.36, green: 0.62, blue: 1.00, alpha: 0.92),
            "twoThirds": ConfigColor(red: 0.50, green: 0.82, blue: 0.42, alpha: 0.92),
            "threeQuarters": ConfigColor(red: 0.30, green: 0.76, blue: 0.86, alpha: 0.92),
            "half": ConfigColor(red: 0.62, green: 0.52, blue: 1.00, alpha: 0.92),
            "third": ConfigColor(red: 0.96, green: 0.66, blue: 0.28, alpha: 0.92),
            "quarter": ConfigColor(red: 0.92, green: 0.42, blue: 0.74, alpha: 0.92),
            "sixth": ConfigColor(red: 0.75, green: 0.15, blue: 0.25, alpha: 0.92),
            "free": ConfigColor(red: 0.58, green: 0.64, blue: 0.70, alpha: 0.95),
            "fixedSizeCenter": ConfigColor(red: 0.58, green: 0.64, blue: 0.70, alpha: 0.95),
        ]
        var dimmedStyles: [String: ConfigColor] = [:]
        for (kind, color) in defaultStyles {
            var dimmed = color
            dimmed.alpha = 0.22
            dimmedStyles[kind] = dimmed
        }

        func hotkeyBinding(_ path: String) -> AreaHintsConfig.HotkeyBinding? {
            guard let key = merged.string("\(path).key"), !key.isEmpty else { return nil }
            return .init(modifiers: merged.stringArray("\(path).modifiers") ?? [], key: key)
        }

        return AreaHintsConfig(
            hotkey: hotkeyBinding("hotkey"),
            jinraiModeHotkey: hotkeyBinding("jinraiMode.hotkey"),
            screens: screens,
            defaultScreen: defaultScreen,
            actions: actions,
            windowHintsKey: windowHintsKey,
            showLabels: merged.bool("labels.show") ?? true,
            activeWindowSpotlightAlpha: merged.double("activeWindowSpotlight.alpha") ?? 0.5,
            activeWindowHighlightColor: merged.color("activeWindowHighlight.borderColor")
                ?? ConfigColor(red: 0.95, green: 0.68, blue: 0.40, alpha: 0.95),
            activeWindowHighlightWidth: merged.double("activeWindowHighlight.borderWidth")
                ?? 13,
            activeWindowHighlightCornerRadius: merged.double(
                "activeWindowHighlight.cornerRadius") ?? 12,
            styleColors: defaultStyles,
            styleDimmedColors: dimmedStyles,
            normalBgColor: merged.color("appearance.state.normal.bgColor")
                ?? ConfigColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.88),
            normalTextColor: merged.color("appearance.state.normal.textColor")
                ?? ConfigColor(red: 0.96, green: 1.0, blue: 0.98, alpha: 1.0),
            typedTextColor: merged.color("appearance.state.normal.typedTextColor")
                ?? ConfigColor(red: 0.96, green: 1.0, blue: 0.98, alpha: 0.38),
            dimmedBgColor: merged.color("appearance.state.dimmed.bgColor")
                ?? ConfigColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.30),
            dimmedTextColor: merged.color("appearance.state.dimmed.textColor")
                ?? ConfigColor(red: 0.96, green: 1.0, blue: 0.98, alpha: 0.32),
            jinraiModeKey: nil  // RootConfigBuilder が jinraiMode.triggers から注入
        )
    }

    /// フラットなエリアマップ、またはディスプレイ数("1"〜 / "default")で分岐するマップをパースする。
    /// キーがすべて純数字か "default" なら分岐形式、1つもなければフラット形式、混在はエラー
    static func parseMappingVariants(
        _ raw: [String: Any], context: String
    ) throws -> AreaHintsConfig.AreaMappingVariants {
        func displayCount(of key: String) -> Int? {
            guard key.allSatisfy(\.isNumber), let count = Int(key) else { return nil }
            return count
        }
        let variantKeys = raw.keys.filter { displayCount(of: $0) != nil || $0 == "default" }
        if variantKeys.isEmpty {
            guard let mapping = raw as? [String: String] else {
                throw ConfigError("[jinrai.areaHints] \(context) must map area names to keys")
            }
            return .init(fallback: try validateAreaMapping(mapping, context: context))
        }
        guard variantKeys.count == raw.count else {
            throw ConfigError(
                "[jinrai.areaHints] \(context) must not mix display counts and area names")
        }

        var byDisplayCount: [Int: [String: String]] = [:]
        var fallback: [String: String]?
        for (key, value) in raw {
            guard let mapping = value as? [String: String] else {
                throw ConfigError(
                    "[jinrai.areaHints] \(context)['\(key)'] must map area names to keys")
            }
            let variantContext = "\(context)['\(key)']"
            if key == "default" {
                fallback = try validateAreaMapping(mapping, context: variantContext)
            } else {
                guard let count = displayCount(of: key), count >= 1 else {
                    throw ConfigError(
                        "[jinrai.areaHints] \(variantContext) display count must be 1 or more")
                }
                byDisplayCount[count] = try validateAreaMapping(
                    mapping, context: variantContext)
            }
        }
        return .init(byDisplayCount: byDisplayCount, fallback: fallback)
    }

    static func validateAreaMapping(
        _ mapping: [String: String], context: String
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        for (areaName, key) in mapping {
            guard AreaSpec.kind(of: areaName) != nil else {
                throw ConfigError("[jinrai.areaHints] unknown area '\(areaName)' in \(context)")
            }
            guard (1...3).contains(key.count) else {
                throw ConfigError(
                    "[jinrai.areaHints] key for '\(areaName)' must be 1-3 chars in \(context)")
            }
            result[areaName] = key
        }
        return result
    }

    /// 重複と接頭辞包含("K" と "KD" の共存)を禁止
    static func validateKeyConflicts(_ keys: [ConfigKeyDescriptor], context: String) throws {
        for i in keys.indices {
            for j in keys.indices where i < j {
                let a = keys[i]
                let b = keys[j]
                if a == b {
                    throw ConfigError("[jinrai.areaHints] duplicate key '\(a.display)' in \(context)")
                }
                if a.conflicts(with: b) {
                    throw ConfigError(
                        "[jinrai.areaHints] key '\(a.display)' conflicts with '\(b.display)' (prefix) in \(context)"
                    )
                }
            }
        }
    }
}
