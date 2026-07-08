import Foundation

/// Window Mover の設定(元 window_mover_config.lua)。
/// エリア選択画面(Area Hints)の設定は AreaHintsConfig に分離している。
public struct WindowMoverConfig: Sendable {
    public struct HotkeyBinding: Equatable, Sendable {
        /// ホットキーの修飾キー
        public var modifiers: [String]
        /// ホットキーのキー
        public var key: String
    }

    /// コマンド名 → ホットキー(未設定のコマンドは含まれない)
    public var commandHotkeys: [String: HotkeyBinding]
    /// 移動後にカーソルをウィンドウ中央へ移動するか(behavior.cursor.afterMove)。
    /// Area Hints 経由の移動にも適用される
    public var cursorAfterMove: Bool
    /// cycle 系コマンドで横幅を切り替える比率の順番(behavior.cycle.horizontalRatios)
    public var horizontalRatios: [Double]
    /// cycle 系コマンドで高さを切り替える比率の順番(behavior.cycle.verticalRatios)
    public var verticalRatios: [Double]
    /// 前面ウィンドウに隠れた背面ウィンドウを freeArea 計算から除外するしきい値
    /// (behavior.freeArea.hiddenWindowThreshold)。Area Hints の freeArea にも適用される
    public var hiddenWindowThreshold: Double
    /// 前面ウィンドウに隠れた背面ウィンドウを freeArea 計算から除外するか
    /// (behavior.freeArea.excludeHiddenWindows)。Area Hints の freeArea にも適用される
    public var excludeHiddenWindows: Bool
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
            "sixthLeft", "sixthRight",
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
                ?? 0.5,
            excludeHiddenWindows: merged.bool("behavior.freeArea.excludeHiddenWindows") ?? true
        )
    }

    static func doubleArray(_ value: Any?) -> [Double]? {
        (value as? [NSNumber])?.map(\.doubleValue)
    }
}
