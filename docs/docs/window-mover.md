---
icon: lucide/move
---

# Window Mover

Window Moverは、アクティブウィンドウの位置や大きさをホットキーで変更する機能です。

画面上のエリアを選んで移動する場合は[Area Hints](area-hints.md)を使用します。

[全設定](configuration.md)に、Window Moverの全項目、デフォルト値、各項目の説明を掲載しています。

==TODO: 動画==


## ホットキーで移動する

### ホットキーを設定

使いたいコマンドにホットキーを設定します。

```json
"windowMover": {
  "commands": {
    "moveToNextDisplay": {
      "hotkey": {
        "modifiers": ["ctrl", "alt"],
        "key": "m"
      }
    },
    "maximizeWindow": {
      "hotkey": {
        "modifiers": ["ctrl", "alt"],
        "key": "return"
      }
    },
    "cycleLeft": {
      "hotkey": {
        "modifiers": ["ctrl", "alt"],
        "key": "h"
      }
    },
    "cycleRight": {
      "hotkey": {
        "modifiers": ["ctrl", "alt"],
        "key": "l"
      }
    }
  }
}
```

ホットキーを指定していないコマンドは無効です。

### ディスプレイと空き領域

| コマンド | 説明 |
| --- | --- |
| `moveToNextDisplay` | 次のディスプレイへ移動し、移動先で最大化します。 |
| `moveToActiveDisplayFreeArea` | 現在のディスプレイにある最大の空き領域へ移動・リサイズします。 |

### ウィンドウ操作

| コマンド | 説明 |
| --- | --- |
| `maximizeWindow` | 現在のディスプレイの作業領域へ最大化します。macOSのフルスクリーンとは異なります。 |
| `minimizeWindow` | ウィンドウを最小化します。 |

### サイズを切り替えながら配置

同じコマンドを繰り返すと、既定では`1/2`、`1/3`、`2/3`の順にサイズが変わります。

| コマンド | 説明 |
| --- | --- |
| `cycleLeft` | 左端へ配置し、横幅を切り替えます。 |
| `cycleHorizontalCenter` | 横方向中央へ配置し、横幅を切り替えます。 |
| `cycleRight` | 右端へ配置し、横幅を切り替えます。 |
| `cycleTop` | 上端へ配置し、高さを切り替えます。 |
| `cycleVerticalCenter` | 縦方向中央へ配置し、高さを切り替えます。 |
| `cycleBottom` | 下端へ配置し、高さを切り替えます。 |

切り替える比率は、`0`より大きく`1`以下の任意の値へ変更できます。たとえば、次の設定では`1/4`と`3/4`も含めて切り替えます。

```json
"windowMover": {
  "behavior": {
    "cycle": {
      "horizontalRatios": [0.5, 0.3333, 0.25, 0.6667, 0.75],
      "verticalRatios": [0.5, 0.3333, 0.25, 0.6667, 0.75]
    }
  }
}
```

### 決まったサイズへ配置

次のコマンドは、名前に対応する[利用可能なエリア](window-mover-areas.md)へ直接移動します。

| サイズ | コマンド |
| --- | --- |
| 横または縦の2分割 | `halfLeft`、`halfHorizontalCenter`、`halfRight`、`halfTop`、`halfVerticalCenter`、`halfBottom` |
| 横または縦の3分割 | `thirdLeft`、`thirdHorizontalCenter`、`thirdRight`、`thirdTop`、`thirdVerticalCenter`、`thirdBottom` |
| 横または縦の4分割 | `quarterLeft`、`quarterHorizontalLeftCenter`、`quarterHorizontalRightCenter`、`quarterRight`、`quarterTop`、`quarterVerticalTopCenter`、`quarterVerticalBottomCenter`、`quarterBottom` |
| 画面の4分割 | `quarterTopLeft`、`quarterTopRight`、`quarterBottomLeft`、`quarterBottomRight` |
| 画面の6分割 | `sixthTopLeft`、`sixthTopCenter`、`sixthTopRight`、`sixthBottomLeft`、`sixthBottomCenter`、`sixthBottomRight` |
| 3分の2 | `twoThirdsLeft`、`twoThirdsHorizontalCenter`、`twoThirdsRight`、`twoThirdsTop`、`twoThirdsVerticalCenter`、`twoThirdsBottom`、`twoThirdsCenter` |
| 4分の3 | `threeQuartersLeft`、`threeQuartersHorizontalCenter`、`threeQuartersRight`、`threeQuartersTop`、`threeQuartersVerticalCenter`、`threeQuartersBottom`、`threeQuartersCenter` |

## 共通設定

以下の設定は、[Area Hints](area-hints.md)経由の移動にも適用されます。

### 移動後にカーソルを追従

```json
"windowMover": {
  "behavior": {
    "cursor": {
      "afterMove": true
    }
  }
}
```

`behavior.cursor.afterMove`を`true`にすると、移動後にカーソルもウィンドウ中央へ移動します。

### freeAreaの背面判定

```json
"windowMover": {
  "behavior": {
    "freeArea": {
      "hiddenWindowThreshold": 0.5
    }
  }
}
```

`behavior.freeArea.hiddenWindowThreshold`は、前面ウィンドウに隠れた背面ウィンドウを`freeArea`計算から除外するしきい値です。対象ウィンドウの画面内面積に対して、前面ウィンドウに隠れた割合がこの値以上なら除外します。`0`にすると、少しでも重なった背面ウィンドウを除外する旧挙動相当になります。
