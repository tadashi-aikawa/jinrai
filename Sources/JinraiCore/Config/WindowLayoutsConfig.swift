import Foundation

/// Window Layouts(定義済みレイアウトをホットキーで一括適用)の設定
public struct WindowLayoutsConfig: Sendable {
    public struct HotkeyBinding: Equatable, Sendable {
        /// ホットキーの修飾キー
        public var modifiers: [String]
        /// ホットキーのキー
        public var key: String
    }

    /// 配置対象ウィンドウ1件の定義(layouts.<名前>.windows[])
    public struct WindowEntry: Equatable, Sendable {
        /// 対象アプリの bundle ID(完全一致・必須)
        public var bundleID: String
        /// ウィンドウタイトルの glob(`*` と `?`。省略時はタイトルを問わない)
        public var titleGlob: String?
        /// 配置先ディスプレイの UUID(省略・未接続時はメインディスプレイ)
        public var screenUUID: String?
        /// 配置先エリア名(AreaSpec の名前。freeArea は不可)
        public var area: String
        /// ウィンドウが1枚も存在しなければ起動(reopen)してウィンドウ出現を待つか(デフォルト false = スキップ)
        public var launch: Bool
        /// レイアウト適用後にこのエントリのウィンドウへフォーカスするか(デフォルト false)
        public var focus: Bool
    }

    /// 配置対象に選ばれなかったオンスクリーン標準ウィンドウの扱い(layouts.<名前>.unlistedWindows)
    public enum UnlistedWindowsAction: Equatable, Sendable {
        /// 閉じる("close")
        case close
        /// 指定の screen + area へ一律配置する({ screen?, area })
        case place(screenUUID: String?, area: String)
    }

    /// 1つのレイアウト定義(layouts.<名前>)
    public struct Layout: Sendable {
        /// レイアウト名(layouts のキー。ピッカー表示・検索・ログ用)
        public var name: String
        /// レイアウトの説明(ピッカーに表示され検索対象になる)
        public var description: String?
        /// レイアウトを直接適用するホットキー(省略時はピッカーからのみ呼び出せる)
        public var hotkey: HotkeyBinding?
        /// 配置対象に選ばれなかったオンスクリーン標準ウィンドウの扱い(nil = 何もしない)
        public var unlistedWindows: UnlistedWindowsAction?
        /// 配置対象ウィンドウ(unlistedWindows 指定時は省略可。focus 指定がなければ配列の最後にマッチしたエントリへフォーカス)
        public var windows: [WindowEntry]
    }

    /// レイアウト選択ピッカーを開くホットキー(hotkey。nil で無効)
    public var pickerHotkey: HotkeyBinding?
    /// Window Hints からピッカーへ遷移するキー(init 相当の結線で注入)
    public var windowHintsKey: String?
    /// レイアウト一覧(名前昇順)
    public var layouts: [Layout]
    /// launch で起動したアプリのウィンドウ出現を待つ最大時間(秒。windowWaitTimeout)
    public var windowWaitTimeout: Double

    /// ピッカーの幅(appearance.pickerWidth)
    public var pickerWidth: Double
    /// ピッカーのレイアウト1行の高さ(appearance.rowHeight)
    public var rowHeight: Double
    /// ピッカーに同時表示する最大行数(appearance.maxVisibleRows)
    public var maxVisibleRows: Int
    /// ピッカー背景の角丸(appearance.cornerRadius)
    public var cornerRadius: Double
    /// ピッカーの背景色(appearance.bgColor)
    public var bgColor: ConfigColor
    /// レイアウト名・クエリの文字色(appearance.textColor)
    public var textColor: ConfigColor
    /// description・プレースホルダ・件数表示の文字色(appearance.dimmedTextColor)
    public var dimmedTextColor: ConfigColor
    /// 選択行の背景色(appearance.selectedBgColor)
    public var selectedBgColor: ConfigColor
    /// 選択行の文字色(appearance.selectedTextColor)
    public var selectedTextColor: ConfigColor
}

