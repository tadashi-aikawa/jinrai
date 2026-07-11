<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.png" width="256" />
    <h3>迅雷</h3>
    <p>思考の速度で素早くウィンドウ操作を行うmacOS用ツール</p>
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
brew install --cask tadashi-aikawa/tap/jinrai
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

初回起動時に**アクセシビリティ権限**を求められる。システム設定 → プライバシーとセキュリティ → アクセシビリティで JINRAI を許可すると機能が有効になる。ウィンドウヒントで隠れたウィンドウのプレビューを表示する場合は**画面収録**の許可も必要。

### アップデート

- メニューバーの JINRAI アイコン → **「アップデートを確認…」** から更新できる(更新後は自動で再起動)
- Homebrew 経由でインストールした場合は `brew upgrade --cask jinrai`


## ドキュメント

- [プロモーションサイト](https://tadashi-aikawa.github.io/jinrai/)
- [JINRAI(迅雷)](https://tadashi-aikawa.github.io/jinrai/docs/)
- [Deep Wiki](https://deepwiki.com/tadashi-aikawa/jinrai)


## 開発者向け

### 必要環境

- Swift 6 toolchain(Xcode または Command Line Tools)

### コマンド

```bash
# ビルド
swift build

# ユニットテスト(JinraiCore の純粋ロジック)
swift test

# 実機確認
./scripts/make-app.sh && open .build/JINRAI.app
# 実機 再起動
pkill -x JINRAI && ./scripts/make-app.sh && open .build/JINRAI.app
# 実機 再起動 (ログを参照しながら)
pkill -x JINRAI && ./scripts/make-app.sh && open .build/JINRAI.app --stdout /tmp/jinrai.out --stderr /tmp/jinrai.err && tail -f /tmp/jinrai.out /tmp/jinrai.err
```

初回起動時に**アクセシビリティ権限**を求められる。システム設定 → プライバシーとセキュリティ → アクセシビリティで JINRAI を許可すると機能が有効になる。

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

[Release ワークフロー](https://github.com/tadashi-aikawa/jinrai/actions/workflows/release.yml) を実行する。

#### 前提条件

以下のGitHub Secretsが設定されていること。


| Secret | 内容 |
| --- | --- |
| `MACOS_CERT_P12_BASE64` | `jinrai-dev` 証明書(.p12)の base64。`base64 -i jinrai-dev.p12 \| pbcopy` |
| `MACOS_CERT_PASSWORD` | .p12 のエクスポートパスワード |
| `TAP_GITHUB_TOKEN` | homebrew-tap 更新用 fine-grained PAT(homebrew-tap リポジトリのみ・Contents: Read and write) |


## ライセンス

MIT
