/// 初回起動時に生成する config.jsonc のテンプレート。
/// 全機能を衝突しにくいキーマップで有効化した状態にする。
/// docs/docs/setup.md の「初期設定」に同じ内容を掲載しているため、変更時は同期すること
public enum DefaultConfigTemplate {
    public static let text = """
        {
            "$schema": "https://tadashi-aikawa.github.io/jinrai/schemas/config.schema.json",

            // Jinrai 設定ファイル(JSONC: コメント・末尾カンマ可)
            // 各機能はセクションが存在するときだけ有効になり、書いていない項目にはデフォルト値が使われます
            // ホットキーは設定に書いたものだけが登録されます

            // フォーカス移動時にウィンドウを枠線で強調
            "focusBorder": {},

            // alt+w で直前のウィンドウへ戻る
            "focusBack": {
                "hotkey": { "modifiers": ["alt"], "key": "w" }
            },

            // ウィンドウヒント: ctrl+alt+f でヒントを表示し、キー入力でウィンドウを選択
            "windowHints": {
                "hotkey": { "modifiers": ["ctrl", "alt"], "key": "f" },
                "navigation": {
                    // 表示中に space で Area Hints(移動先選択)へ切り替え
                    "areaHints": { "key": "space" },
                    // 表示中に tab で Application Hints(アプリランチャー)へ切り替え
                    "applicationHints": { "key": "tab" }
                }
            },

            // ウィンドウ移動コマンド
            "windowMover": {
                "commands": {
                    // 左/右半分に配置(繰り返すと幅が切り替わる)
                    "cycleLeft": { "hotkey": { "modifiers": ["ctrl", "alt"], "key": "h" } },
                    "cycleRight": { "hotkey": { "modifiers": ["ctrl", "alt"], "key": "l" } },
                    // 最大化
                    "maximizeWindow": { "hotkey": { "modifiers": ["ctrl", "alt"], "key": "return" } },
                    // 次のディスプレイへ移動
                    "moveToNextDisplay": { "hotkey": { "modifiers": ["ctrl", "alt"], "key": "m" } }
                }
            },

            // エリア選択画面: ctrl+alt+s で開き、キー入力でウィンドウを配置
            "areaHints": {
                "hotkey": { "modifiers": ["ctrl", "alt"], "key": "s" },
                // 全ディスプレイ共通のエリア(ディスプレイごとに変えるには "screens" を使う)
                "defaultScreen": { "halfLeft": "H", "halfRight": "L", "full": "F", "freeArea": "V" },
                "navigation": {
                    // 表示中に space で Window Hints へ切り替え
                    "windowHints": { "key": "space" }
                }
            },

            // アプリランチャー: Window Hints から tab で開く。
            // 起動済みアプリは新規ウィンドウ(既定 cmd+n)、未起動なら起動する
            "applicationHints": {
                "apps": [
                    { "bundleID": "com.apple.Safari", "key": "S" },
                    { "bundleID": "com.apple.finder", "key": "F" },
                    // 例:
                    // { "bundleID": "com.google.Chrome", "key": "E" },
                    // { "bundleID": "md.obsidian", "key": "O", "name": "Obsidian",
                    //   "newWindow": { "url": "obsidian://open?path=/path/to/vault" } },
                ]
            },

            // JinraiMode: ヒント表示中に return で開始し、ウィンドウ選択→配置を連続操作
            "jinraiMode": {
                "triggers": {
                    "windowHints": { "key": "return" },
                    "areaHints": { "key": "return" }
                }
            },

            // 特定のディスプレイが接続されているときだけ設定を上書き
            // 例:
            // "profiles": [
            //     {
            //         "displays": ["DISPLAY_UUID"],
            //         "overrides": {
            //             "jinraiMode": {
            //                 "combo": {
            //                     "character": {
            //                         "enabled": true,
            //                         "images": ["~/Pictures/jinrai-combo.png"]
            //                     },
            //                     "text": { "enabled": true }
            //                 }
            //             }
            //         }
            //     }
            // ],
        }
        """
}
