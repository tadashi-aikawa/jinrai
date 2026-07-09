---
icon: lucide/layout-grid
---

# Window Layouts

Window Layoutsは、あらかじめ定義したレイアウト(どのアプリのウィンドウを、どのディスプレイのどのエリアに置くか)を、ホットキー一発で一括適用する機能です。

いつもの作業で決まった位置に配置する複数のウィンドウを、一瞬で整列できます。

[全設定](configuration.md#window-layouts)に、Window Layoutsの全項目、デフォルト値、各項目の説明を掲載しています。

## レイアウトを定義する

`layouts`にレイアウトの一覧を配列で定義します。各レイアウトには`name`(必須・重複不可)と、ホットキーや配置対象ウィンドウの一覧を指定します。

```json
"displayAliases": {
  "desk": "37D8832A-2D66-02CA-B9F7-8F30A301B230"
},
"windowLayouts": {
  "layouts": [
    {
      "name": "dev",
      "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
      "unlistedWindows": "close",
      "windows": [
        {
          "bundleID": "com.google.Chrome",
          "screen": "desk",
          "area": "halfLeft"
        },
        { "bundleID": "dev.warp.Warp-Stable", "area": "halfRight" },
        { "bundleID": "md.obsidian", "area": "1200x900Center", "launch": true }
      ]
    },
    {
      "name": "meeting",
      "hotkey": { "modifiers": ["ctrl", "alt"], "key": "2" },
      "windows": [
        { "bundleID": "us.zoom.xos", "area": "twoThirdsLeft" },
        { "bundleID": "com.apple.Notes", "area": "thirdRight" }
      ]
    }
  ]
}
```

ホットキーを押すと、`windows`の各エントリにマッチしたウィンドウが指定エリアへ一括で移動します。

レイアウト個別の`hotkey`は任意です。省略したレイアウトは、次のピッカーからのみ呼び出せます(ピッカーへの導線も未設定の場合は設定エラーになります)。

## ピッカーで選択する

`windowLayouts.hotkey`を設定すると、レイアウトを検索して選択するモーダル(ピッカー)を開けます。
レイアウトごとにホットキーを覚えなくても、1つのホットキーからすべてのレイアウトを呼び出せます。

```json
"windowLayouts": {
  "hotkey": { "modifiers": ["ctrl", "alt"], "key": "l" },
  "layouts": [
    {
      "name": "dev",
      "description": "開発用: ブラウザ + ターミナル",
      "windows": [ /* ... */ ]
    },
    {
      "name": "meeting",
      "description": "会議用: Zoom + メモ",
      "windows": [ /* ... */ ]
    }
  ]
}
```

- レイアウトは`layouts`の記載順に表示されます
- 文字を入力すると、レイアウト名と`description`の部分一致(大文字小文字は無視)でインクリメンタルサーチされます
- ++up++ / ++down++(または ++ctrl+n++ / ++ctrl+p++)で選択行を移動し、++enter++ で選択したレイアウトを適用します
- ++esc++、画面クリック、ピッカーのホットキー再押下で閉じます
- `description`(任意)はピッカーの一覧に表示され、検索対象にもなります

## Window Hintsから開く {#window-hints}

`windowHints.navigation.windowLayouts.key`を設定すると、Window Hints表示中にレイアウト選択ピッカーへ切り替えられます。
Window Layouts専用のグローバルホットキーを増やさず、Window Hintsを起点にレイアウト適用できます。
`jinraiMode`を有効にすると、通常のWindow Hints表示からでもJINRAI Modeを開始してピッカーへ移れます。
レイアウト適用後はコンボを進めてWindow Hintsへ戻ります。

```json
"windowHints": {
  "navigation": {
    "windowLayouts": { "key": "l", "jinraiMode": true }
  }
},
"windowLayouts": {
  "layouts": [
    {
      "name": "dev",
      "description": "開発用: ブラウザ + ターミナル",
      "windows": [ /* ... */ ]
    }
  ]
}
```

## ウィンドウのマッチ規則

各エントリは次の規則でウィンドウを特定します。

- `bundleID`(必須): アプリのbundle IDと完全一致で照合します。
- `titleGlob`(任意): ウィンドウタイトルをglobパターンで絞り込みます。`*`は任意の文字列、`?`は任意の1文字にマッチします。省略するとタイトルを問いません。
- そのウィンドウにマッチしうるエントリがレイアウト内に1つだけの場合、マッチする**すべての**ウィンドウを同じ位置へ配置します(全取り)。
- 複数のエントリにマッチしうるウィンドウは、エントリの記述順に最前面に近いものから1枚ずつ配置します。先のエントリで配置したウィンドウは、後のエントリのマッチ対象から除外されます。同一アプリの別ウィンドウを`titleGlob`で振り分けたり、同じ条件を2回書いて前面から順に2枚配置したりできます。

```json
"windows": [
  { "bundleID": "com.google.Chrome", "titleGlob": "*GitHub*", "area": "halfLeft" },
  { "bundleID": "com.google.Chrome", "titleGlob": "*Gmail*", "area": "quarterTopRight", "focus": true }
]
```

マッチしないエントリはスキップされます。レイアウトに含まれないウィンドウには、`unlistedWindows`を指定しない限り一切触りません。

## 配置先の指定

- `area`(必須): [利用可能なエリア](window-mover-areas.md)の名前を指定します(`freeArea`は使用不可)。`1200x900Center`のような固定サイズ中央配置も指定できます。
- `screen`(任意): 配置先ディスプレイのUUIDまたは[ディスプレイ別名](display-aliases.md)を指定します。省略時、またはそのディスプレイが未接続のときは、そのウィンドウが現在いるディスプレイに配置します(最小化中などで判定できない場合はメインディスプレイ)。UUIDの確認方法は[Area Hints](area-hints.md#display-uuid)を参照してください。

接続ディスプレイによってレイアウト自体を切り替えたい場合は、[プロファイル](profiles.md)と組み合わせてください。

## ウィンドウが存在しないアプリの起動 (launch)

`launch`を`true`にすると、対象アプリのウィンドウが1枚も存在しないときにアプリを起動し、ウィンドウの出現を待ってから配置します。アプリが未起動の場合はもちろん、起動済みでもウィンドウが1枚もなければ再オープン(Dockアイコンのクリック相当)でウィンドウを開かせます。
`false`(デフォルト)の場合、ウィンドウが存在しないアプリのエントリはスキップされます。

出現を待つ最大時間は`windowWaitTimeout`(デフォルト10秒)で変更できます。

!!! note
    同一アプリに対して複数のエントリで`launch`を指定しても、起動直後に現れるウィンドウは通常1枚のため、2枚目以降はタイムアウトまで待った後スキップされることがあります。また、起動後の出現待ちで配置されるウィンドウは1エントリにつき1枚です(全取りは適用時にすでに表示されているウィンドウが対象)。

!!! note
    ウィンドウが存在するのに`titleGlob`に一致するウィンドウが無い場合は、launchは行われずスキップされます。また、再オープンで新規ウィンドウを開かないアプリでは、出現待ちがタイムアウトすることがあります。

## 定義外ウィンドウの扱い (unlistedWindows)

`unlistedWindows`で、現在のSpaceで表示されている標準ウィンドウのうち、レイアウトで実際に選ばれたウィンドウ**以外**の扱いを指定できます。

- `"close"`: 定義外のウィンドウをすべて閉じます。
- `{ "screen": <UUIDまたは別名(任意)>, "area": <エリア名> }`: 定義外のウィンドウをすべて指定位置へ一律配置します。`screen`省略時は各ウィンドウが現在いるディスプレイに配置するため、`{ "area": "full" }`で「残りは全部いまいるディスプレイの全面へ」といった指定ができます。
- 省略時は何もしません(定義外のウィンドウには一切触りません)。

```json
"layouts": [
  {
    "name": "dev",
    "unlistedWindows": { "screen": "desk", "area": "full" },
    "windows": [ /* ... */ ]
  }
]
```

`unlistedWindows`はレイアウト対象のマッチ数に関わらず適用されます(1枚もマッチしなくても実行されます)。一律配置はレイアウト対象の背面に置かれます(前面には出しません)。

`unlistedWindows`を指定していれば`windows`は省略できます。すべての標準ウィンドウが定義外扱いになるため、「全ウィンドウを閉じる」「全ウィンドウを一律配置する」といったレイアウトを定義できます(`windows`と`unlistedWindows`の両方を省略すると設定エラーです)。

```json
"layouts": [
  {
    "name": "clear",
    "hotkey": { "modifiers": ["ctrl", "alt"], "key": "0" },
    "unlistedWindows": "close"
  }
]
```

## 適用時の挙動

- 最小化されたウィンドウは、解除してから配置します。
- フルスクリーンのウィンドウは、フルスクリーンを自動で解除してから配置します。
- 適用後は、`focus: true`を指定したエントリのウィンドウへフォーカスします。`focus: true`は1レイアウトに1件だけ指定できます。
- `focus: true`を省略した場合、または指定したエントリにマッチするウィンドウが見つからない場合は、`windows`配列で最後にマッチしたエントリのウィンドウへフォーカスします。
- `windowMover.behavior.cursor.afterMove`が`true`(デフォルト)の場合、フォーカスしたウィンドウの中央へカーソルも移動します。
