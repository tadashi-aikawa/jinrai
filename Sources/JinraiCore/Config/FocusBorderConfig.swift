import Foundation

/// Focus Border の設定(元 focus_border_config.lua)
public struct FocusBorderConfig: Equatable, Sendable {
    public struct Logo: Equatable, Sendable {
        public var source: String?
        public var size: Double
        public var alpha: Double
    }

    public var borderWidth: Double
    public var borderColor: ConfigColor
    public var outlineWidth: Double
    public var outlineColor: ConfigColor
    public var logo: Logo?
    public var duration: Double
    public var fadeSteps: Int
    public var spaceSwitchDelay: Double
    public var minWindowSize: Double
}

public enum FocusBorderConfigBuilder {
    static var defaults: [String: Any] { [
        "visual": [
            "border": [
                "width": 10,
                "color": ["red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.95],
            ],
            "outline": [
                "width": 2,
                "color": ["red": 0, "green": 0, "blue": 0, "alpha": 0.70],
            ],
        ],
        "animation": [
            "duration": 0.5,
            "fadeSteps": 18,
            "spaceSwitchDelay": 0.30,
        ],
        "window": [
            "minSize": 480
        ],
    ] }

    public static func build(_ options: [String: Any] = [:]) throws -> FocusBorderConfig {
        let merged = ConfigDict(
            DeepMerge.merge(defaults: defaults, overrides: options), context: "focusBorder")

        var logo: FocusBorderConfig.Logo?
        if merged.dict("visual.logo") != nil {
            logo = FocusBorderConfig.Logo(
                source: merged.string("visual.logo.source"),
                size: merged.double("visual.logo.size") ?? 480,
                alpha: merged.double("visual.logo.alpha") ?? 0.95
            )
        }

        return FocusBorderConfig(
            borderWidth: merged.double("visual.border.width") ?? 10,
            borderColor: merged.color("visual.border.color")
                ?? ConfigColor(red: 0.40, green: 0.68, blue: 0.98, alpha: 0.95),
            outlineWidth: merged.double("visual.outline.width") ?? 2,
            outlineColor: merged.color("visual.outline.color")
                ?? ConfigColor(red: 0, green: 0, blue: 0, alpha: 0.70),
            logo: logo,
            duration: merged.double("animation.duration") ?? 0.5,
            fadeSteps: merged.int("animation.fadeSteps") ?? 18,
            spaceSwitchDelay: merged.double("animation.spaceSwitchDelay") ?? 0.30,
            minWindowSize: merged.double("window.minSize") ?? 480
        )
    }
}
