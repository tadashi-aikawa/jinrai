import Foundation

/// Focus Border の設定(元 focus_border_config.lua)
public struct FocusBorderConfig: Equatable, Sendable {
    /// フォーカス時にウィンドウ中央へ表示するロゴ(visual.logo)
    public struct Logo: Equatable, Sendable {
        /// ロゴ画像のパスまたは URL(nil で JINRAI 同梱ロゴ)
        public var source: String?
        /// ロゴの大きさ(visual.logo.size)
        public var size: Double
        /// ロゴの透明度(visual.logo.alpha)
        public var alpha: Double
    }

    /// メイン枠線の太さ(visual.border.width)
    public var borderWidth: Double
    /// メイン枠線の色(visual.border.color)
    public var borderColor: ConfigColor
    /// 外側の枠線の太さ(visual.outline.width)
    public var outlineWidth: Double
    /// 外側の枠線の色(visual.outline.color)
    public var outlineColor: ConfigColor
    /// フォーカス時に表示するロゴ(nil で非表示)
    public var logo: Logo?
    /// 枠線が消えるまでの時間(秒。animation.duration)
    public var duration: Double
    /// フェードアニメーションの分割数(animation.fadeSteps)
    public var fadeSteps: Int
    /// Space 切り替え後に表示を待つ時間(秒。animation.spaceSwitchDelay)
    public var spaceSwitchDelay: Double
    /// 枠線を表示する最小ウィンドウサイズ(window.minSize)
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
