---
icon: lucide/download
---

# セットアップ

## 対応環境

- macOS 15 以降

## JINRAIをインストール

### Homebrew(推奨)

```bash
brew install tadashi-aikawa/tap/jinrai
```

### 手動

1. [Releases](https://github.com/tadashi-aikawa/jinrai/releases/latest)から`JINRAI-x.y.z.zip`をダウンロードします。
2. 展開して`JINRAI.app`を`/Applications`へ移動します。

#### 手動インストールの初回起動 (Gatekeeper対策)

JINRAIは自己署名(未公証)アプリのため、手動インストール時は初回起動がブロックされます。
macOS 15以降は「右クリック → 開く」のバイパスが廃止されているため、以下の手順で許可します。

1. `JINRAI.app`をダブルクリック → 「開けませんでした」ダイアログで「完了」を選びます。
2. システム設定 → プライバシーとセキュリティ → 下部の「"JINRAI" は…」の**「このまま開く」**をクリックします。

代替手段: `xattr -dr com.apple.quarantine /Applications/JINRAI.app`(Homebrew経由なら不要です)

## 権限を許可

初回起動時に**アクセシビリティ権限**を求められます。
システム設定 → プライバシーとセキュリティ → アクセシビリティでJINRAIを許可すると機能が有効になります。

[Window Hints](window-hints.md)で隠れたウィンドウのプレビューを表示する場合は、**画面収録**の許可も必要です。

## 初期設定

初回起動時に`~/.config/jinrai/config.jsonc`へ次の内容が自動生成されます(`$XDG_CONFIG_HOME`を設定している場合はその配下)。
JSONC形式のため、コメントと末尾カンマを使用できます。

全機能が有効な状態で始まり、ホットキーは設定に書いたものだけが登録されます。

```json
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
}
```

`$schema`によりJSON Schema対応エディタで補完と静的チェックが有効になります([全設定](configuration.md#エディタ補完)参照)。

### 初期キーマップ

| キー | 動作 |
| --- | --- |
| `ctrl+alt+f` | [Window Hints](window-hints.md)を開く |
| `ctrl+alt+s` | [Area Hints](area-hints.md)を開く |
| `ctrl+alt+h` / `ctrl+alt+l` | ウィンドウを左/右半分に配置(繰り返しで幅切替) |
| `ctrl+alt+return` | ウィンドウを最大化 |
| `ctrl+alt+m` | ウィンドウを次のディスプレイへ移動 |
| `alt+w` | 直前のウィンドウへ戻る([Focus Back](focus-back.md)) |

ヒント表示中のキー:

| キー | 動作 |
| --- | --- |
| `space` | Window Hints ⇄ Area Hints を切り替え |
| `tab` | Window Hints から[Application Hints](application-hints.md)を開く |
| `return` | [JinraiMode](jinrai-mode.md)を開始 |

設定を変更したら、メニューバーのJINRAIアイコンから`設定を再読込`を実行してください。

`focusBorder`、`windowHints`、`focusBack`、`windowMover`、`areaHints`、`applicationHints`は、それぞれ設定を記述した機能だけが有効になります。

すべての設定項目、デフォルト値、各項目の概要は[全設定](configuration.md)を参照してください。
値の選択肢や機能固有の制約は各機能ページに記載しています。

## アップデート

JINRAIを起動すると、macOSのメニューバーに稲妻アイコンが表示されます。アイコンをクリックすると、現在のバージョンを確認できます。

1. `アップデートを確認…`を選びます。
2. 更新が見つかった場合はダウンロードと置き換えが行われ、新しいバージョンが自動的に起動します。

Homebrew経由でインストールした場合は、バージョン管理の整合性を保つため自動更新は行われません。次のコマンドで更新してください。

```bash
brew upgrade --cask jinrai
```
