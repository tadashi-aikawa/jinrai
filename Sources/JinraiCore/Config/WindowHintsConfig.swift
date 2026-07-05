import Foundation

/// ヒントの表示状態(元 hint.state.normal/dimmed/occluded/active)
public enum HintState: String, CaseIterable, Sendable {
    case normal, dimmed, occluded, active
}

public struct HintStateStyle: Equatable, Sendable {
    /// ヒントの背景色(hint.state.<state>.bgColor)
    public var bgColor: ConfigColor
    /// アプリアイコンの透明度(hint.icon.state.<state>.alpha)
    public var iconAlpha: Double
    /// キーの文字色(hint.key.state.<state>.color)
    public var keyColor: ConfigColor
    /// タイトルの文字色(hint.title.state.<state>.color)
    public var titleColor: ConfigColor
}

/// Window Hints の設定(元 window_hints_config.lua のフェーズ1サブセット)
public struct WindowHintsConfig: Sendable {
    /// Hints を開かずに直接方向フォーカス移動するホットキー(navigation.direction.direct)
    public struct DirectDirectionHotkeys: Equatable, Sendable {
        /// 直接方向移動の修飾キー(fn 不可)
        public var modifiers: [String]
        /// 方向 → キー名(方向ごとに1ホットキーを登録するため hints.keys とは向きが逆)
        public var keys: [Direction: String]
    }

    /// Window Hints を開くホットキーの修飾キー(hotkey.modifiers)
    public var hotkeyModifiers: [String]
    /// Window Hints を開くキー(hotkey.key。nil で無効)
    public var hotkeyKey: String?
    /// ヒントキーに使用する文字(hint.chars)
    public var hintChars: [String]
    /// アプリやタイトルごとのヒント先頭文字ルール(hint.prefixOverrides)
    public var prefixOverrides: [HintKeyAssignment.PrefixOverride]

    /// ヒント内側の余白(hint.padding)
    public var padding: Double
    /// ヒント背景の角丸(hint.cornerRadius)
    public var cornerRadius: Double
    /// 隠れたウィンドウのヒント倍率(hint.occludedScale)
    public var occludedScale: Double
    /// アプリアイコンの大きさ(hint.icon.size)
    public var iconSize: Double
    /// キー表示の文字サイズ(hint.key.fontSize)
    public var keyFontSize: Double
    /// キー表示部分の最小幅(hint.key.minWidth)
    public var keyMinWidth: Double
    /// 入力済みプレフィックス文字の色(元 hint.key.keyHighlightColor)
    public var keyHighlightColor: ConfigColor
    /// ウィンドウタイトルを表示するか(hint.title.show)
    public var titleShow: Bool
    /// タイトルの文字サイズ(hint.title.fontSize)
    public var titleFontSize: Double
    /// 表示するタイトルの最大文字数(hint.title.maxSize)
    public var titleMaxSize: Int
    /// 状態(normal/dimmed/occluded/active)ごとのスタイル
    public var states: [HintState: HintStateStyle]

    /// 現在のウィンドウを示す枠線色(focusedWindowHighlight.borderColor)
    public var focusedHighlightColor: ConfigColor
    /// 現在のウィンドウを示す枠線の太さ(focusedWindowHighlight.borderWidth)
    public var focusedHighlightWidth: Double
    /// 現在のウィンドウ以外を覆う暗幕の透明度(focusedWindowSpotlight.alpha)
    public var focusedSpotlightAlpha: Double

    /// ヒント箱の overlay(塗り+枠線)。状態・アクティブウィンドウで色が変わる
    public var overlayBorderWidth: Double
    public var overlayFillColor: ConfigColor  // 通常(青)
    public var overlayBorderColor: ConfigColor
    public var dimmedOverlayBorderColor: ConfigColor  // 入力で候補外(灰)
    public var activeOverlayFillColor: ConfigColor  // アクティブウィンドウ(橙)
    public var activeOverlayBorderColor: ConfigColor

