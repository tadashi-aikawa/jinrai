import Foundation

/// JinraiMode(連続配置モード)の設定(元 init.lua の DEFAULT_JINRAI_MODE)
public struct JinraiModeConfig: Sendable {
    public enum Easing: String, Sendable {
        case linear, easeOut, easeInOut
    }

    public struct Animation: Equatable, Sendable {
        public var fade: Bool
        /// 開始スケール(1.0 でスケールアニメなし)
        public var scale: Double
        public var duration: Double
        public var easing: Easing

        public static let `default` = Animation(
            fade: true, scale: 1.0, duration: 0.16, easing: .linear)
    }

    public struct Logo: Equatable, Sendable {
        public var enabled: Bool
        public var size: Double
        public var alpha: Double
        public var animation: Animation
    }

    public struct ComboElement: Equatable, Sendable {
        public var enabled: Bool
        public var alpha: Double
        public var animation: Animation
    }

    /// ロゴ・コンボの表示位置基準("activeWindow" = フォーカスウィンドウ中央)
    public var position: String
    /// 各機能の表示中に JinraiMode を開始するキー
    public var windowHintsTriggerKey: String?
    public var applicationHintsTriggerKey: String?
    public var areaHintsTriggerKey: String?
    public var logo: Logo
    public var comboCharacter: ComboElement
    public var comboText: ComboElement

    public static let `default` = JinraiModeConfig(
        position: "activeWindow",
        windowHintsTriggerKey: nil,
        applicationHintsTriggerKey: nil,
        areaHintsTriggerKey: nil,
        logo: Logo(enabled: true, size: 480, alpha: 0.25, animation: .default),
        comboCharacter: ComboElement(
            enabled: false, alpha: 0.7,
            animation: Animation(fade: true, scale: 1.18, duration: 0.16, easing: .linear)),
        comboText: ComboElement(enabled: false, alpha: 0.7, animation: .default)
    )
}

public enum JinraiModeConfigBuilder {
    public static func build(_ options: [String: Any] = [:]) throws -> JinraiModeConfig {
        let merged = ConfigDict(options, context: "jinraiMode")
        var config = JinraiModeConfig.default

        if let position = merged.string("position") {
            guard position == "activeWindow" || position == "activeDisplay" else {
                throw ConfigError(
                    "[jinrai.jinraiMode] position は activeWindow か activeDisplay です")
            }
            config.position = position
        }
        config.windowHintsTriggerKey =
            merged.string("triggers.windowHints.key")?.lowercased()
        config.applicationHintsTriggerKey =
            merged.string("triggers.applicationHints.key")?.lowercased()
        config.areaHintsTriggerKey =
            merged.string("triggers.areaHints.key")?.lowercased()

        func animation(_ path: String, base: JinraiModeConfig.Animation)
            -> JinraiModeConfig.Animation
        {
            var result = base
            if let fade = merged.bool("\(path).fade") { result.fade = fade }
            if let scale = merged.double("\(path).scale") { result.scale = scale }
            if let duration = merged.double("\(path).duration") { result.duration = duration }
            if let easing = merged.string("\(path).easing")
                .flatMap(JinraiModeConfig.Easing.init(rawValue:))
            {
                result.easing = easing
            }
            return result
        }

        if let enabled = merged.bool("logo.enabled") { config.logo.enabled = enabled }
        if let size = merged.double("logo.size") { config.logo.size = size }
        if let alpha = merged.double("logo.alpha") { config.logo.alpha = alpha }
        config.logo.animation = animation("logo.animation", base: config.logo.animation)

        if let enabled = merged.bool("combo.character.enabled") {
            config.comboCharacter.enabled = enabled
        }
        if let alpha = merged.double("combo.character.alpha") {
            config.comboCharacter.alpha = alpha
        }
        config.comboCharacter.animation = animation(
            "combo.character.animation", base: config.comboCharacter.animation)

        if let enabled = merged.bool("combo.text.enabled") {
            config.comboText.enabled = enabled
        }
        if let alpha = merged.double("combo.text.alpha") { config.comboText.alpha = alpha }
        config.comboText.animation = animation(
            "combo.text.animation", base: config.comboText.animation)

        return config
    }
}
