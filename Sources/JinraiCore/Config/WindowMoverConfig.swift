import Foundation

/// Window Mover の設定(元 window_mover_config.lua)。
/// エリア選択画面(Area Hints)の設定は AreaHintsConfig に分離している。
public struct WindowMoverConfig: Sendable {
    public struct HotkeyBinding: Equatable, Sendable {
        public var modifiers: [String]
        public var key: String
    }

    /// コマンド名 → ホットキー(未設定のコマンドは含まれない)
    public var commandHotkeys: [String: HotkeyBinding]
    public var cursorAfterMove: Bool
    public var horizontalRatios: [Double]
    public var verticalRatios: [Double]
    public var hiddenWindowThreshold: Double
}

public enum WindowMoverConfigBuilder {
    /// コマンド一覧(cycle 系 + 固定エリア直接移動 + 操作系)
    public static var commandNames: Set<String> {
        var names: Set<String> = [
            "moveToNextDisplay", "moveToActiveDisplayFreeArea",
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

    public static func build(_ options: [String: Any] = [:]) throws -> WindowMoverConfig {
        let merged = ConfigDict(options, context: "windowMover")

        // commands.<name>.hotkey の収集
        var commandHotkeys: [String: WindowMoverConfig.HotkeyBinding] = [:]
        if let commands = merged.dict("commands") {
            for (name, value) in commands {
                guard commandNames.contains(name) else {
                    throw ConfigError("[jinrai.windowMover] unknown command '\(name)'")
                }
                guard let command = value as? [String: Any],
                    let hotkey = command["hotkey"] as? [String: Any],
                    let key = hotkey["key"] as? String, !key.isEmpty
                else { continue }
                let modifiers = hotkey["modifiers"] as? [String] ?? []
                commandHotkeys[name] = .init(modifiers: modifiers, key: key)
            }
        }

        return WindowMoverConfig(
            commandHotkeys: commandHotkeys,
            cursorAfterMove: merged.bool("behavior.cursor.afterMove") ?? true,
            horizontalRatios: doubleArray(merged.value("behavior.cycle.horizontalRatios"))
                ?? CycleState.defaultRatios.map(Double.init),
            verticalRatios: doubleArray(merged.value("behavior.cycle.verticalRatios"))
                ?? CycleState.defaultRatios.map(Double.init),
            hiddenWindowThreshold: merged.double("behavior.freeArea.hiddenWindowThreshold")
                ?? 0.5
        )
    }

    static func doubleArray(_ value: Any?) -> [Double]? {
        (value as? [NSNumber])?.map(\.doubleValue)
    }
}