    /// ウィンドウの隠れ具合を判定するサンプリング設定(occlusion.sampling)
    public var occlusionSampling: Occlusion.SamplingConfig
    /// 隠れウィンドウのプレビュー(要・画面収録権限)
    public var previewEnabled: Bool
    /// "background": ヒント全体の背景として表示 / "below": タイトル下に小さく表示
    public var previewMode: String
    /// プレビューの幅(occlusion.preview.width)
    public var previewWidth: Double
    /// ヒントとプレビューの間隔(occlusion.preview.padding)
    public var previewPadding: Double
    /// プレビューの透明度(occlusion.preview.alpha)
    public var previewAlpha: Double
    /// 画面下部に並べる候補の下余白(dock.bottomMargin)
    public var dockBottomMargin: Double
    /// 画面下部に並べる候補の間隔(dock.itemGap)
    public var dockItemGap: Double
    /// ドックアイテムをウィンドウの実位置へ寄せる度合い(0=中央整列, 1=ウィンドウ位置)
    public var dockWindowXBlend: Double
    public var dockWindowYBlend: Double

    /// 表示中に Focus Back を実行するキー(navigation.focusBack.key)
    public var navigationFocusBackKey: String?
    /// Area Hints(エリア選択画面)へ遷移するキー
    public var areaHintsKey: String?
    /// Application Hints へ遷移するキー
    public var applicationHintsKey: String?
    /// Application Hints へ遷移するとき JinraiMode を開始するか
    public var applicationHintsJinraiMode: Bool
    /// Hints 表示中に JinraiMode を開始するキー(jinraiMode.triggers.windowHints.key)
    public var jinraiModeKey: String?
    /// 表示中に方向で候補を選ぶキー → 方向(navigation.direction.hints.keys)
    public var directionHintKeys: [String: Direction]
    /// Hints 非表示時のグローバル方向移動ホットキー(nil で無効)
    public var directDirectionHotkeys: DirectDirectionHotkeys?
    /// 方向移動の候補評価の調整(navigation.direction.scoring)
    public var directionScoring: DirectionScoring.Config
    /// 数字キーで対応する Space へ移動するか(navigation.spaces.numbers)
    public var spacesNumbers: Bool
    /// 前の Space へ移動するキー(navigation.spaces.prev.key)
    public var prevSpaceKey: String?
    /// 次の Space へ移動するキー(navigation.spaces.next.key)
    public var nextSpaceKey: String?

    /// 選択後にカーソルを対象ウィンドウ中央へ移動するか(behavior.cursor.onSelect)
    public var cursorOnSelect: Bool
    /// 起動時にカーソルを現在のウィンドウ中央へ移動するか(behavior.cursor.onStart)
    public var cursorOnStart: Bool
    /// 別の Space にあるウィンドウを候補に含めるか(behavior.candidates.includeOtherSpaces)
    public var includeOtherSpaces: Bool
    /// 現在のウィンドウを候補に含めるか(behavior.candidates.includeActiveWindow)
    public var includeActiveWindow: Bool
    /// 押しながら選択すると移動元と移動先の位置・サイズを交換する修飾キー
    /// (behavior.selection.swapWindowFrame.modifiers)
    public var swapModifiers: [String]?
    /// ヒントを ease-in で立ち上げるフェード時間(秒。0 で即時表示)。
    /// 小面積なので短くして即応感を優先する
    public var showFadeInHints: Double
    /// spotlight(暗幕) + アクティブボーダーを ease-in で立ち上げるフェード時間(秒)。
    /// 画面全体の輝度が変わり明滅の刺激が強いため、ヒントより長めに取る。
    /// 高速な操作は低い不透明度のうちに完結するため暗転が目立たず、
    /// 迷った(時間をかけた)ぶんだけ暗幕が満ちてくる(0 で即時表示)
    public var showFadeInSpotlight: Double
}

