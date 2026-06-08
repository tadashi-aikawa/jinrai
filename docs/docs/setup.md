# セットアップ

## 前提準備

まだHammerspoonをインストールしていない場合は、次のコマンドでインストールして起動します。

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

続いてSpoonInstallをインストールします。

```bash
mkdir -p ~/.hammerspoon/Spoons
curl -L https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip -o /tmp/SpoonInstall.spoon.zip
unzip -o /tmp/SpoonInstall.spoon.zip -d ~/.hammerspoon/Spoons
```

## JINRAIをインストール

Hammerspoon Consoleで次のコードを1回だけ実行します。

```lua
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall:installSpoonFromZipURL(
  "https://github.com/tadashi-aikawa/jinrai/releases/latest/download/Jinrai.spoon.zip"
)
hs.reload()
```

!!! warning
    このコードを`~/.hammerspoon/init.lua`に記述しないでください。`hs.reload()`によって再読み込みが繰り返されます。

## 最小設定

`~/.hammerspoon/init.lua`に次の設定を追加します。

```lua
hs.loadSpoon("Jinrai")

spoon.Jinrai:setup({
  focus_border = {},
  window_hints = {},
  focus_back = {},
  window_mover = {
    commands = {
      moveToNextDisplay = {
        hotkey = {
          modifiers = { "ctrl", "alt" },
          key = "m",
        },
      },
    },
  },
})
```

設定後、Hammerspoonのメニューから`Reload Config`を実行してください。

`focus_border`、`window_hints`、`focus_back`、`window_mover`は、それぞれ設定を記述した機能だけが有効になります。利用可能な設定は各機能ページを参照してください。

## アップデート

JINRAIを読み込むと、macOSのメニューバーにモノクロの稲妻アイコンが表示されます。アイコンをクリックすると、現在のバージョンを確認できます。

1. `Check for Updates...`を選びます。
2. 更新が見つかった場合は、`Update to vX.Y.Z...`または通知をクリックします。
3. SpoonInstallによる更新後、Hammerspoonが自動的に再読み込みされます。
