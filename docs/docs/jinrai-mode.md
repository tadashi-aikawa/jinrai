---
icon: lucide/repeat
---

# JINRAI Mode

JINRAI Modeは、[Window Hints](window-hints.md)によるウィンドウ選択と、[Area Hints](area-hints.md)による移動先選択を交互に繰り返すモードです。

==TODO: 動画==


## 使い方

JINRAI Modeは次の方法で開始できます。

- [Window Hints](window-hints.md)の表示中に`triggers.windowHints.key`を押す
- [Application Hints](application-hints.md)の表示中に`triggers.applicationHints.key`を押す
- [Window Hints](window-hints.md)の`navigation.applicationHints.jinraiMode`を有効にしてApplication Hintsを開く
- [Area Hints](area-hints.md)の表示中に`triggers.areaHints.key`を押す
- [Area Hints](area-hints.md)の`jinraiMode.hotkey`を押す

[Window Hints](window-hints.md)から開始した場合は、ウィンドウを選択すると移動先の候補が開きます。移動先を選択すると[Window Hints](window-hints.md)へ戻り、次のウィンドウを続けて選べます。

`escape`、候補外のクリック、または表示中のホットキーをもう一度押して操作をキャンセルすると、JINRAI Modeも終了します。

## 設定

[全設定](configuration.md)に、JINRAI Modeの全項目、デフォルト値、各項目の説明を掲載しています。

`position`は`activeWindow`または`activeDisplay`から指定します。
それぞれ、アクティブウィンドウ中央またはアクティブディスプレイ中央にロゴなどを表示します。

各`animation`には次の設定を指定できます。

| 設定 | 説明 |
| --- | --- |
| `fade` | `true`の場合は新しい表示をフェードインし、切り替え前の表示をフェードアウトします。 |
| `scale` | アニメーション開始時の倍率です。`1.0`へ変化します。0より大きい値を指定します。 |
| `duration` | アニメーション時間（秒）です。`0`を指定すると即時に最終状態を表示します。 |
| `easing` | 補間方式です。`linear`、`easeOut`、`easeInOut`から指定します。 |

### 機能間を直接移動

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

JINRAI Modeの開始キーや戻るキーは、同じ画面で使うエリアキーやアクションキーと重複させないでください。`K`と`KD`のような、一方がもう一方の先頭に一致する組み合わせも使用できません。
