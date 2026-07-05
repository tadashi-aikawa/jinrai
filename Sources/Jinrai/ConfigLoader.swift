import AppKit
import JinraiCore

/// ~/.config/jinrai/config.jsonc の読込($XDG_CONFIG_HOME 尊重)
enum ConfigLoader {
    static var configFileURL: URL {
        let base: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config")
        }
        return base.appendingPathComponent("jinrai/config.jsonc")
    }

    /// 初回起動時に生成するテンプレート
    static let defaultConfigTemplate = """
        {
            // Jinrai 設定ファイル(JSONC: コメント・末尾カンマ可)
            // 各機能はセクションが存在するときだけ有効になります

            // フォーカス移動時にウィンドウを枠線で強調
            "focusBorder": {},

            // option+w で直前のウィンドウへ戻る
            "focusBack": {},

            // ウィンドウヒント(デフォルトのホットキーは alt+f20)
            // "hotkey": { "modifiers": ["alt"], "key": "f20" } で変更可
            "windowHints": {},

            // ウィンドウ移動。コマンドにホットキーを割り当てて有効化する
            // 例:
            // "windowMover": {
            //     "commands": {
            //         "cycleLeft": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "h" } },
            //         "cycleRight": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "l" } },
            //         "moveToSelectedArea": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "s" } }
            //     },
            //     "selectedArea": {
            //         "defaultScreen": { "halfLeft": "H", "halfRight": "L", "full": "F" }
            //     }
            // },

            // アプリランチャー。Window Hints から navigation.applicationHints.key で開く。
            // 起動済みアプリは新規ウィンドウ(既定 Cmd+N)、未起動なら起動する。
            // 例:
            // "applicationHints": {
            //     "appearance": { "columns": 4 },
            //     "apps": [
            //         { "bundleID": "com.mitchellh.ghostty", "key": "G",
            //           "newWindow": { "hotkey": { "modifiers": ["ctrl"], "key": "n" } } },
            //         { "bundleID": "com.google.Chrome", "key": "E" },
            //         { "bundleID": "md.obsidian", "key": "O", "name": "Obsidian",
            //           "newWindow": { "url": "obsidian://open?path=/path/to/vault" } }
            //     ]
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
