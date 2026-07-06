import Foundation

/// JinraiMode(連続配置モード)の設定(元 init.lua の DEFAULT_JINRAI_MODE)
public struct JinraiModeConfig: Sendable {
    public enum Easing: String, Sendable {
        case linear, easeOut, easeInOut
    }

    public struct Animation: Equatable, Sendable {
        /// 表示切り替え時にフェードするか
        public var fade: Bool
        /// 開始スケール(1.0 でスケールアニメなし)
        public var scale: Double
        /// アニメーション時間(秒。0 で即時表示)
        public var duration: Double
        /// アニメーションの補間方式(linear / easeOut / easeInOut)
        public var easing: Easing

        public static let `default` = Animation(
            fade: true, scale: 1.0, duration: 0.16, easing: .linear)
    }

    /// JinraiMode 中の JINRAI ロゴ表示(logo)
    public struct Logo: Equatable, Sendable {
        /// ロゴを表示するか(logo.enabled)
        public var enabled: Bool
        /// ロゴの大きさ(logo.size)
        public var size: Double
        /// ロゴの透明度(logo.alpha)
        public var alpha: Double
        /// 表示切り替えアニメーション(logo.animation)
        public var animation: Animation
    }

    /// コンボ表示要素(combo.character / combo.text)
    public struct ComboElement: Equatable, Sendable {
        /// この表示を有効にするか
        public var enabled: Bool
        /// 表示の透明度
        public var alpha: Double
        /// 表示切り替えアニメーション
        public var animation: Animation
    }

    /// 操作回数に応じたキャラクター画像の表示(combo.character)
    public struct ComboCharacter: Equatable, Sendable {
        /// この表示を有効にするか
        public var enabled: Bool
        /// 表示の透明度
        public var alpha: Double
        /// 表示切り替えアニメーション
        public var animation: Animation
        /// ユーザー指定のキャラクター画像パス配列(nil で同梱画像)
        public var images: [String]?
    }

    /// ロゴ・コンボの表示位置基準("activeWindow" = フォーカスウィンドウ中央)
    public var position: String
    /// Window Hints 表示中に JinraiMode を開始するキー(triggers.windowHints.key)
    public var windowHintsTriggerKey: String?
    /// Application Hints 表示中に JinraiMode を開始するキー(triggers.applicationHints.key)
    public var applicationHintsTriggerKey: String?
    /// Area Hints 表示中に JinraiMode を開始するキー(triggers.areaHints.key)
    public var areaHintsTriggerKey: String?
    /// JinraiMode 中のロゴ表示(logo)
    public var logo: Logo
    /// 操作回数に応じたキャラクター画像の表示(combo.character)
    public var comboCharacter: ComboCharacter
    /// 継続回数を示す COMBO テキストの表示(combo.text)
    public var comboText: ComboElement

    public static let `default` = JinraiModeConfig(
        position: "activeWindow",
        windowHintsTriggerKey: nil,
        applicationHintsTriggerKey: nil,
        areaHintsTriggerKey: nil,
        logo: Logo(enabled: true, size: 480, alpha: 0.25, animation: .default),
        comboCharacter: ComboCharacter(
            enabled: false, alpha: 0.7,
            animation: Animation(fade: true, scale: 1.18, duration: 0.16, easing: .linear),
            images: nil),
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
        if let imagesValue = merged.value("combo.character.images") {
            guard let images = imagesValue as? [String] else {
                throw ConfigError("[jinrai.jinraiMode] combo.character.images は文字列配列です")
            }
            guard !images.isEmpty else {
                throw ConfigError("[jinrai.jinraiMode] combo.character.images は1件以上必要です")
            }
            guard !images.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            else {
                throw ConfigError("[jinrai.jinraiMode] combo.character.images に空文字は指定できません")
            }
            config.comboCharacter.images = images
        }

        if let enabled = merged.bool("combo.text.enabled") {
            config.comboText.enabled = enabled
        }
        if let alpha = merged.double("combo.text.alpha") { config.comboText.alpha = alpha }
        config.comboText.animation = animation(
            "combo.text.animation", base: config.comboText.animation)

        return config
    }
}
