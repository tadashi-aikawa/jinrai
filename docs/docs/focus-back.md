# Focus Back

ホットキーを押すと、直前にアクティブだったウィンドウへ戻ります。連続して押すと、2つのウィンドウを交互に切り替えられます。

## 設定

```lua
focus_back = {
  hotkey = {
    modifiers = { "option" },
    key = "w",
  },
  urlEvent = {
    name = nil,
  },
  behavior = {
    cursor = {
      onSelect = true,
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `hotkey.modifiers` | Focus Backを実行する修飾キーです。 |
| `hotkey.key` | Focus Backを実行するキーです。`nil`でホットキーを無効にします。 |
| `urlEvent.name` | `hammerspoon://<名前>`からFocus Backを実行する場合の名前です。 |
| `behavior.cursor.onSelect` | 切り替え後、カーソルをウィンドウ中央へ移動するかを指定します。 |

[Window Hints](window-hints.md)の表示中にも、任意のキーからFocus Backを実行できます。
