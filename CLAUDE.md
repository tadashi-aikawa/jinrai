# CLAUDE.md

## コードベースの全体像

macOS 常駐(メニューバー)のウィンドウ操作ツール。Hammerspoon 製からの移行で、`元 xxx.lua` のコメントは旧実装との対応を示す。SwiftPM の4ターゲット構成で、依存方向は上から下のみ:

- **`Sources/Jinrai`(executable)**: エントリポイント。`AppDelegate` が設定を読み、セクションが存在する機能だけ `Features/` から起動して束ねる。`Features/` は機能単位(Window Hints / Area Hints / Application Hints / Window Mover / Window Layouts / JINRAI Mode / Focus Border / Focus Back / Updater)で、Core のロジックと Platform の API を組み合わせる配線層
- **`Sources/JinraiPlatform`**: macOS API 層(AppKit / AX / Carbon / ScreenCaptureKit / SkyLight)。要注意部品は `EventTap`(モーダル系機能で1本共有。下の鉄則参照)、`WindowRegistry`(AX 要素キャッシュ。別 Space フォーカスの要)、`WindowServerFocus`(SLPS 経由の front process 切替)、`OverlayPanel` / `OverlayWindow`
- **`Sources/JinraiCore`**: 純粋ロジック層(値型のみ、AppKit 非依存)。ヒント配置・キー割当・レイアウト計画・方向スコアリング等。`Config/` に config.jsonc のスキーマ(JSONC パーサ・deepMerge・ディスプレイ構成別 profiles の解決を含む)
- **`Sources/CGSPrivate`**: 非公開 CGS / AX API の extern 宣言のみの C ターゲット

設定は `~/.config/jinrai/config.jsonc`($XDG_CONFIG_HOME 尊重)。機能はセクションの存在で有効化。`swift run JINRAI --check-config` で読込確認できる。

テストは `Tests/JinraiCoreTests` のみ(= ユニットテストの主戦場は Core 層。Platform / Features はテスト対象外なので実機確認が必要)。`swift build` / `swift test` で回る。

リリースは GitHub Actions の release.yml(workflow_dispatch、main のみ)→ semantic-release が conventional commits からバージョン算出(v1 までは breaking も minor。feat/build/style/perf → minor、fix/refactor → patch)→ 自己署名(jinrai-dev 固定。TCC 許可の維持のため)で .app を zip 化して Releases へ → `update_tap.sh` が homebrew-tap の cask を更新。アプリ内 Updater は Releases API を見て zip を差し替える。

`docs/` はユーザードキュメント(zensical)、`site/` はプロモサイト(Astro)。docs.yml が両方をビルド・マージして GitHub Pages へ配備する。

## ウィンドウ z-order / フォーカス操作の鉄則(実機検証で確立)

- `kAXRaiseAction` は非アクティブアプリのウィンドウより前面に出せるが、**現アクティブアプリのウィンドウには勝てない**。複数ウィンドウを前面化するときは、先にフォーカス対象を `WindowServerFocus.focus`(SLPS は WindowServer 側で同期的に front process を切り替える)+ AX focus でアクティブ化して前面権を奪い、その後に残りを AXRaise する。
- `activate()` や SLPS の front process 化を**複数アプリへ連続発行してはいけない**。front になったアプリが非同期で自分のウィンドウを raise し直し、後続の明示的な raise を上書きする(Chrome 等の重いアプリで顕著)。非フォーカス対象には AXRaise のみを使う。
- キー入力が必要な自前パネルは `.nonactivatingPanel`(`OverlayPanel`)を使い、`NSApp.activate` しない。アプリをアクティブ化すると、パネルを閉じたときに macOS が直前のアクティブアプリへアクティブ状態を非同期に返し、そのウィンドウが raise されて直後のレイアウト適用などの z-order を壊す。

## モーダル入力捕捉(EventTap)の鉄則(実機検証で確立)

- CGEventTap を**破棄してから次の tap を作るまでの間はキーが前面アプリへ素通りする**(tap のルーティングは WindowServer 側で行われ、アプリのメインスレッドが同期実行中でも配送される)。モーダル系機能(Window Hints / Area Hints / Application Hints / Layouts ピッカー)は `EventTap` を1本共有し、遷移では stop→start ではなくハンドラの張り替えで受け渡す。`stop()` は破棄を次の run loop turn へ遅延し、その間のキーを握りつぶす(遷移先の `start()` が予約を取り消す)。
- `postKeyStroke` の合成キー(Space 移動の Ctrl+数字等)は session tap を通過するため、tap が生きたまま投稿すると自分で消費してしまう。`eventSourceUserData` のマーカーで自前イベントを識別し、tap では無条件に素通しする。
- `stop()` の遅延破棄が守れるのは**同一 run loop turn 内の同期遷移だけ**。スリープやウィンドウ出現待ちを挟んで画面を開き直す遷移(detach 後の Area Hints 再表示等)では、`stop()` の後に `holdKeysForNextStart()` で tap を維持してキーを保持し、開いた側が `drainHeldKeyEvents()` で流し込む(タイムアウト付き。start() が来ないままキーボードが死ぬのを防ぐ)。モーダルを開いたまま待つ場合(Application Hints のウィンドウ出現待ち)はハンドラ側でキーを溜め、次画面へは `stashKeyEvents()` で持ち越し、アプリ本体へは `postKeyEvents(_:toPid:)` で再送する。モーダル中に押されたキーは**捨てずにどこかへ届ける**のが原則。

## デバッグの進め方

- z-order 系の不具合は推測で直さない。単発では動く API が連続実行や特定のアクティブアプリ状態で壊れることがあるため、`CGWindowListCopyWindowInfo` の Z順ダンプで before/after を取り、失敗ケースを再現する小さなハーネスで実機検証してから修正する(ステータスメニューにも Z順ダンプ機能あり)。

## コミット

- Conventional Commits 形式で日本語で書く(release.yml のバージョン算出に使われる)
- AI Agent (owlery) がコミットする場合は `--author="<名前> <slug@owlery.local>"` で author を自分の Agent 名にする(committer はデフォルトのまま)
