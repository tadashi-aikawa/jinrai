# Window Hints

Window Hintsは、各ウィンドウの上にアプリアイコンとキーを表示し、キー入力やクリックで対象ウィンドウへ切り替える機能です。

他のウィンドウに隠れたウィンドウや別のSpaceにあるウィンドウも候補にできます。

## 基本設定

```lua
window_hints = {
  hotkey = {
    modifiers = { "alt" },
    key = "f20",
  },
}
```

ホットキーを押すとヒントが表示されます。表示中に次の操作ができます。

- 表示されたキーを入力してウィンドウを選択
- ヒントをクリックしてウィンドウを選択
- ヒント外をクリック、`escape`、または同じホットキーを押して閉じる
- `1`から`9`を押して対応するSpaceへ移動

## ヒントをカスタマイズ

### ヒント表示

```lua
window_hints = {
  hint = {
    chars = {
      "A", "S", "D", "F", "G", "H", "J", "K", "L",
      "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
      "Z", "X", "C", "V", "B", "N", "M",
    },
    padding = 12,
    collisionOffset = 90,
    cornerRadius = 12,
    icon = {
      size = 72,
    },
    key = {
      size = 72,
      minWidth = 72,
      fontName = nil,
      fontSize = 48,
    },
    title = {
      show = true,
      fontName = nil,
      fontSize = 16,
      maxSize = 72,
    },
    spaceBadge = {
      enabled = true,
      size = 32,
    },
  },
  focusedWindowHighlight = {
    borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 },
    borderWidth = 13,
  },
  occlusion = {
    preview = {
      enabled = true,
      mode = "background",
      width = 140,
      alpha = 0.64,
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `hint.chars` | ヒントキーに使用する文字です。 |
| `hint.padding` | ヒント内側の余白です。 |
| `hint.collisionOffset` | ヒント同士が重なった場合にずらす距離です。 |
| `hint.cornerRadius` | ヒント背景の角丸です。 |
| `hint.icon.size` | アプリアイコンの大きさです。 |
| `hint.key.size` | キー表示部分の高さです。 |
| `hint.key.minWidth` | キー表示部分の最小幅です。 |
| `hint.key.fontName` | キー表示に使うフォントです。`nil`でシステム標準になります。 |
| `hint.key.fontSize` | キー表示の文字サイズです。 |
| `hint.title.show` | ウィンドウタイトルを表示するかを指定します。 |
| `hint.title.fontName` | タイトルに使うフォントです。 |
| `hint.title.fontSize` | タイトルの文字サイズです。 |
| `hint.title.maxSize` | 表示するタイトルの最大文字数です。 |
| `hint.spaceBadge.enabled` | 別のSpaceにある候補へSpace番号を表示するかを指定します。 |
| `hint.spaceBadge.size` | Space番号バッジの大きさです。 |
| `focusedWindowHighlight.borderColor` | 現在のウィンドウを示す枠線の色です。 |
| `focusedWindowHighlight.borderWidth` | 現在のウィンドウを示す枠線の太さです。 |
| `occlusion.preview.enabled` | 隠れたウィンドウのプレビューを表示するかを指定します。 |
| `occlusion.preview.mode` | プレビューをヒント背景にする場合は`"background"`、下に表示する場合は`"below"`を指定します。 |
| `occlusion.preview.width` | プレビューの幅です。 |
| `occlusion.preview.alpha` | プレビューの透明度です。 |

ヒントの背景色、文字色、枠線色は、`hint.state`、`hint.icon.state`、`hint.key.state`、`hint.title.state`、`hint.spaceBadge.state`で変更できます。各設定では`normal`、`dimmed`、`occluded`、`active`の状態ごとに色や透明度を指定できます。

### ヒントキーの先頭文字を指定

アプリやウィンドウタイトルに応じて、ヒントキーの先頭文字を固定できます。ルールは上から順に評価され、最初に一致したものが使われます。

```lua
window_hints = {
  hint = {
    prefixOverrides = {
      {
        match = {
          bundleID = "md.obsidian",
          titleGlob = "Minerva*",
        },
        prefix = "M",
      },
    },
  },
}
```

- `match.bundleID`または`match.titleGlob`の少なくとも一方を指定します。
- `titleGlob`では`*`と`?`を使用でき、大文字と小文字は区別されます。
- `prefix`は`hint.chars`に含まれる1文字または2文字で指定します。
- 複数のヒントキーが互いの先頭と一致しないよう、残りの文字は自動調整されます。

## 操作をカスタマイズ

### ナビゲーション

```lua
window_hints = {
  navigation = {
    focusBack = {
      key = "tab",
    },
    direction = {
      hints = {
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
      direct = {
        modifiers = { "ctrl", "alt" },
        keys = {
          left = "h",
          down = "j",
          up = "k",
          right = "l",
        },
      },
    },
    spaces = {
      numbers = true,
      prev = { key = "," },
      next = { key = "." },
    },
    windowMover = {
      moveToSelectedArea = {
        key = "space",
      },
    },
    applicationHints = {
      key = ";",
      jinraiMode = true,
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `navigation.focusBack.key` | ヒント表示中に[Focus Back](focus-back.md)を実行するキーです。 |
| `navigation.direction.hints.keys` | ヒント表示中に方向でウィンドウを選ぶキーです。 |
| `navigation.direction.direct` | Window Hintsを表示せず、方向で直接フォーカスを移動するホットキーです。 |
| `navigation.spaces.numbers` | ヒント表示中に数字キーでSpaceを切り替えるかを指定します。 |
| `navigation.spaces.prev.key` | 前のSpaceへ移動するキーです。 |
| `navigation.spaces.next.key` | 次のSpaceへ移動するキーです。 |
| `navigation.windowMover.moveToSelectedArea.key` | Window Hintsを閉じ、[Window Mover](window-mover.md)のエリア選択を開くキーです。 |
| `navigation.applicationHints.key` | Window Hintsを閉じ、[Application Hints](application-hints.md)を開くキーです。 |
| `navigation.applicationHints.jinraiMode` | `true`の場合、Application Hintsを[JinraiMode](jinrai-mode.md)として開きます。デフォルトは`false`です。 |

ヒント表示中のナビゲーションキーと`hint.chars`が重複した場合は、ナビゲーションキーが優先されます。方向移動は現在のSpaceにあるウィンドウを対象にします。

### 選択対象とカーソル

```lua
window_hints = {
  behavior = {
    selection = {
      swapWindowFrame = {
        modifiers = { "shift" },
      },
    },
    cursor = {
      onStart = true,
      onSelect = true,
    },
    candidates = {
      includeOtherSpaces = true,
      includeActiveWindow = true,
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `behavior.selection.swapWindowFrame.modifiers` | 指定した修飾キーを押しながら選択した場合、選択元と選択先の位置・サイズを入れ替えます。 |
| `behavior.cursor.onStart` | 起動時にカーソルを現在のウィンドウ中央へ移動するかを指定します。 |
| `behavior.cursor.onSelect` | 選択後にカーソルを対象ウィンドウ中央へ移動するかを指定します。 |
| `behavior.candidates.includeOtherSpaces` | 別のSpaceにあるウィンドウも候補へ含めるかを指定します。 |
| `behavior.candidates.includeActiveWindow` | 現在のウィンドウにもヒントを表示するかを指定します。 |

別のSpaceにある候補はSpace番号付きで画面下部に表示されます。完全に隠れたウィンドウも同じ領域へプレビュー付きで表示されます。
