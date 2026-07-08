---
icon: lucide/repeat
---

# JINRAI Mode

JINRAI Modeは、[Window Hints](window-hints.md)によるウィンドウ選択と、[Area Hints](area-hints.md)による移動先選択を交互に繰り返すモードです。

## 使い方

JINRAI Modeは次の方法で開始できます。

- [Window Hints](window-hints.md)の表示中に`triggers.windowHints.key`を押す
- [Application Hints](application-hints.md)の表示中に`triggers.applicationHints.key`を押す
- [Window Hints](window-hints.md)の`navigation.applicationHints.jinraiMode`を有効にしてApplication Hintsを開く
- [Window Hints](window-hints.md)の`navigation.windowLayouts.jinraiMode`を有効にしてWindow Layoutsを開く
- [Area Hints](area-hints.md)の表示中に`triggers.areaHints.key`を押す
- [Area Hints](area-hints.md)の`jinraiMode.hotkey`を押す

[Window Hints](window-hints.md)から開始した場合は、ウィンドウを選択すると移動先の候補が開きます。移動先を選択すると[Window Hints](window-hints.md)へ戻り、次のウィンドウを続けて選べます。

`escape`、候補外のクリック、または表示中のホットキーをもう一度押して操作をキャンセルすると、JINRAI Modeも終了します。

## 基本設定

[全設定](configuration.md)に、JINRAI Modeの全項目、デフォルト値、各項目の説明を掲載しています。

```json
"jinraiMode": {
  "triggers": {
    "windowHints": { "key": "space" },
    "applicationHints": { "key": "space" },
    "areaHints": { "key": "space" }
  }
}
```

`triggers`には、各機能の表示中にJINRAI Modeを開始するキーを指定します。指定したキーだけが有効になります。

このほかの開始方法である`navigation.applicationHints.jinraiMode`は[Application Hints](application-hints.md#from-window-hints)、`navigation.windowLayouts.jinraiMode`は[Window Layouts](window-layouts.md#window-hints)、`jinraiMode.hotkey`は[Area Hints](area-hints.md#jinrai-mode)を参照してください。

## 演出

JINRAI Mode中は、**ロゴ**、**キャラクター画像**、**COMBOテキスト**の3つの演出を表示できます。デフォルトで有効なのはロゴだけです。

### ロゴ

```json
"jinraiMode": {
  "logo": {
    "enabled": true,
    "size": 480,
    "alpha": 0.25
  }
}
```

JINRAI Mode中、JINRAIロゴを表示し続けます。

### キャラクター画像

JINRAI Mode中に選択操作をするたびにcombo数が1ずつ増えます。`combo.character`を有効にすると、combo数に応じたキャラクター画像を表示します。combo数はJINRAI Modeを終了するとリセットされます。

```json
"jinraiMode": {
  "combo": {
    "character": {
      "enabled": true,
      "alpha": 0.7
    }
  }
}
```

画像はデフォルトでは同梱のものを使用します。`images`に画像パスの配列を指定すると、同梱画像の代わりに使用します。

```json
"jinraiMode": {
  "combo": {
    "character": {
      "enabled": true,
      "images": [
        "~/Pictures/jinrai-start.png",
        "~/Pictures/jinrai-combo1.png",
        "~/Pictures/jinrai-combo2.png"
      ]
    }
  }
}
```

- 1枚だけ指定した場合は、すべてのcombo数で同じ画像を表示します。
- 2枚以上指定した場合は、0枚目を開始直後(combo数0)に表示し、1枚目以降をcombo数に応じた順番で巡回します。

### COMBOテキスト

`combo.text`を有効にすると、combo数を`N COMBO!`のテキストで表示します。開始直後(combo数0)は表示されません。

```json
"jinraiMode": {
  "combo": {
    "text": {
      "enabled": true,
      "alpha": 0.7
    }
  }
}
```

## 位置とアニメーション {#position-and-animation}

`position`は、ロゴ・キャラクター画像・COMBOテキストを表示する中心位置です。

| 値 | 説明 |
| --- | --- |
| `activeWindow` | アクティブウィンドウの中央に表示します。 |
| `activeDisplay` | アクティブディスプレイの中央に表示します。 |

`logo`、`combo.character`、`combo.text`には、それぞれ表示切り替え時の`animation`を指定できます。

| 設定 | 説明 |
| --- | --- |
| `fade` | `true`の場合は新しい表示をフェードインし、切り替え前の表示をフェードアウトします。 |
| `scale` | アニメーション開始時の倍率です。`1.0`へ変化します。0より大きい値を指定します。 |
| `duration` | アニメーション時間（秒）です。`0`を指定すると即時に最終状態を表示します。 |
| `easing` | 補間方式です。`linear`、`easeOut`、`easeInOut`から指定します。 |

## 機能間を直接移動

[Area Hints](area-hints.md)の表示中にウィンドウを選び直すキーも設定できます。

```json
"areaHints": {
  "navigation": {
    "windowHints": {
      "key": "space"
    }
  }
}
```

このキーは通常の操作でも利用できます。JINRAI Mode中に使った場合は、モードを終了せず[Window Hints](window-hints.md)へ戻ります。

JINRAI Modeの開始キーや戻るキーは、同じ画面で使うエリアキーやアクションキーと重複できません。詳細は[Area Hints](area-hints.md#key-constraints)の「キーの制約」を参照してください。
