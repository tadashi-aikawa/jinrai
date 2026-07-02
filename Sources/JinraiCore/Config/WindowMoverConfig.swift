import Foundation

/// Window Mover の設定(元 window_mover_config.lua)
public struct WindowMoverConfig: Sendable {
    public struct HotkeyBinding: Equatable, Sendable {
        public var modifiers: [String]
        public var key: String
    }

    /// エリア選択画面のディスプレイ別設定: エリア名 → 選択キー(1〜3文字)
    public struct SelectedArea: Sendable {
        public var defaultScreen: [String: String]?
        public var screens: [String: [String: String]]
        /// アクション名(closeWindow 等)→ キー
        public var actions: [String: String]
        public var windowHintsKey: String?
        public var showHints: Bool
        /// エリア種類別の色
        public var styleColors: [String: ConfigColor]
        public var styleDimmedColors: [String: ConfigColor]
    }

    /// コマンド名 → ホットキー(未設定のコマンドは含まれない)
    public var commandHotkeys: [String: HotkeyBinding]
    public var cursorAfterMove: Bool
    public var horizontalRatios: [Double]
    public var verticalRatios: [Double]
    public var hiddenWindowThreshold: Double
    public var selectedArea: SelectedArea
}

public enum WindowMoverConfigBuilder {
    /// コマンド一覧(cycle 系 + 固定エリア直接移動 + 操作系)
    public static var commandNames: Set<String> {
        var names: Set<String> = [
            "moveToNextDisplay", "moveToActiveDisplayFreeArea",
            "moveToSelectedArea", "moveToSelectedAreaInJinraiMode",
            "minimizeWindow", "maximizeWindow",
            "cycleLeft", "cycleHorizontalCenter", "cycleRight",
            "cycleTop", "cycleVerticalCenter", "cycleBottom",
        ]
        names.formUnion(directAreaCommands)
        return names
    }

    /// 固定エリア名 = そのままコマンド名(freeArea と full は除く)
    public static var directAreaCommands: [String] {
        [
            "halfLeft", "halfHorizontalCenter", "halfRight",
            "halfTop", "halfVerticalCenter", "halfBottom",
            "thirdLeft", "thirdHorizontalCenter", "thirdRight",
            "thirdTop", "thirdVerticalCenter", "thirdBottom",
            "quarterLeft", "quarterHorizontalLeftCenter", "quarterHorizontalRightCenter",
            "quarterRight", "quarterTop", "quarterVerticalTopCenter",
            "quarterVerticalBottomCenter", "quarterBottom",
            "quarterTopLeft", "quarterTopRight", "quarterBottomLeft", "quarterBottomRight",
            "sixthTopLeft", "sixthTopCenter", "sixthTopRight",
            "sixthBottomLeft", "sixthBottomCenter", "sixthBottomRight",
            "twoThirdsLeft", "twoThirdsHorizontalCenter", "twoThirdsRight",
            "twoThirdsTop", "twoThirdsVerticalCenter", "twoThirdsBottom", "twoThirdsCenter",
            "threeQuartersLeft", "threeQuartersHorizontalCenter", "threeQuartersRight",
            "threeQuartersTop", "threeQuartersVerticalCenter", "threeQuartersBottom",
            "threeQuartersCenter",
        ]
    }

    public static var actionNames: Set<String> {
        [
            "closeWindow", "minimizeWindow", "maximizeWindow",
            "quitApplication", "detachChromeTabToNewWindow",
        ]
    }

