import Foundation

/// ヒントの表示状態(元 hint.state.normal/dimmed/occluded/active)
public enum HintState: String, CaseIterable, Sendable {
    case normal, dimmed, occluded, active
}

public struct HintStateStyle: Equatable, Sendable {
    public var bgColor: ConfigColor
    public var iconAlpha: Double
    public var keyColor: ConfigColor
    public var titleColor: ConfigColor
}

/// Window Hints の設定(元 window_hints_config.lua のフェーズ1サブセット)
public struct WindowHintsConfig: Sendable {
    public var hotkeyModifiers: [String]
    public var hotkeyKey: String?
    public var hintChars: [String]
    public var prefixOverrides: [HintKeyAssignment.PrefixOverride]

    public var padding: Double
    public var cornerRadius: Double
    public var occludedScale: Double
    public var iconSize: Double
    public var keyFontSize: Double
    public var keyMinWidth: Double
    /// 入力済みプレフィックス文字の色(元 hint.key.keyHighlightColor)
    public var keyHighlightColor: ConfigColor
    public var titleShow: Bool
    public var titleFontSize: Double
    public var titleMaxSize: Int
    public var states: [HintState: HintStateStyle]

    public var focusedHighlightColor: ConfigColor
    public var focusedHighlightWidth: Double

    /// ヒント箱の overlay(塗り+枠線)。状態・アクティブウィンドウで色が変わる
    public var overlayBorderWidth: Double
    public var overlayFillColor: ConfigColor  // 通常(青)
    public var overlayBorderColor: ConfigColor
    public var dimmedOverlayBorderColor: ConfigColor  // 入力で候補外(灰)
    public var activeOverlayFillColor: ConfigColor  // アクティブウィンドウ(橙)
    public var activeOverlayBorderColor: ConfigColor

    public var occlusionSampling: Occlusion.SamplingConfig
    /// 隠れウィンドウのプレビュー(要・画面収録権限)
    public var previewEnabled: Bool
    /// "background": ヒント全体の背景として表示 / "below": タイトル下に小さく表示
    public var previewMode: String
    public var previewWidth: Double
    public var previewPadding: Double
    public var previewAlpha: Double
    public var dockBottomMargin: Double
    public var dockItemGap: Double
    /// ドックアイテムをウィンドウの実位置へ寄せる度合い(0=中央整列, 1=ウィンドウ位置)
    public var dockWindowXBlend: Double
    public var dockWindowYBlend: Double

    public var navigationFocusBackKey: String?
    /// Window Mover のエリア選択画面へ遷移するキー
    public var windowMoverKey: String?
    /// Application Hints へ遷移するキー
    public var applicationHintsKey: String?
    public var directionHintKeys: [String: Direction]
    public var directionScoring: DirectionScoring.Config
    public var spacesNumbers: Bool
    public var prevSpaceKey: String?
    public var nextSpaceKey: String?

    public var cursorOnSelect: Bool
    public var cursorOnStart: Bool
    public var includeOtherSpaces: Bool
    public var includeActiveWindow: Bool
    public var swapModifiers: [String]?
}

public enum WindowHintsConfigBuilder {
    static var legacyFlatKeys: Set<String> {
        [
            "hotkeyModifiers", "hotkeyKey", "hintChars", "iconSize", "keyBoxSize",
            "keyBoxMinWidth", "keyBoxHorizontalPadding", "keyGap", "padding", "fontName",
            "fontSize", "titleFontSize", "rowGap", "titleMaxSize", "showTitles", "bgColor",
            "dimmedBgAlpha", "textColor", "dimmedTextColor", "titleTextColor",
            "dimmedTitleTextColor", "keyHighlightColor", "iconAlpha", "dimmedIconAlpha",
            "keyFontName", "titleFontName", "bumpMove", "showPreviewForOccluded",
            "previewMode", "appPrefixOverrides", "occlusionSamplingEnabled",
            "occlusionSamplingBaseWidth", "occlusionSamplingBaseHeight",
            "occlusionSamplingMinCols", "occlusionSamplingMinRows", "occlusionSamplingMaxCols",
            "occlusionSamplingMaxRows", "previewWidth", "previewPadding", "occludedScale",
            "occludedBgAlpha", "occludedIconAlpha", "occludedPreviewAlpha",
            "activeOverlayBorderColor", "activeOverlayBorderWidth", "hintOverlayColor",
            "hintOverlayBorderColor", "dimmedHintOverlayBorderColor",
        ]
    }

    public static func build(_ options: [String: Any] = [:]) throws -> WindowHintsConfig {
        let raw = ConfigDict(options, context: "window_hints")
        try raw.rejectLegacyKeys(legacyFlatKeys)
        let merged = ConfigDict(options, context: "window_hints")

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
                        "[jinrai.window_hints] hint.prefixOverrides[\(index)].match must be a table"
                    )
                }
                let bundleID = match["bundleID"] as? String
                let titleGlob = match["titleGlob"] as? String
                guard bundleID != nil || titleGlob != nil else {
                    throw ConfigError(
                        "[jinrai.window_hints] hint.prefixOverrides[\(index)].match requires bundleID or titleGlob"
                    )
                }
                guard let prefix = rule["prefix"] as? String, (1...2).contains(prefix.count)
                else {
                    throw ConfigError(
                        "[jinrai.window_hints] hint.prefixOverrides[\(index)].prefix must be 1 or 2 chars"
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
                        "[jinrai.window_hints] unknown direction '\(directionName)' in navigation.direction.hints.keys"
                    )
                }
                if let key = keyValue as? String, !key.isEmpty {
                    directionKeys[key.lowercased()] = direction
                }
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
            windowMoverKey: merged.string("navigation.windowMover.moveToSelectedArea.key")?
                .lowercased(),
            applicationHintsKey: merged.string("navigation.applicationHints.key")?.lowercased(),
            directionHintKeys: directionKeys,
            directionScoring: scoring,
            spacesNumbers: merged.bool("navigation.spaces.numbers") ?? true,
            prevSpaceKey: merged.string("navigation.spaces.prev.key")?.lowercased(),
            nextSpaceKey: merged.string("navigation.spaces.next.key")?.lowercased(),
            cursorOnSelect: merged.bool("behavior.cursor.onSelect") ?? true,
            cursorOnStart: merged.bool("behavior.cursor.onStart") ?? true,
            includeOtherSpaces: merged.bool("behavior.candidates.includeOtherSpaces") ?? true,
            includeActiveWindow: merged.bool("behavior.candidates.includeActiveWindow") ?? true,
            swapModifiers: swapModifiers
        )
    }
}
