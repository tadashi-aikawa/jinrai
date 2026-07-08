# CLAUDE.md

## ウィンドウ z-order / フォーカス操作の鉄則(実機検証で確立)

- `kAXRaiseAction` は非アクティブアプリのウィンドウより前面に出せるが、**現アクティブアプリのウィンドウには勝てない**。複数ウィンドウを前面化するときは、先にフォーカス対象を `WindowServerFocus.focus`(SLPS は WindowServer 側で同期的に front process を切り替える)+ AX focus でアクティブ化して前面権を奪い、その後に残りを AXRaise する。
- `activate()` や SLPS の front process 化を**複数アプリへ連続発行してはいけない**。front になったアプリが非同期で自分のウィンドウを raise し直し、後続の明示的な raise を上書きする(Chrome 等の重いアプリで顕著)。非フォーカス対象には AXRaise のみを使う。
- キー入力が必要な自前パネルは `.nonactivatingPanel`(`OverlayPanel`)を使い、`NSApp.activate` しない。アプリをアクティブ化すると、パネルを閉じたときに macOS が直前のアクティブアプリへアクティブ状態を非同期に返し、そのウィンドウが raise されて直後のレイアウト適用などの z-order を壊す。

## デバッグの進め方

- z-order 系の不具合は推測で直さない。単発では動く API が連続実行や特定のアクティブアプリ状態で壊れることがあるため、`CGWindowListCopyWindowInfo` の Z順ダンプで before/after を取り、失敗ケースを再現する小さなハーネスで実機検証してから修正する(ステータスメニューにも Z順ダンプ機能あり)。
