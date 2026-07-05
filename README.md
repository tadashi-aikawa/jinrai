# jinrai

<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.png" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>思考の速度で素早くウィンドウ操作を行うmacOS用ツール</div>
    </p>
    <p>
        <a href="https://github.com/tadashi-aikawa/jinrai/releases/latest"><img src="https://img.shields.io/github/release/tadashi-aikawa/jinrai" alt="release" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml"><img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE"><img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" /></a>
    </p>
</div>


## 対応環境

- macOS 15 以降
    - 動作確認は macOS 26.5.1 のみ


## インストール

### Homebrew(推奨)

```bash
brew install tadashi-aikawa/tap/jinrai
```

### 手動

1. [Releases](https://github.com/tadashi-aikawa/jinrai/releases/latest) から `JINRAI-x.y.z.zip` をダウンロード
2. 展開して `JINRAI.app` を `/Applications` へ移動

#### 手動インストールの初回起動時 (Gatekeeper対策)

JINRAI は自己署名(未公証)アプリのため、手動インストール時は初回起動がブロックされる。
macOS 15 以降は「右クリック → 開く」のバイパスが廃止されているため、以下の手順で許可する。

1. `JINRAI.app` をダブルクリック → 「開けませんでした」ダイアログで「完了」
2. システム設定 → プライバシーとセキュリティ → 下部の「"JINRAI" は…」の **「このまま開く」** をクリック

代替手段: `xattr -dr com.apple.quarantine /Applications/JINRAI.app`(Homebrew 経由なら不要)

### 権限

初回起動時に**アクセシビリティ権限**を求められる。システム設定 → プライバシーとセキュリティ → アクセシビリティで JINRAI を許可すると機能が有効になる。ウィンドウヒント機能を使う場合は**画面収録**の許可も必要。

### アップデート

- メニューバーの JINRAI アイコン → **「アップデートを確認…」** から更新できる(更新後は自動で再起動)
- Homebrew 経由でインストールした場合は `brew upgrade --cask jinrai`


## ドキュメント

- TODO: JINRAI(迅雷)
- TODO: Deepwiki


## 開発者向け

### 必要環境

- Swift 6 toolchain(Xcode または Command Line Tools)

### コマンド

```bash
swift build          # ビルド
swift test           # ユニットテスト(JinraiCore の純粋ロジック)
./scripts/make-app.sh && open .build/Jinrai.app   # 実機確認
pkill -x Jinrai && ./scripts/make-app.sh && open .build/Jinrai.app  # 再起動
```

初回起動時に**アクセシビリティ権限**を求められる。システム設定 → プライバシーとセキュリティ → アクセシビリティで Jinrai を許可すると機能が有効になる。

> [!WARNING]
> ad-hoc 署名は再ビルドで署名が変わり、アクセシビリティ許可が剥がれることがある。
> その場合は `tccutil reset Accessibility com.tadashi-aikawa.jinrai` を実行してから再許可する。

### アーキテクチャ

| ターゲット | 内容 |
| --- | --- |
| `CGSPrivate` | 非公開 CGS / AX API の extern 宣言(C ヘッダのみ) |
| `JinraiCore` | 純粋ロジック(幾何・オクルージョン・方向スコアリング・キー割当・設定ビルダー)。Foundation + CGRect のみに依存し、全ユニットテストの対象 |
| `JinraiPlatform` | macOS API 層(AXUIElement / CGWindowList / CGEventTap / Carbon Hotkey / overlay NSWindow / CGS) |
| `Jinrai` | 実行ターゲット。機能モジュール(Features/)と結線(AppDelegate = 元 init.lua 相当) |

座標系は内部を CG/AX 準拠の top-left 原点に統一し、NSWindow/NSScreen との境界(`ScreenUtil`)でのみ変換する。

### リリース

GitHub Actions の [Release ワークフロー](.github/workflows/release.yml) を main ブランチで手動実行(workflow_dispatch)すると、
semantic-release が conventional commits から次バージョンを算出し、
ビルド → 自己署名 → zip 化 → タグ・GitHub Release 作成 → [homebrew-tap](https://github.com/tadashi-aikawa/homebrew-tap) の cask 更新まで自動で行われる。

```bash
gh workflow run Release
```

バージョンの決定ルールやリリースノートのセクション構成は [release.config.cjs](release.config.cjs) を参照。前回リリース以降にリリース対象のコミット(feat/fix など)が無い場合は何もせず終了する。

署名には自己署名証明書 `jinrai-dev` を使う(ad-hoc だとリリース毎に署名が変わり、更新のたびに TCC 許可が剥がれるため)。必要な GitHub Secrets:

| Secret | 内容 |
| --- | --- |
| `MACOS_CERT_P12_BASE64` | `jinrai-dev` 証明書(.p12)の base64。`base64 -i jinrai-dev.p12 \| pbcopy` |
| `MACOS_CERT_PASSWORD` | .p12 のエクスポートパスワード |
| `TAP_GITHUB_TOKEN` | homebrew-tap 更新用 fine-grained PAT(homebrew-tap リポジトリのみ・Contents: Read and write) |

`jinrai-dev` 証明書は Keychain Access → 証明書アシスタント → 「証明書を作成…」で作る(自己署名ルート / コード署名 / 有効期限は 3650 日等に延長推奨)。秘密鍵ごと .p12 で書き出して Secrets に登録する。証明書を作り直すと TCC 許可が剥がれるので注意。


## ライセンス

MIT
