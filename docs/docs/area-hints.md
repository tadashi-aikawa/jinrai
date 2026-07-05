---
icon: lucide/layout-dashboard
---

# Area Hints

Area Hintsは、各ディスプレイ上に設定済みのエリアとキーを表示し、キー入力でアクティブウィンドウをそのエリアへ移動する機能です。

移動そのものの挙動(カーソル追従、freeAreaの計算)は[Window Mover](window-mover.md)の共通設定に従います。

[全設定](configuration.md)に、Area Hintsの全項目、デフォルト値、各項目の説明を掲載しています。

==TODO: 動画==

## 基本設定

```json
"areaHints": {
  "hotkey": {
    "modifiers": ["ctrl", "alt"],
    "key": "space"
  }
}
```

ホットキーを押すとエリア選択画面が開きます。キーを入力すると、アクティブウィンドウがそのエリアへ移動します。

選択画面は`escape`、候補外のクリック、または起動に使ったホットキーで閉じられます。

## ディスプレイUUIDを確認

エリアが未設定の状態でArea Hintsを開くと、各ディスプレイ上にUUIDと設定例が表示されます。表示されたUUIDを`screens`のキーに使用します。

## エリアを設定

設定できるエリア名は[利用可能なエリア](window-mover-areas.md)を参照してください。

```json
"areaHints": {
  "hotkey": {
    "modifiers": ["ctrl", "alt"],
    "key": "space"
  },
  "defaultScreen": {
    "halfLeft": "H",
    "halfRight": "L",
    "full": "F"
  },
  "screens": {
    "DISPLAY_UUID_A": {
      "freeArea": "V",
      "full": "A",
      "halfLeft": "S",
      "halfHorizontalCenter": "D",
      "halfRight": "F",
      "quarterTopLeft": "Q",
      "quarterTopRight": "W",
      "quarterBottomLeft": "Z",
      "quarterBottomRight": "X",
      "1920x1080Center": "M"
    }
  },
  "actions": {
    "closeWindow": "C",
    "minimizeWindow": "N",
    "maximizeWindow": "G",
    "quitApplication": "P",
    "detachChromeTabToNewWindow": "T"
  },
  "navigation": {
    "windowHints": {
      "key": "H"
    }
  },
  "labels": {
    "show": true
  }
}
```

| 設定 | 説明 |
| --- | --- |
| `screens` | ディスプレイUUIDごとに、エリア名と選択キーを指定します。[ディスプレイ数ごとの分岐](#ディスプレイ数で設定を切り替える)も指定できます。 |
| `defaultScreen` | `screens`に設定がないディスプレイで使う、エリア名と選択キーのマップです。こちらもディスプレイ数ごとの分岐を指定できます。 |
| `actions.closeWindow` | 選択中にアクティブウィンドウを閉じるキーです。 |
| `actions.minimizeWindow` | 選択中にアクティブウィンドウを最小化するキーです。 |
| `actions.maximizeWindow` | 選択中にアクティブウィンドウを最大化するキーです。 |
| `actions.quitApplication` | 選択中にアクティブウィンドウのアプリケーションを通常終了するキーです。 |
| `actions.detachChromeTabToNewWindow` | 選択中にGoogle Chromeの現在のタブを新しいChromeウィンドウとして分離するキーです。 |
| `navigation.windowHints.key` | 選択画面を閉じ、[Window Hints](window-hints.md)を開くキーです。 |
| `labels.show` | エリアとキーのラベルを画面上に表示するかを指定します。`false`でもキー入力は有効です。 |

`freeArea`を選ぶと、選択した時点のウィンドウ配置から最大の空き領域を探します。アクティブウィンドウは移動先を塞ぐ障害物から除外されますが、背面ウィンドウを隠す前面領域として扱われます。空き領域がない場合、ウィンドウは移動せず選択画面が維持されます。

## ディスプレイ数で設定を切り替える

同じディスプレイでも、接続中のディスプレイ数によってエリアとキーの割り当てを変えられます。エリアマップの代わりに、ディスプレイ数をキーにしたマップを指定します。

たとえば「外部モニタ接続時はメインの外部モニタを1キー、サブのMacBookは`J`プレフィックス付きにするが、MacBook単体のときはプレフィックスなしにする」場合は次のように設定します。

```json
"areaHints": {
  "screens": {
    "MACBOOK_UUID": {
      "1": {
        "halfLeft": "H",
        "halfRight": "L",
        "full": "F"
      },
      "2": {
        "halfLeft": "JH",
        "halfRight": "JL",
        "full": "JF"
      }
    },
    "EXTERNAL_UUID": {
      "halfLeft": "H",
      "halfRight": "L",
      "full": "F"
    }
  }
}
```

- キーがすべて数字(または`default`)の場合にディスプレイ数ごとの分岐として解釈されます。数字とエリア名は混在できません。
- エリアマップは「Area Hintsを開いた時点のディスプレイ数に一致するもの → `default` → `defaultScreen`」の順で解決されます。
- `defaultScreen`にも同じ形式でディスプレイ数ごとの分岐を指定できます。

## キーの制約

- 選択キーは1〜3文字で指定します。
- 同じディスプレイ内のエリアキー、アクションキー、[Window Hints](window-hints.md)へ移るキーは重複させないでください。
- `B`と`B1`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。

## Window Hintsから開く

```json
"windowHints": {
  "navigation": {
    "areaHints": {
      "key": "space"
    }
  }
}
```

[Window Hints](window-hints.md)の表示中に設定キーを押すと、Area Hintsへ切り替わります。

## JinraiModeで使う

[JinraiMode](jinrai-mode.md)では、Window Hintsによるウィンドウ選択とArea Hintsによる移動先選択を交互に繰り返します。

- `jinraiMode.hotkey`を設定すると、最初からJinraiModeとしてArea Hintsを開けます。
- 表示中に`jinraiMode.triggers.areaHints.key`([全設定](configuration.md)参照)を押すと、その場でJinraiModeを開始します。

```json
"areaHints": {
  "jinraiMode": {
    "hotkey": {
      "modifiers": ["ctrl", "alt"],
      "key": "j"
    }
  }
}
```

JinraiMode中に`detachChromeTabToNewWindow`を実行した場合は、Window Hintsには戻らず、分離したChromeウィンドウを移動できるようにArea Hintsを再表示します。

## 選択画面の見た目

ラベルの背景色と文字色は、`normal`(候補)と`dimmed`(キー入力で候補から外れた状態)ごとに変更できます。

```json
"areaHints": {
  "appearance": {
    "state": {
      "normal": {
        "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.88 },
        "textColor": { "red": 0.96, "green": 1.0, "blue": 0.98, "alpha": 1.0 },
        "typedTextColor": { "red": 0.96, "green": 1.0, "blue": 0.98, "alpha": 0.38 }
      },
      "dimmed": {
        "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.30 },
        "textColor": { "red": 0.96, "green": 1.0, "blue": 0.98, "alpha": 0.32 }
      }
    }
  }
}
```

エリア種類ごとの枠線色は固定です。アクティブウィンドウの強調は`activeWindowHighlight`(枠線色・太さ・角丸)と`activeWindowSpotlight.alpha`(暗幕の透明度)で変更できます。
