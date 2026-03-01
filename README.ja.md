<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.svg" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>思考の速度で素早くウィンドウの切り替えや認識を行うためのhammerspoonスクリプト</div>
    </p>
    <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml">
      <img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" />
    </a>
    <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE">
      <img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" />
    </a>
    <br />
    <a href="./README.md">
      <img src="https://img.shields.io/badge/Language-English-9ca3af?style=for-the-badge" alt="Language: English" />
    </a>
    <a href="./README.ja.md">
      <img src="https://img.shields.io/badge/Language-%E6%97%A5%E6%9C%AC%E8%AA%9E-2ea44f?style=for-the-badge" alt="Language: Japanese" />
    </a>
</div>

---

- 🔠 **Window Hints**
    - アプリアイコン＋キーヒントによるウィンドウ切り替え
        - アプリ名の頭文字をキーヒントのプレフィックスに自動割り当て
        - 同一プレフィックスのウィンドウが複数ある場合は複数キー入力で絞り込み
    - 他のウィンドウに完全に隠れた(サンプリング近似)ウィンドウは画面下部にドック形式＋プレビュー付きで表示
    - アクティブウィンドウをオーバーレイでハイライト表示
- 🔳 **Focus Border**
    - フォーカスが移動したウィンドウの枠を一瞬だけハイライト表示
- ↩️ **Focus Back**
    - ホットキーで直前にアクティブだったウィンドウに戻る

## デモ動画

