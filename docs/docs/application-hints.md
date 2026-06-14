# Application Hints

Application Hintsは、登録したアプリを固定キーから起動し、新しいウィンドウを作成する機能です。

Window Hintsとは異なり、現在存在するウィンドウではなく、起動可能なアプリを表示します。

## 基本設定

```lua
application_hints = {
  hotkey = {
    modifiers = { "ctrl", "alt" },
    key = "a",
  },
  apps = {
    {
      bundleID = "com.google.Chrome",
      key = "C",
    },
  },
}
```

Application Hintsを開くと、登録アプリがアクティブウィンドウの中央に表示されます。

- `OPEN`: アプリが起動していません。選択するとアプリを起動します。
- `NEW`: アプリが起動済みです。選択すると新しいウィンドウを作成します。
- 作成したウィンドウへ自動的にフォーカスします。

## 折り返す件数

`appearance.columns`で、1行に表示するアプリ数を変更できます。デフォルトは`3`です。

```lua
application_hints = {
  appearance = {
    columns = 4,
  },
  apps = {
    {
      bundleID = "com.google.Chrome",
      key = "C",
    },
  },
}
```

## 背景の透明度

背景色の`alpha`で、通常表示とキー入力によって候補から外れた表示の透明度を変更できます。

```lua
application_hints = {
  appearance = {
    bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 },
    dimmedBgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.30 },
  },
  apps = {
    {
      bundleID = "com.google.Chrome",
      key = "C",
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `appearance.bgColor` | 通常表示の背景色です。`alpha`のデフォルトは`0.80`です。 |
| `appearance.dimmedBgColor` | キー入力によって候補から外れた表示の背景色です。`alpha`のデフォルトは`0.30`です。 |

## 新規ウィンドウ作成

起動中のアプリを選択すると、既定ではフォーカスを切り替えずに`Cmd+N`で新しいウィンドウを作成します。

Ghosttyのように新規ウィンドウのキーが異なるアプリは、`newWindow.hotkey`で上書きします。

```lua
{
  bundleID = "com.mitchellh.ghostty",
  key = "G",
  newWindow = {
    hotkey = {
      modifiers = { "ctrl" },
      key = "n",
    },
  },
}
```

## アプリ固有の新規ウィンドウ作成

ホットキーでは作成できないアプリは、`newWindow.callback`を指定できます。`callback`は`hotkey`より優先されます。

```lua
application_hints = {
  apps = {
    {
      bundleID = "com.example.app",
      key = "E",
      newWindow = {
        callback = function(app)
          -- アプリ固有の新規ウィンドウ作成処理
        end,
      },
    },
  },
}
```

通常のキー操作でウィンドウを作成できないアプリに使用します。

## Window Hintsから開く

```lua
window_hints = {
  navigation = {
    applicationHints = {
      key = ";",
      jinraiMode = true,
    },
  },
}
```

Window Hints表示中に設定キーを押すとApplication Hintsへ切り替わります。同じキーをもう一度押すとWindow Hintsへ戻り、`escape`で閉じます。

`jinraiMode = true`を指定すると、Window Hintsが通常表示中でもJinraiModeを開始してApplication Hintsへ切り替わります。

## JinraiModeを開始

```lua
jinrai_mode = {
  triggers = {
    applicationHints = {
      key = "space",
    },
  },
}
```

Application Hints表示中に`triggers.applicationHints.key`を押すとJinraiModeを開始し、ロゴ・キャラクター・COMBOテキストを表示します。

## キーの制約

- アプリキーは1文字または2文字で指定します。
- アプリキー、Window Hintsとの切り替えキー、JinraiMode開始キーは重複できません。
- `A`と`AB`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。
