---
icon: lucide/panels-top-left
---

# macOS Native Tabs

macOSネイティブタブを使うアプリで、[Window Hints](window-hints.md)と[Focus Back](focus-back.md)を安定して利用するための補正設定です。

GhosttyとFinderは最初から対象に含まれています。

[全設定](configuration.md)に、デフォルト値と各項目の説明を掲載しています。

## 対象アプリを追加

bundle IDまたはアプリ名を指定します。

```json
{
  "macosNativeTabs": {
    "apps": [
      "com.example.terminal"
    ]
  },
  "windowHints": {},
  "focusBack": {}
}
```

`apps`に指定したアプリは、組み込みの対象アプリへ追加されます。
