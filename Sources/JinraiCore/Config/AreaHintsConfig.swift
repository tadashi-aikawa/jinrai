import Foundation

/// Area Hints(エリア選択画面)の設定(元 window_mover.selectedArea)。
/// Window Hints / Application Hints と同格の「ヒント選択UI」としてトップレベルに置く。
public struct AreaHintsConfig: Sendable {
    public struct HotkeyBinding: Equatable, Sendable {
        public var modifiers: [String]
        public var key: String
    }

    /// エリア選択画面を開くホットキー
    public var hotkey: HotkeyBinding?
    /// JinraiMode として開くホットキー
    public var jinraiModeHotkey: HotkeyBinding?

    /// ディスプレイUUID → { エリア名: 選択キー(1〜3文字) }
    public var screens: [String: [String: String]]
    /// screens に設定がないディスプレイで使うマップ
    public var defaultScreen: [String: String]?
    /// アクション名(closeWindow 等)→ キー
    public var actions: [String: String]
    /// Window Hints へ遷移するキー(navigation.windowHints.key)
    public var windowHintsKey: String?
    /// エリアと選択キーのラベルを画面上に表示するか(false でもキー入力は有効)
    public var showLabels: Bool

    public var activeWindowSpotlightAlpha: Double
    public var activeWindowHighlightColor: ConfigColor
    public var activeWindowHighlightWidth: Double
    public var activeWindowHighlightCornerRadius: Double

    /// エリア種類別の色
    public var styleColors: [String: ConfigColor]
    public var styleDimmedColors: [String: ConfigColor]
    /// ラベルボックスの状態別色(appearance.state)
    public var normalBgColor: ConfigColor
    public var normalTextColor: ConfigColor
    public var typedTextColor: ConfigColor
    public var dimmedBgColor: ConfigColor
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

        // screens: UUID → { エリア名: キー }
        var screens: [String: [String: String]] = [:]
        if let rawScreens = merged.dict("screens") {
            for (uuid, value) in rawScreens {
                guard let mapping = value as? [String: String] else {
                    throw ConfigError(
                        "[jinrai.areaHints] screens['\(uuid)'] must map area names to keys")
                }
                screens[uuid] = try validateAreaMapping(mapping, context: uuid)
            }
        }
        var defaultScreen: [String: String]?
        if let mapping = merged.dict("defaultScreen") as? [String: String] {
            defaultScreen = try validateAreaMapping(mapping, context: "defaultScreen")
        }

        var actions: [String: String] = [:]
        if let rawActions = merged.dict("actions") {
            for (name, value) in rawActions {
                guard actionNames.contains(name) else {
                    throw ConfigError("[jinrai.areaHints] unknown action '\(name)'")
                }
                if let key = value as? String, !key.isEmpty {
                    actions[name] = key.uppercased()
                }
            }
        }

        let windowHintsKey = merged.string("navigation.windowHints.key")?.uppercased()

        // キー衝突の検証(エリアキー + アクションキー + windowHints キー)
        for (uuid, mapping) in screens {
            var allKeys = Array(mapping.values.map { $0.uppercased() })
            allKeys.append(contentsOf: actions.values)
            if let windowHintsKey { allKeys.append(windowHintsKey) }
            try validateKeyConflicts(allKeys, context: "screens['\(uuid)']")
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
            result[areaName] = key.uppercased()
        }
        return result
    }

    /// 重複と接頭辞包含("K" と "KD" の共存)を禁止
    static func validateKeyConflicts(_ keys: [String], context: String) throws {
        for i in keys.indices {
            for j in keys.indices where i < j {
                let a = keys[i]
                let b = keys[j]
                if a == b {
                    throw ConfigError("[jinrai.areaHints] duplicate key '\(a)' in \(context)")
                }
                if a.hasPrefix(b) || b.hasPrefix(a) {
                    throw ConfigError(
                        "[jinrai.areaHints] key '\(a)' conflicts with '\(b)' (prefix) in \(context)"
                    )
                }
            }
        }
    }
}
