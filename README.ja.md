<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.svg" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>思考の速度で素早くウィンドウの切り替えや認識を行うためのhammerspoonスクリプト</div>
    </p>
    <p>
        <a href="./README.md">English</a> | 日本語
    </p>
    <p>
        <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml">
          <img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" />
        </a>
        <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE">
          <img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" />
        </a>
    </p>
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

## 開発者ブログ記事（日本語）

[📘至高のウィンドウ切り替えを目指して『JINRAI(迅雷)』をつくった - Minerva](https://minerva.mamansoft.net/2026-03-01-jinrai-ultimate-window-switching)

## セットアップ

### SpoonInstall でインストール（推奨）

`~/.hammerspoon/init.lua` に以下を追加:

```lua
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.jinrai = {
  url = "https://github.com/tadashi-aikawa/jinrai",
  desc = "JINRAI Spoon repository",
  branch = "spoons",
}

spoon.SpoonInstall:andUse("Jinrai", {
  repo = "jinrai",
  fn = function(jinrai)
    jinrai:setup({
      focus_border = {},
      window_hints = {},
      focus_back = {},
    })
  end,
})
```

`focus_border` や `window_hints`、`focus_back` のキーを省略するとそのモジュールは無効になります。

インストール済みの Spoon を更新する場合:

```lua
spoon.SpoonInstall:updateRepo("jinrai")
spoon.SpoonInstall:installSpoonFromRepo("Jinrai", "jinrai")
```

### ソースからインストール（開発向け）

Git + symlink でインストールします:

```bash
git clone https://github.com/tadashi-aikawa/jinrai /path/to/jinrai
ln -sfn /path/to/jinrai/Jinrai.spoon ~/.hammerspoon/Spoons/Jinrai.spoon
```

`~/.hammerspoon/init.lua` に以下を追加:

```lua
hs.loadSpoon("Jinrai")

spoon.Jinrai:setup({
  focus_border = {},
  window_hints = {},
  focus_back = {},
})
```

`focus_border` や `window_hints`、`focus_back` のキーを省略するとそのモジュールは無効になります。

更新する場合:

```bash
git -C /path/to/jinrai pull
```

## 設定例

```lua
hs.loadSpoon("Jinrai")

spoon.Jinrai:setup({
  focus_border = {
    visual = {
      border = {
        width = 10,
        color = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
      },
      outline = {
        width = 2,
        color = { red = 0, green = 0, blue = 0, alpha = 0.70 },
      },
      cornerRadius = 10,
    },
    animation = {
      duration = 0.5,
      fadeSteps = 18,
    },
    window = {
      minSize = 480,
    },
  },
  window_hints = {
    hotkey = {
      modifiers = { "alt" },
      key = "f20",
    },
    hint = {
      chars = { "A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M" },
      prefixOverrides = {
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
    },
    navigation = {
      focusBackKey = "i",
      directionKeys = {
        left = "h",
        down = "j",
        up = "k",
        right = "l",
        upLeft = "y",
        upRight = "u",
        downLeft = "b",
        downRight = "n",
      },
      directHotkeys = {
        modifiers = { "ctrl", "alt" },
        keys = {
          left = "h",
          down = "j",
          up = "k",
          right = "l",
          upLeft = "y",
          upRight = "u",
          downLeft = "b",
          downRight = "n",
        },
      },
      swapSelectModifiers = { "shift" },
    },
    ui = {
      icon = { size = 72 },
      text = { titleMaxSize = 72 },
    },
    behavior = {
      centerCursor = true,
      onError = function(err)
        hs.alert.show("Window Hints error: " .. tostring(err), 3)
      end,
    },
  },
  focus_back = {
    hotkey = {
      modifiers = { "option" },
      key = "w",
    },
    behavior = {
      centerCursor = true,
    },
  },
})
```

## Focus Border オプション

全設定を含むサンプル（デフォルト値）:

```lua
focus_border = {
  visual = {
    border = {
      width = 10, -- メインボーダーの太さ (px)
      color = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 }, -- メインボーダーの色
    },
    outline = {
      width = 2, -- 外側アウトラインの太さ (px)
      color = { red = 0, green = 0, blue = 0, alpha = 0.70 }, -- 外側アウトラインの色
    },
    cornerRadius = 10, -- 角丸半径 (px)
  },
  animation = {
    duration = 0.5, -- フェードアウト時間 (秒)
    fadeSteps = 18, -- フェードアウトのステップ数
  },
  window = {
    minSize = 480, -- 表示する最小ウィンドウサイズ (px)
  },
}
```

## Window Hints オプション

全設定を含むサンプル（デフォルト値）:

```lua
window_hints = {
  hotkey = {
    modifiers = { "alt" }, -- ヒント表示ホットキー修飾キー
    key = "f20",            -- ヒント表示ホットキー
  },
  hint = {
    chars = { "A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M" }, -- ヒント文字配列
    prefixOverrides = nil, -- prefix 上書きルール配列
  },
  ui = {
    icon = {
      size = 72,         -- アイコンサイズ (px)
      alpha = 0.95,      -- アイコン不透明度
      dimmedAlpha = 0.30, -- 非アクティブ時アイコン不透明度
    },
    keyBox = {
      size = 72,             -- キー表示ボックス高さ (px)
      minWidth = 72,         -- キー表示ボックス最小幅 (px)
      horizontalPadding = 10, -- キー表示ボックス左右パディング (px)
      gap = 0,               -- アイコンとキー表示ボックスの間隔 (px)
    },
    text = {
      fontName = nil,      -- フォント名（nil でシステムデフォルト）
      keyFontSize = 48,    -- キー文字フォントサイズ
      titleFontSize = 16,  -- タイトル文字フォントサイズ
      rowGap = 8,          -- アイコン行とタイトル行の間隔 (px)
      titleMaxSize = 72,   -- タイトル最大表示文字数
      showTitles = true,   -- タイトル行表示
      keyColor = { red = 1, green = 1, blue = 1, alpha = 1 }, -- キー文字色
      keyDimmedColor = { red = 0.85, green = 0.85, blue = 0.88, alpha = 0.28 }, -- 非アクティブキー文字色
      titleColor = { red = 0.90, green = 0.92, blue = 0.96, alpha = 1.00 }, -- タイトル文字色
      titleDimmedColor = { red = 0.90, green = 0.92, blue = 0.96, alpha = 0.30 }, -- 非アクティブタイトル文字色
      keyHighlightColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 }, -- 入力済みプレフィックス色
    },
    badge = {
      padding = 12, -- バッジ内側余白 (px)
      bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 }, -- バッジ背景色
      dimmedBgAlpha = 0.14, -- 非アクティブ時背景アルファ
      bumpMove = 90, -- ヒント重なり時のずらし量 (px)
    },
  },
  overlay = {
    active = {
      fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 }, -- アクティブウィンドウの塗り色
      borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 }, -- アクティブウィンドウのボーダー色
      borderWidth = 13, -- アクティブウィンドウのボーダー幅 (px)
      cornerRadius = 10, -- アクティブウィンドウの角丸半径 (px)
    },
    hint = {
      fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.56 }, -- 前面ヒントの塗り色
      borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 }, -- 前面ヒントのボーダー色
      dimmedBorderColor = { red = 0.45, green = 0.45, blue = 0.48, alpha = 0.30 }, -- 候補外前面ヒントのボーダー色
      borderWidth = 6, -- 前面ヒントのボーダー幅 (px)
      cornerRadius = 12, -- 前面ヒントの角丸半径 (px)
    },
  },
  occlusion = {
    sampling = {
      enabled = true,   -- 遮蔽サンプリングを動的化するか
      baseWidth = 1920, -- サンプリング基準ウィンドウ幅 (px)
      baseHeight = 1080, -- サンプリング基準ウィンドウ高さ (px)
      minCols = 4,      -- サンプリング列数の最小値
      minRows = 4,      -- サンプリング行数の最小値
      maxCols = 8,      -- サンプリング列数の最大値
      maxRows = 8,      -- サンプリング行数の最大値
    },
    preview = {
      enabled = true, -- 遮蔽ウィンドウのプレビューを表示するか
      width = 140,    -- プレビュー幅 (px)
      padding = 6,    -- プレビュー上余白 (px)
      alpha = 0.46,   -- プレビュー不透明度
    },
    hint = {
      scale = 0.65,  -- 遮蔽ヒント縮小率
      bgAlpha = 0.32, -- 遮蔽ヒント背景アルファ
      iconAlpha = 0.46, -- 遮蔽ヒントアイコン不透明度
    },
  },
  dock = {
    bottomMargin = 24, -- 遮蔽ヒントドックの下端マージン (px)
    itemGap = 12,      -- ドック内アイテム間隔 (px)
    windowBlend = {
      x = 0.0, -- ドックXを対象ウィンドウへ寄せる割合
      y = 0.0, -- ドックYを対象ウィンドウへ寄せる割合
    },
  },
  navigation = {
    focusBackKey = nil, -- Hints表示中に Focus Back 相当を実行するキー
    directionKeys = nil, -- Hints表示中の方向移動キー
    directHotkeys = nil, -- Hintsを表示せず方向移動するホットキー
    cardinalOverlapTieThresholdPx = 720, -- 上下左右方向移動で同点扱いにする閾値 (px)
    debugDirectionalNavigation = false, -- 方向移動の候補スコアログを出すか
    swapSelectModifiers = nil, -- 確定時にウィンドウフレーム入れ替えする修飾キー
  },
  behavior = {
    onSelect = nil, -- ウィンドウ選択時コールバック
    onError = nil,  -- エラー時コールバック
    centerCursor = false, -- 選択後にカーソルをウィンドウ中央へ移動
    centerCursorOnStart = false, -- 起動時にアクティブウィンドウ中央へカーソル移動
  },
  internal = {
    focusHistory = nil, -- 内部注入専用（通常は設定しない）
  },
}
```

遮蔽判定は対象ウィンドウ内のサンプル点で行う近似判定です。
`occlusion.sampling.enabled=true` の場合、`occlusion.sampling.baseWidth/baseHeight` を基準に
`occlusion.sampling.min*` から `occlusion.sampling.max*` の範囲でサンプリンググリッドを動的に調整します。

### hint.prefixOverrides

`hint.prefixOverrides` は、ウィンドウごとのヒントキー先頭文字（prefix）を上書きするための設定です。
ルールは上から順に評価され、最初に一致したルールが適用されます。

#### hint.prefixOverrides の定義

```lua
hint = {
  prefixOverrides = {
    {
      match = {
        bundleID = "md.obsidian",   -- 任意
        titleGlob = "Minerva*",     -- 任意 (`window:title()` 対象、`*` と `?` をサポート)
      },
      prefix = "M",                 -- 1文字または2文字。各文字は hint.chars に含まれている必要あり
    },
  },
}
```

#### hint.prefixOverrides の動作

- `match.bundleID` と `match.titleGlob` はどちらか必須
- `titleGlob` は大文字小文字を区別
- 表示キー集合は prefix-free になるよう自動調整（例: `G` と `GC` が競合した場合は `GA` と `GC`）
- どのルールにも一致しない場合は、アプリ名の文字を先頭から見て `hint.chars` に含まれる文字を選ぶ（同じ文字が使用済みなら次候補へ）。候補がなければ `hint.chars[1]` にフォールバック
- `prefix` が不正（`hint.chars` 外の文字、3文字以上など）の場合はエラー

実装上のデフォルト値や内部向け設定は、`window_hints_config.lua` 内の `DEFAULT_CONFIG` を参照してください。

### Window Hints 内ナビゲーション

- `navigation.focusBackKey` と `navigation.directionKeys` はヒント表示中のみ有効です
- `navigation.focusBackKey` は `focus_back` 設定が有効なときだけ動作します
- これらのキーと `hint.chars` が競合する場合、競合文字はヒント側から除外され、ナビゲーションキーが優先されます
- 完全に背面に遮蔽されているウィンドウは方向移動の候補から除外されます
- 上下左右は基本的に「副軸の重なり量が大きい」候補を優先し、重なり差が `navigation.cardinalOverlapTieThresholdPx` 以内なら同点扱いとして次に主軸エッジ距離、前面順、副軸ずれ、直前アクティブウィンドウの順で決定します
- 斜め方向は2軸のエッジ距離合計が小さい候補を優先し、同率時は前面順、中心距離、直前アクティブウィンドウの順で決定します

### 直接方向移動ホットキー

`navigation.directHotkeys` は、Window Hints を出さずに方向移動を直接実行する設定です。

```lua
navigation = {
  directHotkeys = {
    modifiers = { "ctrl", "alt" }, -- 必須
    keys = {                       -- 任意。指定した方向だけ有効
      left = "h",
      down = "j",
      up = "k",
      right = "l",
      upLeft = "y",
      upRight = "u",
      downLeft = "b",
      downRight = "n",
    },
  },
}
```

- 移動先の判定は `navigation.directionKeys` と同じ（遮蔽除外・同点時の優先順位を含む）
- キー押下で即フォーカス移動し、Window Hints UI は表示しない
- `keys` を省略した場合は直接方向移動ホットキーを無効化
- `modifiers` では `alt` の別名として `option` も指定可能

## Focus Back オプション

全設定を含むサンプル（デフォルト値）:

```lua
focus_back = {
  hotkey = {
    modifiers = { "option" }, -- ホットキー修飾キー
    key = "w",                -- ホットキー（nil で無効化）
  },
  urlEvent = {
    name = nil, -- URL scheme名（hammerspoon://<名前> で発火）
  },
  behavior = {
    centerCursor = false, -- 切り替え後にカーソルをウィンドウ中央に移動
  },
  stateSync = nil, -- イベント漏れを補完する状態同期設定（下記参照）
  internal = {
    focusHistory = nil, -- 内部注入専用（通常は設定しない）
  },
}
```

連続で押すと2つのウィンドウ間をトグルで行き来できます。

### stateSync

`stateSync` は、`focus_back` の「直前に使っていたウィンドウ」の記録がずれるのを防ぐための設定です。

通常は macOS のフォーカス通知だけで十分ですが、アプリによってはタブ切り替え時の通知がうまく届かず、`focus_back` が期待と違う場所へ戻ることがあります。
そのようなときに `stateSync` を有効にすると、一定間隔で状態を確認して記録を補正できます。

#### 必要になる例

- タブを切り替えた直後に `focus_back` すると、1つ前に見ていたはずのタブに戻らない
- アプリを行き来したとき、`focus_back` の戻り先が安定しない

#### `stateSync` の定義

```lua
stateSync = {
  interval = 0.2,      -- 同期間隔（秒）
  targetApps = nil,    -- 同期対象アプリ名またはbundle IDの配列（nilで全アプリ）
  historyScope = "window", -- 履歴更新単位（"window" or "application"）
}
```

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

## 開発

ソースから symlink で導入しておくと、`Jinrai.spoon/` 配下の変更を Hammerspoon の `Reload Config` ですぐ確認できます。

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
