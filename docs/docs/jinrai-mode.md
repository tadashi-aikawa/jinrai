# JinraiMode

JinraiModeは、[Window Hints](window-hints.md)によるウィンドウ選択と、[Window Mover](window-mover.md)による移動先選択を交互に繰り返すモードです。

## 使い方

JinraiModeは次の方法で開始できます。

- [Window Hints](window-hints.md)の表示中に`triggers.windowHints.key`を押す
- [Application Hints](application-hints.md)の表示中に`triggers.applicationHints.key`を押す
- [Window Mover](window-mover.md)のエリア選択中に`triggers.windowMover.key`を押す
- [Window Mover](window-mover.md)の`moveToSelectedAreaInJinraiMode`ホットキーを押す

[Window Hints](window-hints.md)から開始した場合は、ウィンドウを選択すると移動先の候補が開きます。移動先を選択すると[Window Hints](window-hints.md)へ戻り、次のウィンドウを続けて選べます。

`escape`、候補外のクリック、または表示中のホットキーをもう一度押して操作をキャンセルすると、JinraiModeも終了します。

## 設定

```lua
jinrai_mode = {
  position = "activeWindow",
  triggers = {
    windowHints = {
      key = "space",
    },
    applicationHints = {
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
    animation = {
      fade = true,
      scale = 1.0,
      duration = 0.16,
      easing = "linear",
    },
  },
  combo = {
    character = {
      enabled = false,
      alpha = 0.5,
      animation = {
        fade = true,
        scale = 1.18,
        duration = 0.16,
        easing = "linear",
      },
    },
    text = {
      enabled = false,
      alpha = 0.7,
      animation = {
        fade = true,
        scale = 1.0,
        duration = 0.16,
        easing = "linear",
      },
    },
  },
}
```

| 設定 | 説明 |
| --- | --- |
| `position` | ロゴ・キャラクター・COMBOテキストの中心位置です。`activeDisplay`（アクティブディスプレイ中央）または`activeWindow`（アクティブウィンドウ中央、デフォルト）を指定します。 |
| `triggers.windowHints.key` | [Window Hints](window-hints.md)の表示中にJinraiModeを開始するキーです。 |
| `triggers.applicationHints.key` | [Application Hints](application-hints.md)の表示中にJinraiModeを開始するキーです。 |
| `triggers.windowMover.key` | 移動先の選択中にJinraiModeを開始するキーです。 |
| `logo.enabled` | JinraiMode中にJINRAIロゴを表示するかを指定します。 |
| `logo.size` | ロゴの大きさです。 |
| `logo.alpha` | ロゴの透明度です。 |
| `logo.animation.*` | ロゴ表示時のアニメーションを指定します。 |
| `combo.character.enabled` | 操作を続けた回数に応じたキャラクター画像を表示するかを指定します。 |
| `combo.character.alpha` | キャラクター画像の透明度です。 |
| `combo.character.animation.*` | キャラクター切り替え時のアニメーションを指定します。 |
| `combo.text.enabled` | 継続回数をCOMBOテキストで表示するかを指定します。 |
| `combo.text.alpha` | COMBOテキストの透明度です。 |
| `combo.text.animation.*` | COMBOテキスト切り替え時のアニメーションを指定します。 |

各`animation`には次の設定を指定できます。

| 設定 | 説明 |
| --- | --- |
| `fade` | `true`の場合は新しい表示をフェードインし、切り替え前の表示をフェードアウトします。 |
| `scale` | アニメーション開始時の倍率です。`1.0`へ変化します。0より大きい値を指定します。 |
| `duration` | アニメーション時間（秒）です。`0`を指定すると即時に最終状態を表示します。 |
| `easing` | 補間方式です。`linear`、`easeOut`、`easeInOut`から指定します。 |

### 機能間を直接移動

[Window Mover](window-mover.md)のエリア選択中にウィンドウを選び直すキーも設定できます。

```lua
window_mover = {
  selectedArea = {
    windowHints = {
      key = "space",
    },
  },
}
```

このキーは通常の操作でも利用できます。JinraiMode中に使った場合は、モードを終了せず[Window Hints](window-hints.md)へ戻ります。

JinraiModeの開始キーや戻るキーは、同じ画面で使うエリアキーやアクションキーと重複させないでください。`K`と`KD`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。
