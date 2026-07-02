import AppKit
import JinraiCore

/// ~/.config/jinrai/config.json の読込($XDG_CONFIG_HOME 尊重)
enum ConfigLoader {
    static var configFileURL: URL {
        let base: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config")
        }
        return base.appendingPathComponent("jinrai/config.json")
    }

    /// 初回起動時に生成するテンプレート
    static let defaultConfigTemplate = """
        {
            // Jinrai 設定ファイル(JSONC: コメント・末尾カンマ可)
            // 各機能はセクションが存在するときだけ有効になります

            // フォーカス移動時にウィンドウを枠線で強調
            "focus_border": {},

            // option+w で直前のウィンドウへ戻る
            "focus_back": {},

            // ウィンドウヒント(デフォルトのホットキーは alt+f20)
            // "hotkey": { "modifiers": ["alt"], "key": "f20" } で変更可
            "window_hints": {},

            // ウィンドウ移動。コマンドにホットキーを割り当てて有効化する
            // 例:
            // "window_mover": {
            //     "commands": {
            //         "cycleLeft": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "h" } },
            //         "cycleRight": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "l" } },
            //         "moveToSelectedArea": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "s" } }
            //     },
            //     "selectedArea": {
            //         "defaultScreen": { "halfLeft": "H", "halfRight": "L", "full": "F" }
            //     }
            // },
        }
        """

    /// 設定を読み込む。ファイルがなければテンプレートを生成して読み込む
    static func load() throws -> RootConfig {
        let url = configFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? defaultConfigTemplate.write(to: url, atomically: true, encoding: .utf8)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try RootConfigBuilder.build(text: text)
    }
}
