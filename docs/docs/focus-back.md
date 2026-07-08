---
icon: lucide/rotate-ccw
---

# Focus Back

ホットキーを押すと、直前にアクティブだったウィンドウへ戻ります。連続して押すと、2つのウィンドウを交互に切り替えられます。

## 設定

[全設定](configuration.md)に、Focus Backの全項目、デフォルト値、各項目の説明を掲載しています。

`hotkey`を指定したときだけホットキーが登録されます。
`urlEvent.name`を指定すると、`jinrai://<名前>`のURLからFocus Backを実行できます。

```json
"focusBack": {
  "hotkey": {
    "modifiers": ["alt"],
    "key": "w"
  }
}
```

[Window Hints](window-hints.md)の表示中にも、任意のキーからFocus Backを実行できます。
