# Window Hints

Window Hintsは、各ウィンドウの上にアプリアイコンとキーを表示し、キー入力やクリックで対象ウィンドウへ切り替える機能です。

他のウィンドウに隠れたウィンドウや別のSpaceにあるウィンドウも候補にできます。

<iframe width="700" height="393" src="https://www.youtube.com/embed/clwLqNw0kXw?si=O4erjEct74Pt4Lvj" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>


## 基本設定

[全設定](configuration.md)に、Window Hintsの全項目、デフォルト値、各項目の説明を掲載しています。

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

別のSpaceにある候補はSpace番号付きで画面下部に表示されます。完全に隠れたウィンドウも同じ領域へプレビュー付きで表示されます。
