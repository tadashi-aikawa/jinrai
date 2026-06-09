# Window Mover

Window Moverは、アクティブウィンドウの位置や大きさをホットキーまたはエリア選択から変更する機能です。

## ホットキーを設定

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

## コマンド

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

切り替える比率は変更できます。

```lua
window_mover = {
  behavior = {
    cycle = {
      horizontalRatios = { 1 / 2, 1 / 3, 2 / 3 },
      verticalRatios = { 1 / 2, 1 / 3, 2 / 3 },
    },
  },
}
```

### 決まったサイズへ配置

次のコマンドは、名前に対応する[利用可能なエリア](#available-areas)へ直接移動します。

| サイズ | コマンド |
| --- | --- |
| 横または縦の2分割 | `halfLeft`、`halfHorizontalCenter`、`halfRight`、`halfTop`、`halfVerticalCenter`、`halfBottom` |
| 横または縦の3分割 | `thirdLeft`、`thirdHorizontalCenter`、`thirdRight`、`thirdTop`、`thirdVerticalCenter`、`thirdBottom` |
| 横または縦の4分割 | `quarterLeft`、`quarterHorizontalLeftCenter`、`quarterHorizontalRightCenter`、`quarterRight`、`quarterTop`、`quarterVerticalTopCenter`、`quarterVerticalBottomCenter`、`quarterBottom` |
| 画面の4分割 | `quarterTopLeft`、`quarterTopRight`、`quarterBottomLeft`、`quarterBottomRight` |
| 画面の6分割 | `sixthTopLeft`、`sixthTopCenter`、`sixthTopRight`、`sixthBottomLeft`、`sixthBottomCenter`、`sixthBottomRight` |
| 横または縦の3分の2 | `twoThirdsLeft`、`twoThirdsHorizontalCenter`、`twoThirdsRight`、`twoThirdsTop`、`twoThirdsVerticalCenter`、`twoThirdsBottom` |

## 移動後のカーソル

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
| `selectedArea.windowHints.key` | エリア選択を閉じ、Window Hintsを開くキーです。 |
| `selectedArea.hints.show` | エリアとキーを画面上に表示するかを指定します。`false`でもキー入力は有効です。 |

選択画面は`escape`、候補外のクリック、または起動に使ったホットキーで閉じられます。

`freeArea`を選ぶと、選択した時点のウィンドウ配置から最大の空き領域を探します。空き領域がない場合、ウィンドウは移動せず選択画面が維持されます。

同じディスプレイ内のエリアキー、アクションキー、Window Hintsへ戻るキーは重複させないでください。`B`と`B1`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。

## 選択画面の見た目

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

`selectedArea.appearance.styles`では、`full`、`twoThirds`、`half`、`third`、`quarter`、`sixth`、`free`の種類ごとにエリアの色を変更できます。

<a id="available-areas"></a>

## 利用可能なエリア

| アイコン | エリア | 位置 | サイズ |
| --- | --- | --- | --- |
| <img src="./attachments/window-mover/areas/freeArea.svg" alt="freeArea" width="48"> | `freeArea` | 選択したディスプレイの最大空き領域 | 他の可視な標準ウィンドウと重ならない最大サイズ |
| <img src="./attachments/window-mover/areas/full.svg" alt="full" width="48"> | `full` | ディスプレイ全体 | ディスプレイ全体 |
| <img src="./attachments/window-mover/areas/halfLeft.svg" alt="halfLeft" width="48"> | `halfLeft` | 左端 | 横幅 1/2、高さ全体 |
| <img src="./attachments/window-mover/areas/halfHorizontalCenter.svg" alt="halfHorizontalCenter" width="48"> | `halfHorizontalCenter` | 横方向中央 | 横幅 1/2、高さ全体 |
| <img src="./attachments/window-mover/areas/halfRight.svg" alt="halfRight" width="48"> | `halfRight` | 右端 | 横幅 1/2、高さ全体 |
| <img src="./attachments/window-mover/areas/halfTop.svg" alt="halfTop" width="48"> | `halfTop` | 上端 | 横幅全体、高さ 1/2 |
| <img src="./attachments/window-mover/areas/halfVerticalCenter.svg" alt="halfVerticalCenter" width="48"> | `halfVerticalCenter` | 縦方向中央 | 横幅全体、高さ 1/2 |
| <img src="./attachments/window-mover/areas/halfBottom.svg" alt="halfBottom" width="48"> | `halfBottom` | 下端 | 横幅全体、高さ 1/2 |
| <img src="./attachments/window-mover/areas/thirdLeft.svg" alt="thirdLeft" width="48"> | `thirdLeft` | 左端 | 横幅 1/3、高さ全体 |
| <img src="./attachments/window-mover/areas/thirdHorizontalCenter.svg" alt="thirdHorizontalCenter" width="48"> | `thirdHorizontalCenter` | 横方向中央 | 横幅 1/3、高さ全体 |
| <img src="./attachments/window-mover/areas/thirdRight.svg" alt="thirdRight" width="48"> | `thirdRight` | 右端 | 横幅 1/3、高さ全体 |
| <img src="./attachments/window-mover/areas/thirdTop.svg" alt="thirdTop" width="48"> | `thirdTop` | 上端 | 横幅全体、高さ 1/3 |
| <img src="./attachments/window-mover/areas/thirdVerticalCenter.svg" alt="thirdVerticalCenter" width="48"> | `thirdVerticalCenter` | 縦方向中央 | 横幅全体、高さ 1/3 |
| <img src="./attachments/window-mover/areas/thirdBottom.svg" alt="thirdBottom" width="48"> | `thirdBottom` | 下端 | 横幅全体、高さ 1/3 |
| <img src="./attachments/window-mover/areas/quarterLeft.svg" alt="quarterLeft" width="48"> | `quarterLeft` | 左端 | 横幅 1/4、高さ全体 |
| <img src="./attachments/window-mover/areas/quarterHorizontalLeftCenter.svg" alt="quarterHorizontalLeftCenter" width="48"> | `quarterHorizontalLeftCenter` | 横方向左中央 | 横幅 1/4、高さ全体 |
| <img src="./attachments/window-mover/areas/quarterHorizontalRightCenter.svg" alt="quarterHorizontalRightCenter" width="48"> | `quarterHorizontalRightCenter` | 横方向右中央 | 横幅 1/4、高さ全体 |
| <img src="./attachments/window-mover/areas/quarterRight.svg" alt="quarterRight" width="48"> | `quarterRight` | 右端 | 横幅 1/4、高さ全体 |
| <img src="./attachments/window-mover/areas/quarterTop.svg" alt="quarterTop" width="48"> | `quarterTop` | 上端 | 横幅全体、高さ 1/4 |
| <img src="./attachments/window-mover/areas/quarterVerticalTopCenter.svg" alt="quarterVerticalTopCenter" width="48"> | `quarterVerticalTopCenter` | 縦方向上中央 | 横幅全体、高さ 1/4 |
| <img src="./attachments/window-mover/areas/quarterVerticalBottomCenter.svg" alt="quarterVerticalBottomCenter" width="48"> | `quarterVerticalBottomCenter` | 縦方向下中央 | 横幅全体、高さ 1/4 |
| <img src="./attachments/window-mover/areas/quarterBottom.svg" alt="quarterBottom" width="48"> | `quarterBottom` | 下端 | 横幅全体、高さ 1/4 |
| <img src="./attachments/window-mover/areas/quarterTopLeft.svg" alt="quarterTopLeft" width="48"> | `quarterTopLeft` | 左上 | 横幅 1/2、高さ 1/2 |
| <img src="./attachments/window-mover/areas/quarterTopRight.svg" alt="quarterTopRight" width="48"> | `quarterTopRight` | 右上 | 横幅 1/2、高さ 1/2 |
| <img src="./attachments/window-mover/areas/quarterBottomLeft.svg" alt="quarterBottomLeft" width="48"> | `quarterBottomLeft` | 左下 | 横幅 1/2、高さ 1/2 |
| <img src="./attachments/window-mover/areas/quarterBottomRight.svg" alt="quarterBottomRight" width="48"> | `quarterBottomRight` | 右下 | 横幅 1/2、高さ 1/2 |
| <img src="./attachments/window-mover/areas/sixthTopLeft.svg" alt="sixthTopLeft" width="48"> | `sixthTopLeft` | 左上 | 横幅 1/3、高さ 1/2 |
| <img src="./attachments/window-mover/areas/sixthTopCenter.svg" alt="sixthTopCenter" width="48"> | `sixthTopCenter` | 中央上 | 横幅 1/3、高さ 1/2 |
| <img src="./attachments/window-mover/areas/sixthTopRight.svg" alt="sixthTopRight" width="48"> | `sixthTopRight` | 右上 | 横幅 1/3、高さ 1/2 |
| <img src="./attachments/window-mover/areas/sixthBottomLeft.svg" alt="sixthBottomLeft" width="48"> | `sixthBottomLeft` | 左下 | 横幅 1/3、高さ 1/2 |
| <img src="./attachments/window-mover/areas/sixthBottomCenter.svg" alt="sixthBottomCenter" width="48"> | `sixthBottomCenter` | 中央下 | 横幅 1/3、高さ 1/2 |
| <img src="./attachments/window-mover/areas/sixthBottomRight.svg" alt="sixthBottomRight" width="48"> | `sixthBottomRight` | 右下 | 横幅 1/3、高さ 1/2 |
| <img src="./attachments/window-mover/areas/twoThirdsLeft.svg" alt="twoThirdsLeft" width="48"> | `twoThirdsLeft` | 左端 | 横幅 2/3、高さ全体 |
| <img src="./attachments/window-mover/areas/twoThirdsHorizontalCenter.svg" alt="twoThirdsHorizontalCenter" width="48"> | `twoThirdsHorizontalCenter` | 横方向中央 | 横幅 2/3、高さ全体 |
| <img src="./attachments/window-mover/areas/twoThirdsRight.svg" alt="twoThirdsRight" width="48"> | `twoThirdsRight` | 右端 | 横幅 2/3、高さ全体 |
| <img src="./attachments/window-mover/areas/twoThirdsTop.svg" alt="twoThirdsTop" width="48"> | `twoThirdsTop` | 上端 | 横幅全体、高さ 2/3 |
| <img src="./attachments/window-mover/areas/twoThirdsVerticalCenter.svg" alt="twoThirdsVerticalCenter" width="48"> | `twoThirdsVerticalCenter` | 縦方向中央 | 横幅全体、高さ 2/3 |
| <img src="./attachments/window-mover/areas/twoThirdsBottom.svg" alt="twoThirdsBottom" width="48"> | `twoThirdsBottom` | 下端 | 横幅全体、高さ 2/3 |
| <img src="./attachments/window-mover/areas/fixedSizeCenter.svg" alt="fixedSizeCenter" width="48"> | `<width>x<height>Center` | ディスプレイ中央 | 固定サイズ。ディスプレイ内に収まるよう調整 |

エリア名の方角はディスプレイの向きにかかわらず変わりません。選択キーには1文字または2文字を使用できます。
