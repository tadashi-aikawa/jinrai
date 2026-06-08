# Focus Border

フォーカスが移動したウィンドウを枠線で一時的に強調します。別のSpaceへ移動した場合も、切り替え後のウィンドウを確認しやすくなります。

## 基本設定

`focus_border = {}`で有効になります。次の項目で表示を調整できます。

```lua
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
    logo = nil,
  },
  animation = {
    duration = 0.5,
    spaceSwitchDelay = 0.30,
  },
  window = {
    minSize = 480,
  },
}
```

## 設定項目

| 設定 | 説明 |
| --- | --- |
| `visual.border.width` | メインの枠線の太さです。 |
| `visual.border.color` | メインの枠線の色です。 |
| `visual.outline.width` | 外側の枠線の太さです。 |
| `visual.outline.color` | 外側の枠線の色です。 |
| `animation.duration` | 枠線が消えるまでの時間です。 |
| `animation.spaceSwitchDelay` | 別のSpaceへ移動したときに表示を待つ時間です。 |
| `window.minSize` | 枠線を表示する最小ウィンドウサイズです。 |

## ロゴを表示

フォーカスしたウィンドウの中央に画像を表示できます。

```lua
focus_border = {
  visual = {
    logo = {
      source = nil,
      size = 480,
      alpha = 0.95,
    },
  },
}
```

`source`を省略するとJINRAI同梱ロゴを使います。ローカル画像のパスまたはURLも指定できます。`logo = nil`または`false`で非表示になります。
