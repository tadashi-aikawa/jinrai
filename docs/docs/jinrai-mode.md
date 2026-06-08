# JinraiMode

JinraiModeは、[Window Hints](window-hints.md)によるウィンドウ選択と、[Window Mover](window-mover.md)による移動先選択を交互に繰り返すモードです。

## 使い方

JinraiModeは次の方法で開始できます。

- Window Hintsの表示中に`triggers.windowHints.key`を押す
- Window Moverのエリア選択中に`triggers.windowMover.key`を押す
- Window Moverの`moveToSelectedAreaInJinraiMode`ホットキーを押す

Window Hintsから開始した場合は、ウィンドウを選択すると移動先の候補が開きます。移動先を選択するとWindow Hintsへ戻り、次のウィンドウを続けて選べます。

`escape`、候補外のクリック、または表示中のホットキーをもう一度押して操作をキャンセルすると、JinraiModeも終了します。

## 設定

```lua
jinrai_mode = {
  triggers = {
    windowHints = {
      key = "space",
    },
    windowMover = {
      key = "space",
    },
  },
  logo = {
    enabled = true,
    size = 480,
    alpha = 0.4,
  },
  combo = {
    character = {
      enabled = false,
      alpha = 0.5,
    },
    text = {
      enabled = false,
      alpha = 0.7,
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `triggers.windowHints.key` | Window Hintsの表示中にJinraiModeを開始するキーです。 |
| `triggers.windowMover.key` | 移動先の選択中にJinraiModeを開始するキーです。 |
| `logo.enabled` | JinraiMode中にJINRAIロゴを表示するかを指定します。 |
| `logo.size` | ロゴの大きさです。 |
| `logo.alpha` | ロゴの透明度です。 |
| `combo.character.enabled` | 操作を続けた回数に応じたキャラクター画像を表示するかを指定します。 |
| `combo.character.alpha` | キャラクター画像の透明度です。 |
| `combo.text.enabled` | 継続回数をCOMBOテキストで表示するかを指定します。 |
| `combo.text.alpha` | COMBOテキストの透明度です。 |

## 機能間を直接移動

Window Moverのエリア選択中にウィンドウを選び直すキーも設定できます。

```lua
window_mover = {
  selectedArea = {
    windowHints = {
      key = "space",
    },
  },
}
```

このキーは通常の操作でも利用できます。JinraiMode中に使った場合は、モードを終了せずWindow Hintsへ戻ります。

JinraiModeの開始キーや戻るキーは、同じ画面で使うエリアキーやアクションキーと重複させないでください。`K`と`KD`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。
