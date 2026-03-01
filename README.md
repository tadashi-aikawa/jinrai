<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.svg" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>思考の速度で素早くウィンドウの切り替えや認識を行うためのhammerspoonスクリプト</div>
    </p>
    <img src="https://img.shields.io/github/license/mashape/apistatus.svg" />
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

その他多数のカスタマイズ項目があります。詳しくは `window_hints.lua` 内の `DEFAULT_CONFIG` を参照してください。

## Focus Back オプション

| オプション         | デフォルト       | 説明                                          |
| ------------------ | ---------------- | --------------------------------------------- |
| `hotkeyModifiers`  | `{ "option" }`   | ホットキー修飾キー                            |
| `hotkeyKey`        | `"w"`            | ホットキー（`nil` で無効化）                  |
| `urlEvent`         | `nil`            | URL scheme名（`hammerspoon://<名前>` で発火） |
| `centerCursor`     | `false`          | 切り替え後にカーソルをウィンドウ中央に移動    |

連続で押すと2つのウィンドウ間をトグルで行き来できます。

## ライセンス

MIT
