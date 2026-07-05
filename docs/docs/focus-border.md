# Focus Border

フォーカスが移動したウィンドウを枠線で一時的に強調します。別のSpaceへ移動した場合も、切り替え後のウィンドウを確認しやすくなります。

## 枠線を設定

`focus_border = {}`で有効になります。
[全設定](configuration.md)に、Focus Borderの全項目、デフォルト値、各項目の説明を掲載しています。

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
