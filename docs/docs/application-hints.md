# Application Hints

Application Hintsは、登録したアプリを固定キーから起動し、新しいウィンドウを作成する機能です。

Window Hintsとは異なり、現在存在するウィンドウではなく、起動可能なアプリを表示します。

<iframe width="700" height="393" src="https://www.youtube.com/embed/UnIfdg4emzU?si=e71kGttbS3O_CBfy" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## 基本設定

[全設定](configuration.md)に、Application Hintsの全項目、
デフォルト値、各項目の説明を掲載しています。

```json
"applicationHints": {
  "hotkey": {
    "modifiers": ["ctrl", "alt"],
    "key": "a"
  },
  "apps": [
    {
      "bundleID": "com.google.Chrome",
      "key": "C"
    }
  ]
}
```

Application Hintsを開くと、登録アプリがアクティブウィンドウの中央に表示されます。

- `OPEN`: アプリが起動していません。選択するとアプリを起動します。
- `NEW`: アプリが起動済みです。選択すると新しいウィンドウを作成します。
- 作成したウィンドウへ自動的にフォーカスします。

## タイトルをカスタマイズ

`name`でヒントに表示するアプリ名を指定できます。
未指定の場合はアプリ名から自動で決定します。

```json
"applicationHints": {
  "apps": [
    {
      "bundleID": "com.google.Chrome",
      "key": "C",
      "name": "Chrome"
    }
  ]
}
```

## 表示をカスタマイズ

`appearance.columns`で、1行に表示するアプリ数を変更できます。デフォルトは`3`です。

```json
"applicationHints": {
  "appearance": {
    "columns": 4
  },
  "apps": [
    {
      "bundleID": "com.google.Chrome",
      "key": "C"
    }
  ]
}
```

背景色の`alpha`で、通常表示とキー入力によって候補から外れた表示の透明度を変更できます。

```json
"applicationHints": {
  "appearance": {
    "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.80 },
    "dimmedBgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.30 }
  },
  "apps": [
    {
      "bundleID": "com.google.Chrome",
      "key": "C"
    }
  ]
}
```

## 新規ウィンドウ作成

起動中のアプリを選択すると、既定ではフォーカスを切り替えずに`Cmd+N`で新しいウィンドウを作成します。

Ghosttyのように新規ウィンドウのキーが異なるアプリは、`newWindow.hotkey`で上書きします。

```json
{
  "bundleID": "com.mitchellh.ghostty",
  "key": "G",
  "newWindow": {
    "hotkey": {
      "modifiers": ["ctrl"],
      "key": "n"
    }
  }
}
```

## URLから新規ウィンドウ作成

ホットキーでは作成できないアプリは、`newWindow.url`を指定できます。`url`は`hotkey`より優先され、選択時にそのURLを開きます。

たとえば、ObsidianのURLスキームを使って特定のVaultを開くことができます。

```json
"applicationHints": {
  "apps": [
    {
      "bundleID": "md.obsidian",
      "key": "O",
      "newWindow": {
        "url": "obsidian://open?path=/path/to/vault"
      }
    }
  ]
}
```

## Window Hintsから開く

```json
"windowHints": {
  "navigation": {
    "applicationHints": {
      "key": ";",
      "jinraiMode": true
    }
  }
}
```

Window Hints表示中に設定キーを押すとApplication Hintsへ切り替わります。同じキーをもう一度押すとWindow Hintsへ戻り、`escape`で閉じます。

`"jinraiMode": true`を指定すると、Window Hintsが通常表示中でもJinraiModeを開始してApplication Hintsへ切り替わります。

## JinraiModeを開始

```json
"jinraiMode": {
  "triggers": {
    "applicationHints": {
      "key": "space"
    }
  }
}
```

Application Hints表示中に`triggers.applicationHints.key`を押すとJinraiModeを開始し、ロゴ・キャラクター・COMBOテキストを表示します。

## キーの制約

- アプリキーは1文字または2文字で指定します。
- アプリキー、Window Hintsとの切り替えキー、JinraiMode開始キーは重複できません。
- `A`と`AB`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。