public enum WindowHintsConfigBuilder {
    public static func build(_ options: [String: Any] = [:]) throws -> WindowHintsConfig {
        let merged = ConfigDict(options, context: "windowHints")

        // 状態別スタイル(occluded 等の未指定項目は normal を継承)
        func stateStyle(_ state: HintState) -> HintStateStyle {
            let base = HintStateStyle(
                bgColor: ConfigColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.80),
                iconAlpha: 0.95,
                keyColor: ConfigColor(red: 1, green: 1, blue: 1, alpha: 1),
                titleColor: ConfigColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1.00)
            )
            var style = base
            switch state {
            case .normal:
                break
            case .dimmed:
                style.bgColor.alpha = 0.14
                style.iconAlpha = 0.30
                style.keyColor = ConfigColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 0.28)
                style.titleColor.alpha = 0.30
            case .occluded:
                style.bgColor.alpha = 0.70
                style.iconAlpha = 0.46
            case .active:
                style.bgColor = ConfigColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.88)
                style.iconAlpha = 1.0
                style.keyColor = ConfigColor(red: 1.00, green: 0.93, blue: 0.86, alpha: 1.00)
                style.titleColor = ConfigColor(red: 0.99, green: 0.90, blue: 0.78, alpha: 1.00)
            }
            let prefix = "hint.state.\(state.rawValue)"
            if let bg = merged.color("\(prefix).bgColor") { style.bgColor = bg }
            if let alpha = merged.double("hint.icon.state.\(state.rawValue).alpha") {
                style.iconAlpha = alpha
            }
            if let key = merged.color("hint.key.state.\(state.rawValue).color") {
                style.keyColor = key
            }
            if let title = merged.color("hint.title.state.\(state.rawValue).color") {
                style.titleColor = title
            }
            return style
        }

        // prefixOverrides のバリデーションと変換
        var overrides: [HintKeyAssignment.PrefixOverride] = []
        if let rules = merged.value("hint.prefixOverrides") as? [[String: Any]] {
            for (index, rule) in rules.enumerated() {
                guard let match = rule["match"] as? [String: Any] else {
                    throw ConfigError(
                        "[jinrai.windowHints] hint.prefixOverrides[\(index)].match must be a table"
                    )
                }
                let bundleID = match["bundleID"] as? String
                let titleGlob = match["titleGlob"] as? String
                guard bundleID != nil || titleGlob != nil else {
                    throw ConfigError(
                        "[jinrai.windowHints] hint.prefixOverrides[\(index)].match requires bundleID or titleGlob"
                    )
                }
                guard let prefix = rule["prefix"] as? String, (1...2).contains(prefix.count)
                else {
                    throw ConfigError(
                        "[jinrai.windowHints] hint.prefixOverrides[\(index)].prefix must be 1 or 2 chars"
                    )
                }
                overrides.append(
                    .init(bundleID: bundleID, titleGlob: titleGlob, prefix: prefix))
            }
        }

        // 方向キー設定: navigation.direction.hints.keys = { left = "h", ... }
        var directionKeys: [String: Direction] = [:]
        if let keys = merged.dict("navigation.direction.hints.keys") {
            for (directionName, keyValue) in keys {
                guard let direction = Direction(rawValue: directionName) else {
                    throw ConfigError(
                        "[jinrai.windowHints] unknown direction '\(directionName)' in navigation.direction.hints.keys"
                    )
                }
                if let key = keyValue as? String, !key.isEmpty {
                    directionKeys[key.lowercased()] = direction
                }
            }
        }

        // 直接方向移動ホットキー: navigation.direction.direct = { modifiers, keys }
        // keys が空なら黙って無効。keys があるのに modifiers が空ならエラー(元 normalizeDirectDirectionHotkeys)
        var directHotkeys: WindowHintsConfig.DirectDirectionHotkeys?
        if merged.dict("navigation.direction.direct") != nil {
            var directKeys: [Direction: String] = [:]
            var usedDirectKeys: Set<String> = []
            if let rawKeys = merged.dict("navigation.direction.direct.keys") {
                for (directionName, keyValue) in rawKeys {
                    guard let direction = Direction(rawValue: directionName) else {
                        throw ConfigError(
                            "[jinrai.windowHints] unknown direction '\(directionName)' in navigation.direction.direct.keys"
                        )
                    }
                    if let key = keyValue as? String, !key.isEmpty {
                        let lowered = key.lowercased()
                        guard usedDirectKeys.insert(lowered).inserted else {
                            throw ConfigError(
                                "[jinrai.windowHints] duplicate key '\(lowered)' in navigation.direction.direct.keys"
                            )
                        }
                        directKeys[direction] = lowered
                    }
                }
            }
            if !directKeys.isEmpty {
                guard
                    let directModifiers = merged.stringArray(
                        "navigation.direction.direct.modifiers"),
                    !directModifiers.isEmpty
                else {
                    throw ConfigError(
                        "[jinrai.windowHints] navigation.direction.direct.modifiers is required when keys are set"
                    )
                }
                // Carbon RegisterEventHotKey は fn 修飾非対応(黙って無視され fn なしで登録されるため明示エラー)
                let allowedModifiers: Set<String> = [
                    "cmd", "command", "alt", "option", "ctrl", "control", "shift",
                ]
                for modifier in directModifiers
                where !allowedModifiers.contains(modifier.lowercased()) {
                    throw ConfigError(
                        "[jinrai.windowHints] unsupported modifier '\(modifier)' in navigation.direction.direct.modifiers (use cmd/alt/ctrl/shift)"
                    )
                }
                directHotkeys = .init(modifiers: directModifiers, keys: directKeys)
            }
        }

        let sampling = Occlusion.SamplingConfig(
            enabled: merged.bool("occlusion.sampling.enabled") ?? true,
            baseWidth: merged.double("occlusion.sampling.baseWidth") ?? 1920,
            baseHeight: merged.double("occlusion.sampling.baseHeight") ?? 1080,
            minCols: merged.int("occlusion.sampling.minCols") ?? 4,
            minRows: merged.int("occlusion.sampling.minRows") ?? 4,
            maxCols: merged.int("occlusion.sampling.maxCols") ?? 8,
            maxRows: merged.int("occlusion.sampling.maxRows") ?? 8
        )

        let scoring = DirectionScoring.Config(
            cardinalOverlapTieThresholdPx: CGFloat(
                merged.double("navigation.direction.scoring.cardinalOverlapTieThresholdPx") ?? 720),
            maxPrimaryOverlapRatioForDetached: CGFloat(
                merged.double("navigation.direction.scoring.maxPrimaryOverlapRatioForDetached")
                    ?? 0.2),
            minOrthogonalOverlapRatio: CGFloat(
                merged.double("navigation.direction.scoring.minOrthogonalOverlapRatio") ?? 0.5),
            preferredVisibleRatio: merged.double(
                "navigation.direction.scoring.preferredVisibleRatio") ?? 0.4,
            sampling: sampling
        )

        var swapModifiers: [String]?
        if let modifiers = merged.stringArray("behavior.selection.swapWindowFrame.modifiers"),
            !modifiers.isEmpty
        {
            swapModifiers = modifiers
        }

        return WindowHintsConfig(
            hotkeyModifiers: merged.stringArray("hotkey.modifiers") ?? ["alt"],
            hotkeyKey: merged.string("hotkey.key") ?? "f20",
            hintChars: merged.stringArray("hint.chars") ?? HintKeyAssignment.defaultHintChars,
            prefixOverrides: overrides,
            padding: merged.double("hint.padding") ?? 12,
            cornerRadius: merged.double("hint.cornerRadius") ?? 12,
            occludedScale: merged.double("hint.occludedScale") ?? 0.85,
            iconSize: merged.double("hint.icon.size") ?? 72,
            keyFontSize: merged.double("hint.key.fontSize") ?? 48,
            keyMinWidth: merged.double("hint.key.minWidth") ?? 72,
            keyHighlightColor: merged.color("hint.key.keyHighlightColor")
                ?? ConfigColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 0.35),
            titleShow: merged.bool("hint.title.show") ?? true,
            titleFontSize: merged.double("hint.title.fontSize") ?? 16,
            titleMaxSize: merged.int("hint.title.maxSize") ?? 72,
            states: Dictionary(
                uniqueKeysWithValues: HintState.allCases.map { ($0, stateStyle($0)) }),
            focusedHighlightColor: merged.color("focusedWindowHighlight.borderColor")
                ?? ConfigColor(red: 0.95, green: 0.68, blue: 0.40, alpha: 0.95),
            focusedHighlightWidth: merged.double("focusedWindowHighlight.borderWidth") ?? 13,
            focusedSpotlightAlpha: merged.double("focusedWindowSpotlight.alpha") ?? 0.5,
            overlayBorderWidth: merged.double("hint.highlight.borderWidth") ?? 6,
            overlayFillColor: merged.color("hint.state.normal.highlight.fillColor")
                ?? ConfigColor(red: 0.40, green: 0.68, blue: 0.98, alpha: 0.56),
            overlayBorderColor: merged.color("hint.state.normal.highlight.borderColor")
                ?? ConfigColor(red: 0.40, green: 0.68, blue: 0.98, alpha: 0.85),
            dimmedOverlayBorderColor: merged.color("hint.state.dimmed.highlight.borderColor")
                ?? ConfigColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 0.30),
            activeOverlayFillColor: merged.color("hint.state.active.highlight.fillColor")
                ?? ConfigColor(red: 0.95, green: 0.68, blue: 0.40, alpha: 0.56),
            activeOverlayBorderColor: merged.color("hint.state.active.highlight.borderColor")
                ?? ConfigColor(red: 0.95, green: 0.68, blue: 0.40, alpha: 0.95),
            occlusionSampling: sampling,
            previewEnabled: merged.bool("occlusion.preview.enabled") ?? true,
            previewMode: merged.string("occlusion.preview.mode") ?? "background",
            previewWidth: merged.double("occlusion.preview.width") ?? 140,
            previewPadding: merged.double("occlusion.preview.padding") ?? 6,
            previewAlpha: merged.double("occlusion.preview.alpha") ?? 0.64,
            dockBottomMargin: merged.double("dock.bottomMargin") ?? 96,
            dockItemGap: merged.double("dock.itemGap") ?? 12,
            dockWindowXBlend: merged.double("dock.windowBlend.x") ?? 0.65,
            dockWindowYBlend: merged.double("dock.windowBlend.y") ?? 1,
            navigationFocusBackKey: merged.string("navigation.focusBack.key")?.lowercased(),
            areaHintsKey: merged.string("navigation.areaHints.key")?.lowercased(),
            applicationHintsKey: merged.string("navigation.applicationHints.key")?.lowercased(),
            applicationHintsJinraiMode: merged.bool("navigation.applicationHints.jinraiMode")
                ?? false,
            jinraiModeKey: nil,  // RootConfigBuilder が jinraiMode.triggers から注入
            directionHintKeys: directionKeys,
            directDirectionHotkeys: directHotkeys,
            directionScoring: scoring,
            spacesNumbers: merged.bool("navigation.spaces.numbers") ?? true,
            prevSpaceKey: merged.string("navigation.spaces.prev.key")?.lowercased(),
            nextSpaceKey: merged.string("navigation.spaces.next.key")?.lowercased(),
            cursorOnSelect: merged.bool("behavior.cursor.onSelect") ?? true,
            cursorOnStart: merged.bool("behavior.cursor.onStart") ?? true,
            includeOtherSpaces: merged.bool("behavior.candidates.includeOtherSpaces") ?? true,
            includeActiveWindow: merged.bool("behavior.candidates.includeActiveWindow") ?? true,
            swapModifiers: swapModifiers,
            showFadeInHints: merged.double("behavior.showFadeIn.hints") ?? 0.05,
            showFadeInSpotlight: merged.double("behavior.showFadeIn.spotlight") ?? 0.4
        )
    }
}