    public static func build(_ options: [String: Any] = [:]) throws -> WindowMoverConfig {
        let merged = ConfigDict(options, context: "window_mover")

        // commands.<name>.hotkey の収集
        var commandHotkeys: [String: WindowMoverConfig.HotkeyBinding] = [:]
        if let commands = merged.dict("commands") {
            for (name, value) in commands {
                guard commandNames.contains(name) else {
                    throw ConfigError("[jinrai.window_mover] unknown command '\(name)'")
                }
                guard let command = value as? [String: Any],
                    let hotkey = command["hotkey"] as? [String: Any],
                    let key = hotkey["key"] as? String, !key.isEmpty
                else { continue }
                let modifiers = hotkey["modifiers"] as? [String] ?? []
                commandHotkeys[name] = .init(modifiers: modifiers, key: key)
            }
        }

        // selectedArea.screens: UUID → { エリア名: キー }
        var screens: [String: [String: String]] = [:]
        if let rawScreens = merged.dict("selectedArea.screens") {
            for (uuid, value) in rawScreens {
                guard let mapping = value as? [String: String] else {
                    throw ConfigError(
                        "[jinrai.window_mover] selectedArea.screens['\(uuid)'] must map area names to keys"
                    )
                }
                screens[uuid] = try validateAreaMapping(mapping, context: uuid)
            }
        }
        var defaultScreen: [String: String]?
        if let mapping = merged.dict("selectedArea.defaultScreen") as? [String: String] {
            defaultScreen = try validateAreaMapping(mapping, context: "defaultScreen")
        }

        var actions: [String: String] = [:]
        if let rawActions = merged.dict("selectedArea.actions") {
            for (name, value) in rawActions {
                guard actionNames.contains(name) else {
                    throw ConfigError("[jinrai.window_mover] unknown action '\(name)'")
                }
                if let key = value as? String, !key.isEmpty {
                    actions[name] = key.uppercased()
                }
            }
        }

        let windowHintsKey = merged.string("selectedArea.windowHints.key")?.uppercased()

        // キー衝突の検証(エリアキー + アクションキー + windowHints キー)
        for (uuid, mapping) in screens {
            var allKeys = Array(mapping.values.map { $0.uppercased() })
            allKeys.append(contentsOf: actions.values)
            if let windowHintsKey { allKeys.append(windowHintsKey) }
            try validateKeyConflicts(allKeys, context: "selectedArea.screens['\(uuid)']")
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

        return WindowMoverConfig(
            commandHotkeys: commandHotkeys,
            cursorAfterMove: merged.bool("behavior.cursor.afterMove") ?? true,
            horizontalRatios: doubleArray(merged.value("behavior.cycle.horizontalRatios"))
                ?? CycleState.defaultRatios.map(Double.init),
            verticalRatios: doubleArray(merged.value("behavior.cycle.verticalRatios"))
                ?? CycleState.defaultRatios.map(Double.init),
            hiddenWindowThreshold: merged.double("behavior.freeArea.hiddenWindowThreshold")
                ?? 0.5,
            selectedArea: WindowMoverConfig.SelectedArea(
                defaultScreen: defaultScreen,
                screens: screens,
                actions: actions,
                windowHintsKey: windowHintsKey,
                showHints: merged.bool("selectedArea.hints.show") ?? true,
                styleColors: defaultStyles,
                styleDimmedColors: dimmedStyles
            )
        )
    }

    static func validateAreaMapping(
        _ mapping: [String: String], context: String
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        for (areaName, key) in mapping {
            guard AreaSpec.kind(of: areaName) != nil else {
                throw ConfigError(
                    "[jinrai.window_mover] unknown area '\(areaName)' in \(context)")
            }
            guard (1...3).contains(key.count) else {
                throw ConfigError(
                    "[jinrai.window_mover] key for '\(areaName)' must be 1-3 chars in \(context)"
                )
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
                    throw ConfigError(
                        "[jinrai.window_mover] duplicate key '\(a)' in \(context)")
                }
                if a.hasPrefix(b) || b.hasPrefix(a) {
                    throw ConfigError(
                        "[jinrai.window_mover] key '\(a)' conflicts with '\(b)' (prefix) in \(context)"
                    )
                }
            }
        }
    }

    static func doubleArray(_ value: Any?) -> [Double]? {
        (value as? [NSNumber])?.map(\.doubleValue)
    }
}
