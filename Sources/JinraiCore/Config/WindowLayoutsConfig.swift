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
        /// 未起動なら起動してウィンドウ出現を待つか(デフォルト false = スキップ)
        public var launch: Bool
    }

    /// 1つのレイアウト定義(layouts.<名前>)
    public struct Layout: Sendable {
        /// レイアウト名(layouts のキー。ログ・エラーメッセージ用)
        public var name: String
        /// レイアウトを適用するホットキー(必須)
        public var hotkey: HotkeyBinding
        /// 配置対象ウィンドウ(1件以上。配列の最後にマッチしたエントリへフォーカス)
        public var windows: [WindowEntry]
    }

    /// レイアウト一覧(名前昇順)
    public var layouts: [Layout]
    /// launch で起動したアプリのウィンドウ出現を待つ最大時間(秒。windowWaitTimeout)
    public var windowWaitTimeout: Double
}

public enum WindowLayoutsConfigBuilder {
    public static func build(_ options: [String: Any] = [:]) throws -> WindowLayoutsConfig {
        let merged = ConfigDict(options, context: "windowLayouts")

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

        // レイアウト間のホットキー重複を検証(同一 modifiers+key は後勝ちの未定義動作になるため)
        var seenHotkeys: [String: String] = [:]  // 正規化キー → レイアウト名
        for layout in layouts {
            let normalized = (layout.hotkey.modifiers.map { $0.lowercased() }.sorted()
                + [layout.hotkey.key.lowercased()]).joined(separator: "+")
            if let other = seenHotkeys[normalized] {
                throw ConfigError(
                    "[jinrai.windowLayouts] layouts['\(layout.name)'] のホットキーが layouts['\(other)'] と重複しています"
                )
            }
            seenHotkeys[normalized] = layout.name
        }

        let windowWaitTimeout = merged.double("windowWaitTimeout") ?? 10
        guard windowWaitTimeout > 0 else {
            throw ConfigError("[jinrai.windowLayouts] windowWaitTimeout は正の数が必要です")
        }

        return WindowLayoutsConfig(layouts: layouts, windowWaitTimeout: windowWaitTimeout)
    }

    static func buildLayout(
        name: String, _ raw: [String: Any]
    ) throws -> WindowLayoutsConfig.Layout {
        let context = "layouts['\(name)']"

        guard let rawHotkey = raw["hotkey"] as? [String: Any],
            let key = rawHotkey["key"] as? String, !key.isEmpty
        else {
            throw ConfigError("[jinrai.windowLayouts] \(context).hotkey.key は必須です")
        }
        let hotkey = WindowLayoutsConfig.HotkeyBinding(
            modifiers: rawHotkey["modifiers"] as? [String] ?? [], key: key)

        guard let rawWindows = raw["windows"] as? [[String: Any]], !rawWindows.isEmpty else {
            throw ConfigError("[jinrai.windowLayouts] \(context).windows は1件以上必要です")
        }

        var windows: [WindowLayoutsConfig.WindowEntry] = []
        for (index, rawWindow) in rawWindows.enumerated() {
            let entryContext = "\(context).windows[\(index)]"
            guard let bundleID = rawWindow["bundleID"] as? String, !bundleID.isEmpty else {
                throw ConfigError("[jinrai.windowLayouts] \(entryContext).bundleID は必須です")
            }
            guard let area = rawWindow["area"] as? String, !area.isEmpty else {
                throw ConfigError("[jinrai.windowLayouts] \(entryContext).area は必須です")
            }
            guard let kind = AreaSpec.kind(of: area) else {
                throw ConfigError("[jinrai.windowLayouts] \(entryContext).area '\(area)' は不明なエリア名です")
            }
            guard kind != .freeArea else {
                throw ConfigError(
                    "[jinrai.windowLayouts] \(entryContext).area に freeArea は使用できません")
            }
            let titleGlob = rawWindow["titleGlob"] as? String
            if let titleGlob, titleGlob.isEmpty {
                throw ConfigError(
                    "[jinrai.windowLayouts] \(entryContext).titleGlob は空にできません(全ウィンドウ対象なら省略してください)"
                )
            }
            windows.append(
                .init(
                    bundleID: bundleID,
                    titleGlob: titleGlob,
                    screenUUID: rawWindow["screen"] as? String,
                    area: area,
                    launch: rawWindow["launch"] as? Bool ?? false
                ))
        }

        return WindowLayoutsConfig.Layout(name: name, hotkey: hotkey, windows: windows)
    }
}
