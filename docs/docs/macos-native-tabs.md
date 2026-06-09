# macOS Native Tabs

macOSネイティブタブを使うアプリで、[Window Hints](window-hints.md)と[Focus Back](focus-back.md)を安定して利用するための補正設定です。

GhosttyとFinderは最初から対象に含まれています。

## 対象アプリを追加

アプリ名またはbundle IDを指定します。

```lua
spoon.Jinrai:setup({
  macosNativeTabs = {
    apps = {
      "com.example.terminal",
    },
  },
  window_hints = {},
  focus_back = {},
})
```

`apps`に指定したアプリは、組み込みの対象アプリへ追加されます。

## 補正を無効化

すべてのアプリで補正を無効にする場合は、`false`を指定します。

```lua
spoon.Jinrai:setup({
  macosNativeTabs = false,
  window_hints = {},
  focus_back = {},
})
```
