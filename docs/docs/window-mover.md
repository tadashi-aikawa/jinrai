# Window Mover

Window Moverは、アクティブウィンドウの位置や大きさをホットキーまたはエリア選択から変更する機能です。

## ホットキーで移動する

### ホットキーを設定

使いたいコマンドにホットキーを設定します。

```lua
window_mover = {
  commands = {
    moveToNextDisplay = {
      hotkey = {
        modifiers = { "ctrl", "alt" },
        key = "m",
      },
    },
    maximizeWindow = {
      hotkey = {
        modifiers = { "ctrl", "alt" },
        key = "return",
      },
    },
    cycleLeft = {
      hotkey = {
        modifiers = { "ctrl", "alt" },
        key = "h",
      },
    },
    cycleRight = {
      hotkey = {
        modifiers = { "ctrl", "alt" },
        key = "l",
      },
    },
  },
}
```

ホットキーを指定していないコマンドは無効です。

### ディスプレイとエリア

| コマンド | 説明 |
| --- | --- |
| `moveToNextDisplay` | 次のディスプレイへ移動し、移動先で最大化します。 |
| `moveToActiveDisplayFreeArea` | 現在のディスプレイにある最大の空き領域へ移動・リサイズします。 |
| `moveToSelectedArea` | ディスプレイごとに設定した移動先を選ぶ画面を開きます。 |
| `moveToSelectedAreaInJinraiMode` | [JinraiMode](jinrai-mode.md)として移動先を選ぶ画面を開きます。 |

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

```lua
window_mover = {
  behavior = {
    cycle = {
      horizontalRatios = { 1 / 2, 1 / 3, 1 / 4, 2 / 3, 3 / 4 },
      verticalRatios = { 1 / 2, 1 / 3, 1 / 4, 2 / 3, 3 / 4 },
    },
  },
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

### 移動後にカーソルを追従

```lua
window_mover = {
  behavior = {
    cursor = {
      afterMove = true,
    },
  },
}
```

`behavior.cursor.afterMove`を`true`にすると、移動後にカーソルもウィンドウ中央へ移動します。

## エリアを選んで移動

`moveToSelectedArea`は、各ディスプレイ上に設定済みのエリアとキーを表示します。キーを入力すると、アクティブウィンドウがそのエリアへ移動します。

### ディスプレイUUIDを確認

エリアが未設定の状態で`moveToSelectedArea`を実行すると、各ディスプレイ上にUUIDと設定例が表示されます。表示されたUUIDを`selectedArea.screens`のキーに使用します。

### エリアを設定

設定できるエリア名は[利用可能なエリア](window-mover-areas.md)を参照してください。

```lua
window_mover = {
  commands = {
    moveToSelectedArea = {
      hotkey = {
        modifiers = { "ctrl", "alt" },
        key = "space",
      },
    },
  },
  selectedArea = {
    defaultScreen = "DISPLAY_UUID_A",
    screens = {
      ["DISPLAY_UUID_A"] = {
        freeArea = "V",
        full = "A",
        halfLeft = "S",
        halfHorizontalCenter = "D",
        halfRight = "F",
        quarterTopLeft = "Q",
        quarterTopRight = "W",
        quarterBottomLeft = "Z",
        quarterBottomRight = "X",
        ["1920x1080Center"] = "M",
      },
    },
    actions = {
      closeWindow = "C",
    },
    windowHints = {
      key = "H",
    },
    hints = {
      show = true,
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `selectedArea.screens` | ディスプレイUUIDごとに、エリア名と選択キーを指定します。 |
| `selectedArea.defaultScreen` | 設定がないディスプレイへ流用するキーマップのUUIDです。 |
| `selectedArea.actions.closeWindow` | エリア選択中にアクティブウィンドウを閉じるキーです。 |
| `selectedArea.windowHints.key` | エリア選択を閉じ、[Window Hints](window-hints.md)を開くキーです。 |
| `selectedArea.hints.show` | エリアとキーを画面上に表示するかを指定します。`false`でもキー入力は有効です。 |

選択画面は`escape`、候補外のクリック、または起動に使ったホットキーで閉じられます。

`freeArea`を選ぶと、選択した時点のウィンドウ配置から最大の空き領域を探します。空き領域がない場合、ウィンドウは移動せず選択画面が維持されます。

同じディスプレイ内のエリアキー、アクションキー、[Window Hints](window-hints.md)へ戻るキーは重複させないでください。`B`と`B1`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。

### 選択画面の見た目

```lua
window_mover = {
  selectedArea = {
    appearance = {
      borderWidth = 2,
      cornerRadius = 6,
      state = {
        normal = {
          bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.88 },
          textColor = { red = 0.96, green = 1.0, blue = 0.98, alpha = 1.0 },
          typedTextColor = { red = 0.96, green = 1.0, blue = 0.98, alpha = 0.38 },
        },
        dimmed = {
          bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.30 },
          textColor = { red = 0.96, green = 1.0, blue = 0.98, alpha = 0.32 },
        },
      },
    },
  },
}
```

`selectedArea.appearance.styles`では、[利用可能なエリア](window-mover-areas.md)の種類ごとにエリアの色を変更できます。
