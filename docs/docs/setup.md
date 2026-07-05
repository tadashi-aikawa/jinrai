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

## 最小設定

初回起動時に`~/.config/jinrai/config.jsonc`が自動生成されます(`$XDG_CONFIG_HOME`を設定している場合はその配下)。
JSONC形式のため、コメントと末尾カンマを使用できます。

```json
{
    // フォーカス移動時にウィンドウを枠線で強調
    "focusBorder": {},

    // option+w で直前のウィンドウへ戻る
    "focusBack": {},

    // ウィンドウヒント(デフォルトのホットキーは alt+f20)
    "windowHints": {},

    // ウィンドウ移動。コマンドにホットキーを割り当てて有効化する
    "windowMover": {
        "commands": {
            "moveToNextDisplay": {
                "hotkey": {
                    "modifiers": ["ctrl", "alt"],
                    "key": "m"
                }
            }
        }
    }
}
```

設定を変更したら、メニューバーのJINRAIアイコンから`設定を再読込`を実行してください。

`focusBorder`、`windowHints`、`focusBack`、`windowMover`、`applicationHints`は、それぞれ設定を記述した機能だけが有効になります。

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