public enum WindowLayoutsConfigBuilder {
    static var defaults: [String: Any] {
        [
            "windowWaitTimeout": 10,
            "appearance": [
                "pickerWidth": 480,
                "rowHeight": 32,
                "maxVisibleRows": 8,
                "cornerRadius": 12,
                "bgColor": ["red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.88],
                "textColor": ["red": 0.96, "green": 0.97, "blue": 1.00, "alpha": 1.00],
                "dimmedTextColor": ["red": 0.82, "green": 0.84, "blue": 0.88, "alpha": 0.45],
                "selectedBgColor": ["red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.35],
                "selectedTextColor": ["red": 0.96, "green": 1.00, "blue": 0.98, "alpha": 1.00],
            ],
        ]
    }

    public static func build(
        _ options: [String: Any] = [:], windowHintsKey: String? = nil
    ) throws -> WindowLayoutsConfig {
        let merged = ConfigDict(
            DeepMerge.merge(defaults: defaults, overrides: options), context: "windowLayouts")

        guard let rawLayouts = merged.dict("layouts"), !rawLayouts.isEmpty else {
            throw ConfigError("[jinrai.windowLayouts] layouts は1件以上必要です")
        }

        var layouts: [WindowLayoutsConfig.Layout] = []
        for name in rawLayouts.keys.sorted() {
            guard let rawLayout = rawLayouts[name] as? [String: Any] else {
                throw ConfigError(
                    "[jinrai.windowLayouts] layouts['\(name)'] はオブジェクトである必要があります")
            }
            layouts.append(try buildLayout(name: name, rawLayout))
        }

        // ピッカーのホットキー(key が無ければ無効)
        var pickerHotkey: WindowLayoutsConfig.HotkeyBinding?
        if let key = merged.string("hotkey.key"), !key.isEmpty {
            pickerHotkey = .init(
                modifiers: merged.stringArray("hotkey.modifiers") ?? [], key: key)
        }

        // ピッカーへの導線が無い場合、ホットキーの無いレイアウトは呼び出せない
        if pickerHotkey == nil && windowHintsKey == nil {
            for layout in layouts where layout.hotkey == nil {
                throw ConfigError(
                    "[jinrai.windowLayouts] layouts['\(layout.name)'] は hotkey がなく、"
                        + "ピッカー(windowLayouts.hotkey / windowHints.navigation.windowLayouts.key)も未設定のため呼び出せません")
            }
        }

        // ホットキー重複を検証(ピッカーとレイアウトも同じキー空間で衝突する)
        var seenHotkeys: [String: String] = [:]  // 正規化キー → 用途名
        if let pickerHotkey {
            seenHotkeys[normalize(pickerHotkey)] = "hotkey(ピッカー)"
        }
        for layout in layouts {
            guard let hotkey = layout.hotkey else { continue }
            let normalized = normalize(hotkey)
            if let other = seenHotkeys[normalized] {
                throw ConfigError(
                    "[jinrai.windowLayouts] layouts['\(layout.name)'] のホットキーが \(other) と重複しています"
                )
            }
            seenHotkeys[normalized] = "layouts['\(layout.name)']"
        }

        let windowWaitTimeout = merged.double("windowWaitTimeout") ?? 10
        guard windowWaitTimeout > 0 else {
            throw ConfigError("[jinrai.windowLayouts] windowWaitTimeout は正の数が必要です")
        }

        func positiveDouble(_ path: String, _ fallback: Double) throws -> Double {
            let value = merged.double(path) ?? fallback
            guard value > 0 else {
                throw ConfigError("[jinrai.windowLayouts] \(path) は正の数が必要です")
            }
            return value
        }

        return WindowLayoutsConfig(
            pickerHotkey: pickerHotkey,
            windowHintsKey: windowHintsKey?.uppercased(),
            layouts: layouts,
            windowWaitTimeout: windowWaitTimeout,
            pickerWidth: try positiveDouble("appearance.pickerWidth", 480),
            rowHeight: try positiveDouble("appearance.rowHeight", 32),
            maxVisibleRows: max(1, merged.int("appearance.maxVisibleRows") ?? 8),
            cornerRadius: merged.double("appearance.cornerRadius") ?? 12,
            bgColor: merged.color("appearance.bgColor")
                ?? ConfigColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 0.88),
            textColor: merged.color("appearance.textColor")
                ?? ConfigColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1.00),
            dimmedTextColor: merged.color("appearance.dimmedTextColor")
                ?? ConfigColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 0.45),
            selectedBgColor: merged.color("appearance.selectedBgColor")
                ?? ConfigColor(red: 0.40, green: 0.68, blue: 0.98, alpha: 0.35),
            selectedTextColor: merged.color("appearance.selectedTextColor")
                ?? ConfigColor(red: 0.96, green: 1.00, blue: 0.98, alpha: 1.00)
        )
    }

    /// modifiers の順序・大小文字を無視したホットキーの正規化表現
    static func normalize(_ hotkey: WindowLayoutsConfig.HotkeyBinding) -> String {
        (hotkey.modifiers.map { $0.lowercased() }.sorted() + [hotkey.key.lowercased()])
            .joined(separator: "+")
    }

    static func buildLayout(
        name: String, _ raw: [String: Any]
    ) throws -> WindowLayoutsConfig.Layout {
        let context = "layouts['\(name)']"

        // hotkey は任意(省略時はピッカーからのみ呼び出す)。key が無ければ未設定扱い
        var hotkey: WindowLayoutsConfig.HotkeyBinding?
        if let rawHotkey = raw["hotkey"] as? [String: Any],
            let key = rawHotkey["key"] as? String, !key.isEmpty
        {
            hotkey = .init(modifiers: rawHotkey["modifiers"] as? [String] ?? [], key: key)
        }

        let description = raw["description"] as? String
        if let description, description.isEmpty {
            throw ConfigError(
                "[jinrai.windowLayouts] \(context).description は空にできません(不要なら省略してください)")
        }

        let unlistedWindows = try buildUnlistedWindows(raw, context: context)

        // windows は unlistedWindows 指定時のみ省略可(両方ないレイアウトは何もしないため設定ミスとみなす)
        let rawWindows = raw["windows"] as? [[String: Any]] ?? []
        if rawWindows.isEmpty, unlistedWindows == nil {
            throw ConfigError(
                "[jinrai.windowLayouts] \(context) には windows か unlistedWindows のいずれかが必要です")
        }

        var windows: [WindowLayoutsConfig.WindowEntry] = []
        var focusCount = 0
        for (index, rawWindow) in rawWindows.enumerated() {
            let entryContext = "\(context).windows[\(index)]"
            guard let bundleID = rawWindow["bundleID"] as? String, !bundleID.isEmpty else {
                throw ConfigError("[jinrai.windowLayouts] \(entryContext).bundleID は必須です")
            }
            let area = try validateArea(rawWindow["area"], context: entryContext)
            let titleGlob = rawWindow["titleGlob"] as? String
            if let titleGlob, titleGlob.isEmpty {
                throw ConfigError(
                    "[jinrai.windowLayouts] \(entryContext).titleGlob は空にできません(全ウィンドウ対象なら省略してください)"
                )
            }
            let focus = rawWindow["focus"] as? Bool ?? false
            if focus {
                focusCount += 1
                if focusCount > 1 {
                    throw ConfigError(
                        "[jinrai.windowLayouts] \(context).windows の focus=true は1件だけ指定できます"
                    )
                }
            }
            windows.append(
                .init(
                    bundleID: bundleID,
                    titleGlob: titleGlob,
                    screenUUID: rawWindow["screen"] as? String,
                    area: area,
                    launch: rawWindow["launch"] as? Bool ?? false,
                    focus: focus
                ))
        }

        return WindowLayoutsConfig.Layout(
            name: name, description: description, hotkey: hotkey,
            unlistedWindows: unlistedWindows,
            windows: windows)
    }

    /// unlistedWindows("close" | { screen?, area })のパース。未指定は nil(何もしない)
    private static func buildUnlistedWindows(
        _ raw: [String: Any], context: String
    ) throws -> WindowLayoutsConfig.UnlistedWindowsAction? {
        guard raw["closeUnlistedWindows"] == nil else {
            throw ConfigError(
                "[jinrai.windowLayouts] \(context).closeUnlistedWindows は廃止されました。"
                    + "unlistedWindows: \"close\" を使用してください")
        }
        guard let rawValue = raw["unlistedWindows"] else { return nil }
        switch rawValue {
        case let string as String:
            guard string == "close" else {
                throw ConfigError(
                    "[jinrai.windowLayouts] \(context).unlistedWindows の文字列指定は \"close\" のみです")
            }
            return .close
        case let dict as [String: Any]:
            let area = try validateArea(dict["area"], context: "\(context).unlistedWindows")
            return .place(screenUUID: dict["screen"] as? String, area: area)
        default:
            throw ConfigError(
                "[jinrai.windowLayouts] \(context).unlistedWindows は \"close\" または"
                    + " { screen?, area } のオブジェクトである必要があります")
        }
    }

    /// area の必須・既知エリア名・freeArea 禁止の検証(windows[] / unlistedWindows で共用)
    private static func validateArea(_ rawArea: Any?, context: String) throws -> String {
        guard let area = rawArea as? String, !area.isEmpty else {
            throw ConfigError("[jinrai.windowLayouts] \(context).area は必須です")
        }
        guard let kind = AreaSpec.kind(of: area) else {
            throw ConfigError("[jinrai.windowLayouts] \(context).area '\(area)' は不明なエリア名です")
        }
        guard kind != .freeArea else {
            throw ConfigError(
                "[jinrai.windowLayouts] \(context).area に freeArea は使用できません")
        }
        return area
    }
}
