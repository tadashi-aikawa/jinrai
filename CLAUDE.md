# CLAUDE.md

## ウィンドウ z-order / フォーカス操作の鉄則(実機検証で確立)

- `kAXRaiseAction` は非アクティブアプリのウィンドウより前面に出せるが、**現アクティブアプリのウィンドウには勝てない**。複数ウィンドウを前面化するときは、先にフォーカス対象を `WindowServerFocus.focus`(SLPS は WindowServer 側で同期的に front process を切り替える)+ AX focus でアクティブ化して前面権を奪い、その後に残りを AXRaise する。
- `activate()` や SLPS の front process 化を**複数アプリへ連続発行してはいけない**。front になったアプリが非同期で自分のウィンドウを raise し直し、後続の明示的な raise を上書きする(Chrome 等の重いアプリで顕著)。非フォーカス対象には AXRaise のみを使う。
- キー入力が必要な自前パネルは `.nonactivatingPanel`(`OverlayPanel`)を使い、`NSApp.activate` しない。アプリをアクティブ化すると、パネルを閉じたときに macOS が直前のアクティブアプリへアクティブ状態を非同期に返し、そのウィンドウが raise されて直後のレイアウト適用などの z-order を壊す。

## モーダル入力捕捉(EventTap)の鉄則(実機検証で確立)

- CGEventTap を**破棄してから次の tap を作るまでの間はキーが前面アプリへ素通りする**(tap のルーティングは WindowServer 側で行われ、アプリのメインスレッドが同期実行中でも配送される)。モーダル系機能(Window Hints / Area Hints / Application Hints / Layouts ピッカー)は `EventTap` を1本共有し、遷移では stop→start ではなくハンドラの張り替えで受け渡す。`stop()` は破棄を次の run loop turn へ遅延し、その間のキーを握りつぶす(遷移先の `start()` が予約を取り消す)。
- `postKeyStroke` の合成キー(Space 移動の Ctrl+数字等)は session tap を通過するため、tap が生きたまま投稿すると自分で消費してしまう。`eventSourceUserData` のマーカーで自前イベントを識別し、tap では無条件に素通しする。
- `stop()` の遅延破棄が守れるのは**同一 run loop turn 内の同期遷移だけ**。スリープやウィンドウ出現待ちを挟んで画面を開き直す遷移(detach 後の Area Hints 再表示等)では、`stop()` の後に `holdKeysForNextStart()` で tap を維持してキーを保持し、開いた側が `drainHeldKeyEvents()` で流し込む(タイムアウト付き。start() が来ないままキーボードが死ぬのを防ぐ)。

## デバッグの進め方

- z-order 系の不具合は推測で直さない。単発では動く API が連続実行や特定のアクティブアプリ状態で壊れることがあるため、`CGWindowListCopyWindowInfo` の Z順ダンプで before/after を取り、失敗ケースを再現する小さなハーネスで実機検証してから修正する(ステータスメニューにも Z順ダンプ機能あり)。
