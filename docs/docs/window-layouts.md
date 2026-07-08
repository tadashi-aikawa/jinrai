---
icon: lucide/layout-grid
---

# Window Layouts

Window Layoutsは、あらかじめ定義したレイアウト(どのアプリのウィンドウを、どのディスプレイのどのエリアに置くか)を、ホットキー一発で一括適用する機能です。

いつもの作業で決まった位置に配置する複数のウィンドウを、一瞬で整列できます。

[全設定](configuration.md#window-layouts)に、Window Layoutsの全項目、デフォルト値、各項目の説明を掲載しています。

## レイアウトを定義する

`layouts`にレイアウト名をキーとして、ホットキーと配置対象ウィンドウの一覧を定義します。

```json
"windowLayouts": {
  "layouts": {
    "dev": {
      "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
      "windows": [
        {
          "bundleID": "com.google.Chrome",
          "screen": "37D8832A-2D66-02CA-B9F7-8F30A301B230",
          "area": "halfLeft"
        },
        { "bundleID": "dev.warp.Warp-Stable", "area": "halfRight" },
        { "bundleID": "md.obsidian", "area": "1200x900Center", "launch": true }
      ]
    },
    "meeting": {
      "hotkey": { "modifiers": ["ctrl", "alt"], "key": "2" },
      "windows": [
        { "bundleID": "us.zoom.xos", "area": "twoThirdsLeft" },
        { "bundleID": "com.apple.Notes", "area": "thirdRight" }
      ]
    }
  }
}
```

ホットキーを押すと、`windows`の各エントリにマッチしたウィンドウが指定エリアへ一括で移動します。

## ウィンドウのマッチ規則

各エントリは次の規則でウィンドウ1枚を特定します。

- `bundleID`(必須): アプリのbundle IDと完全一致で照合します。
- `titleGlob`(任意): ウィンドウタイトルをglobパターンで絞り込みます。`*`は任意の文字列、`?`は任意の1文字にマッチします。省略するとタイトルを問いません。
- 複数のウィンドウがマッチする場合は、最前面に近いものが選ばれます。
- 先のエントリで配置したウィンドウは、後のエントリのマッチ対象から除外されます。同一アプリの別ウィンドウを`titleGlob`で振り分けたり、同じ条件を2回書いて前面から順に2枚配置したりできます。

```json
"windows": [
  { "bundleID": "com.google.Chrome", "titleGlob": "*GitHub*", "area": "halfLeft" },
  { "bundleID": "com.google.Chrome", "titleGlob": "*Gmail*", "area": "quarterTopRight" }
]
```

マッチしないエントリはスキップされます。レイアウトに含まれないウィンドウには一切触りません。

## 配置先の指定

- `area`(必須): [利用可能なエリア](window-mover-areas.md)の名前を指定します(`freeArea`は使用不可)。`1200x900Center`のような固定サイズ中央配置も指定できます。
- `screen`(任意): 配置先ディスプレイのUUIDを指定します。省略時、またはそのディスプレイが未接続のときは、メインディスプレイに配置します。UUIDの確認方法は[Area Hints](area-hints.md#display-uuid)を参照してください。

接続ディスプレイによってレイアウト自体を切り替えたい場合は、[プロファイル](configuration.md#profiles)と組み合わせてください。

## 未起動アプリの起動 (launch)

`launch`を`true`にすると、対象アプリが未起動のときに起動し、ウィンドウの出現を待ってから配置します。
`false`(デフォルト)の場合、未起動アプリのエントリはスキップされます。

出現を待つ最大時間は`windowWaitTimeout`(デフォルト10秒)で変更できます。

!!! note
    同一アプリに対して複数のエントリで`launch`を指定しても、起動直後に現れるウィンドウは通常1枚のため、2枚目以降はタイムアウトまで待った後スキップされることがあります。

## 適用時の挙動

- 最小化されたウィンドウは、解除してから配置します。
- フルスクリーンのウィンドウは、フルスクリーンを自動で解除してから配置します。
- 適用後は、`windows`配列で最後にマッチしたエントリのウィンドウへフォーカスします。
- `windowMover.behavior.cursor.afterMove`が`true`(デフォルト)の場合、フォーカスしたウィンドウの中央へカーソルも移動します。