[![JINRAI Demo](https://img.youtube.com/vi/clwLqNw0kXw/hqdefault.jpg)](https://youtu.be/clwLqNw0kXw?si=gdetaK7lY0Eovjpp)

## セットアップ

```bash
git clone https://github.com/tadashi-aikawa/jinrai /path/to/jinrai
```

`~/.hammerspoon/init.lua` に以下を追加:

```lua
local jinrai = dofile("/path/to/jinrai/init.lua")

jinrai.setup({
  focus_border = {},
  window_hints = {},
  focus_back = {},
})
```

`focus_border` や `window_hints`、`focus_back` のキーを省略するとそのモジュールは無効になります。

## 設定例

```lua
local jinrai = dofile("/path/to/jinrai/init.lua")

jinrai.setup({
  focus_border = {
    borderWidth = 10,
    borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
    outlineWidth = 2,
    outlineColor = { red = 0, green = 0, blue = 0, alpha = 0.70 },
    duration = 0.5,
    fadeSteps = 18,
    cornerRadius = 10,
    minWindowSize = 480,
  },
  window_hints = {
    hintChars = { "A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M" },
    appPrefixOverrides = {
      {
        match = { bundleID = "md.obsidian", titleGlob = "*- minerva - Obsidian*" },
        prefix = "M",
      },
      {
        match = { bundleID = "md.obsidian" },
        prefix = "O",
      },
      {
        match = { bundleID = "com.google.Chrome" },
        prefix = "GC",
      },
    },
    hotkeyModifiers = { "alt" },
    hotkeyKey = "f20",
    iconSize = 72,
    titleMaxSize = 72,
    centerCursor = true,
    onError = function(err)
      hs.alert.show("Window Hints error: " .. tostring(err), 3)
    end,
  },
  focus_back = {
    hotkeyModifiers = { "option" },
    hotkeyKey = "w",
    centerCursor = true,
  },
})
```

## Focus Border オプション

| オプション      | デフォルト                                                | 説明                                         |
| --------------- | --------------------------------------------------------- | -------------------------------------------- |
| `borderWidth`   | `10`                                                      | メインボーダーの太さ (px)                    |
| `borderColor`   | `{ red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 }`| メインボーダーの色                            |
| `outlineWidth`  | `2`                                                       | 外側アウトラインの太さ (px)                  |
| `outlineColor`  | `{ red = 0, green = 0, blue = 0, alpha = 0.70 }`         | 外側アウトラインの色                          |
| `duration`      | `0.5`                                                     | フェードアウト時間 (秒)                      |
| `fadeSteps`     | `18`                                                      | フェードアウトのステップ数                   |
| `cornerRadius`  | `10`                                                      | 角丸半径 (px)                                |
| `minWindowSize` | `480`                                                     | 表示する最小ウィンドウサイズ (px)            |

## Window Hints オプション

| オプション         | デフォルト     | 説明                             |
| ------------------ | -------------- | -------------------------------- |
| `hotkeyModifiers`  | `{ "alt" }`   | ヒント表示のホットキー修飾キー   |
| `hotkeyKey`        | `"f20"`        | ヒント表示のホットキー           |
| `hintChars`        | `A-Z (QWERTY)`| ヒント文字の配列                 |
| `appPrefixOverrides` | `nil`        | ルール配列による先頭プレフィックス上書き（`window:title()` の `glob` 対応、1-2文字prefix対応） |
| `iconSize`         | `72`           | アプリアイコンのサイズ (px)      |
| `titleMaxSize`     | `72`           | タイトルの最大表示文字数         |
| `showTitles`       | `true`         | タイトル行の表示有無             |
| `occlusionSamplingEnabled` | `true`  | 遮蔽判定サンプリングを動的化するか |
| `occlusionSamplingBaseWidth` | `1920` | 遮蔽判定サンプリングの基準ウィンドウ幅 (px) |
| `occlusionSamplingBaseHeight` | `1080` | 遮蔽判定サンプリングの基準ウィンドウ高さ (px) |
| `occlusionSamplingMinCols` | `4`      | 遮蔽判定サンプリング列数の最小値 |
| `occlusionSamplingMinRows` | `4`      | 遮蔽判定サンプリング行数の最小値 |
| `occlusionSamplingMaxCols` | `8`      | 遮蔽判定サンプリング列数の最大値 |
| `occlusionSamplingMaxRows` | `8`      | 遮蔽判定サンプリング行数の最大値 |
| `onSelect`         | `nil`          | ウィンドウ選択時のコールバック   |
| `onError`          | `nil`          | エラー時のコールバック           |
| `centerCursor`     | `false`        | 選択後にカーソルをウィンドウ中央に移動 |
| `centerCursorOnStart` | `false`     | 起動時にアクティブウィンドウの中心にカーソルを移動 |

遮蔽判定は対象ウィンドウ内のサンプル点で行う近似判定です。
`occlusionSamplingEnabled=true` の場合、`occlusionSamplingBaseWidth/Height` を基準に
`occlusionSamplingMin*` から `occlusionSamplingMax*` の範囲でサンプリンググリッドを動的に調整します。

### appPrefixOverrides

`appPrefixOverrides` は、ウィンドウごとのヒントキー先頭文字（prefix）を上書きするための設定です。
ルールは上から順に評価され、最初に一致したルールが適用されます。

#### appPrefixOverrides の定義

```lua
appPrefixOverrides = {
  {
    match = {
      bundleID = "md.obsidian",   -- 任意
      titleGlob = "Minerva*",     -- 任意 (`window:title()` 対象、`*` と `?` をサポート)
    },
    prefix = "M",                 -- 1文字または2文字。各文字は hintChars に含まれている必要あり
  },
}
```

#### appPrefixOverrides の動作

- `match.bundleID` と `match.titleGlob` はどちらか必須
- `titleGlob` は大文字小文字を区別
- 旧形式の辞書指定（`["bundleID"] = "T"`）は非対応
- 表示キー集合は prefix-free になるよう自動調整（例: `G` と `GC` が競合した場合は `GA` と `GC`）
- どのルールにも一致しない場合は「アプリ名の先頭文字」を使用し、`hintChars` にない文字は `hintChars[1]` にフォールバック
- `prefix` が不正（`hintChars` 外の文字、3文字以上など）の場合はエラー

その他多数のカスタマイズ項目があります。詳しくは `window_hints.lua` 内の `DEFAULT_CONFIG` を参照してください。

## Focus Back オプション

| オプション         | デフォルト       | 説明                                          |
| ------------------ | ---------------- | --------------------------------------------- |
| `hotkeyModifiers`  | `{ "option" }`   | ホットキー修飾キー                            |
| `hotkeyKey`        | `"w"`            | ホットキー（`nil` で無効化）                  |
| `urlEvent`         | `nil`            | URL scheme名（`hammerspoon://<名前>` で発火） |
| `centerCursor`     | `false`          | 切り替え後にカーソルをウィンドウ中央に移動    |
| `stateSync`        | `nil`            | イベント漏れを補完する状態同期設定（下記参照） |

連続で押すと2つのウィンドウ間をトグルで行き来できます。

### stateSync

`stateSync` は、`focus_back` の「直前に使っていたウィンドウ」の記録がずれるのを防ぐための設定です。

通常は macOS のフォーカス通知だけで十分ですが、アプリによってはタブ切り替え時の通知がうまく届かず、`focus_back` が期待と違う場所へ戻ることがあります。
そのようなときに `stateSync` を有効にすると、一定間隔で状態を確認して記録を補正できます。

#### 必要になる例

- タブを切り替えた直後に `focus_back` すると、1つ前に見ていたはずのタブに戻らない
- アプリを行き来したとき、`focus_back` の戻り先が安定しない

#### `stateSync` の定義

| オプション         | デフォルト       | 説明                                          |
| ------------------ | ---------------- | --------------------------------------------- |
| `interval`         | `0.2`            | 同期間隔（秒）                                |
| `targetApps`       | `nil`            | 同期対象アプリ名またはbundle IDの配列（`nil`で全アプリ） |
| `historyScope`     | `"window"`       | 履歴更新単位（`"window"` or `"application"`） |

##### `historyScope` の動作:

- `"window"`: ウィンドウ（タブ）単位で履歴を更新
- `"application"`: 同じアプリ内のタブ移動では履歴を更新しない

#### Ghosttyでの設定例

Ghosttyはタブごとに異なるウィンドウIDを持ち、タブを切り替えてもJINRAI(hammerspoon)で通知を受け取れないため設定が必要です。

```lua
focus_back = {
  stateSync = {
    interval = 0.15,
    targetApps = { "com.mitchellh.ghostty" },
    historyScope = "application",
  },
}
```

> [!NOTE]
> 別のスマートな解決方法があるなら知りたい。

## テスト

ユニットテストは `busted` で実行します。

```bash
busted
```

特定のテストだけ実行したい場合:

```bash
busted spec/focus_back_spec.lua
busted spec/init_spec.lua
```

## ライセンス

MIT
