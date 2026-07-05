---
icon: lucide/panel-top
---

# Window Hints

Window Hintsは、各ウィンドウの上にアプリアイコンとキーを表示し、キー入力やクリックで対象ウィンドウへ切り替える機能です。

他のウィンドウに隠れたウィンドウや別のSpaceにあるウィンドウも候補にできます。

==TODO: 動画==


## 基本設定

[全設定](configuration.md)に、Window Hintsの全項目、デフォルト値、各項目の説明を掲載しています。

```json
"windowHints": {
  "hotkey": {
    "modifiers": ["alt"],
    "key": "f20"
  }
}
```

ホットキーを押すとヒントが表示されます。表示中に次の操作ができます。

- 表示されたキーを入力してウィンドウを選択
- ヒントをクリックしてウィンドウを選択
- ヒント外をクリック、`escape`、または同じホットキーを押して閉じる
- `1`から`9`を押して対応するSpaceへ移動

!!! note
    完全に隠れたウィンドウのプレビュー表示には**画面収録**の許可が必要です。

## ヒントをカスタマイズ

### ヒント表示

```json
"windowHints": {
  "hint": {
    "chars": [
      "A", "S", "D", "F", "G", "H", "J", "K", "L",
      "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
      "Z", "X", "C", "V", "B", "N", "M"
    ],
    "padding": 12,
    "cornerRadius": 12,
    "icon": {
      "size": 72
    },
    "key": {
      "minWidth": 72,
      "fontSize": 48
    },
    "title": {
      "show": true,
      "fontSize": 16,
      "maxSize": 72
    }
  },
  "focusedWindowHighlight": {
    "borderColor": { "red": 0.95, "green": 0.68, "blue": 0.40, "alpha": 0.95 },
    "borderWidth": 13
  },
  "occlusion": {
    "preview": {
      "enabled": true,
      "mode": "background",
      "width": 140,
      "alpha": 0.64
    }
  }
}
```

ヒントの背景色、文字色、枠線色は、`hint.state`、`hint.icon.state`、`hint.key.state`、`hint.title.state`で変更できます。各設定では`normal`、`dimmed`、`occluded`、`active`の状態ごとに色や透明度を指定できます。

別のSpaceにある候補に付くSpace番号バッジは、Space番号に応じた固定の配色で表示されます。

### ヒントキーの先頭文字を指定

アプリやウィンドウタイトルに応じて、ヒントキーの先頭文字を固定できます。ルールは上から順に評価され、最初に一致したものが使われます。

```json
"windowHints": {
  "hint": {
    "prefixOverrides": [
      {
        "match": {
          "bundleID": "md.obsidian",
          "titleGlob": "Minerva*"
        },
        "prefix": "M"
      }
    ]
  }
}
```

- `match.bundleID`または`match.titleGlob`の少なくとも一方を指定します。
- `titleGlob`では`*`と`?`を使用でき、大文字と小文字は区別されます。
- `prefix`は`hint.chars`に含まれる1文字または2文字で指定します。
- 複数のヒントキーが互いの先頭と一致しないよう、残りの文字は自動調整されます。

## 操作をカスタマイズ

### ナビゲーション

```json
"windowHints": {
  "navigation": {
    "focusBack": {
      "key": "tab"
    },
    "direction": {
      "hints": {
        "keys": {
          "left": "h",
          "down": "j",
          "up": "k",
          "right": "l",
          "upLeft": "y",
          "upRight": "u",
          "downLeft": "b",
          "downRight": "n"
        }
      },
      "direct": {
        "modifiers": ["ctrl", "alt"],
        "keys": {
          "left": "h",
          "down": "j",
          "up": "k",
          "right": "l"
        }
      }
    },
    "spaces": {
      "numbers": true,
      "prev": { "key": "," },
      "next": { "key": "." }
    },
    "areaHints": {
      "key": "space"
    },
    "applicationHints": {
      "key": ";",
      "jinraiMode": true
    }
  }
}
```

ヒント表示中のナビゲーションキーと`hint.chars`が重複した場合は、ナビゲーションキーが優先されます。方向移動は現在のSpaceにあるウィンドウを対象にします。

### ヒントを開かずに方向移動

`navigation.direction.direct`を設定すると、Window Hintsを開かずにグローバルホットキーで隣のウィンドウへ直接フォーカスを移動できます。

- `modifiers`と`keys`の両方を指定したときだけ有効になります。
- `keys`には`hints.keys`と同じ方向名(`left`、`down`、`up`、`right`、`upLeft`、`upRight`、`downLeft`、`downRight`)を指定します。
- `modifiers`に`fn`は使用できません。
- Window Hintsの表示中は`direction.hints.keys`が優先され、directのホットキーは発火しません。

### 選択対象とカーソル

```json
"windowHints": {
  "behavior": {
    "selection": {
      "swapWindowFrame": {
        "modifiers": ["shift"]
      }
    },
    "cursor": {
      "onStart": true,
      "onSelect": true
    },
    "candidates": {
      "includeOtherSpaces": true,
      "includeActiveWindow": true
    }
  }
}
```

別のSpaceにある候補はSpace番号付きで画面下部に表示されます。完全に隠れたウィンドウも同じ領域へプレビュー付きで表示されます。
