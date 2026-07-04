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


## 必要環境

- macOS 14 以降
- Swift 6 toolchain(Xcode または Command Line Tools)


## ドキュメント

- TODO: JINRAI(迅雷)
- TODO: Deepwiki


## 開発者向け

```bash
swift build          # ビルド
swift test           # ユニットテスト(JinraiCore の純粋ロジック)
./scripts/make-app.sh && open .build/Jinrai.app   # 実機確認
```

### アーキテクチャ

| ターゲット | 内容 |
| --- | --- |
| `CGSPrivate` | 非公開 CGS / AX API の extern 宣言(C ヘッダのみ) |
| `JinraiCore` | 純粋ロジック(幾何・オクルージョン・方向スコアリング・キー割当・設定ビルダー)。Foundation + CGRect のみに依存し、全ユニットテストの対象 |
| `JinraiPlatform` | macOS API 層(AXUIElement / CGWindowList / CGEventTap / Carbon Hotkey / overlay NSWindow / CGS) |
| `Jinrai` | 実行ターゲット。機能モジュール(Features/)と結線(AppDelegate = 元 init.lua 相当) |

座標系は内部を CG/AX 準拠の top-left 原点に統一し、NSWindow/NSScreen との境界(`ScreenUtil`)でのみ変換する。

### ビルドと起動

```bash
./scripts/make-app.sh          # swift build + .app 組み立て + ad-hoc 署名
open .build/Jinrai.app
```

開発中は以下のワンライナーで確実に再起動できる。

```bash
pkill -x Jinrai && ./scripts/make-app.sh && open .build/Jinrai.app
```


初回起動時に**アクセシビリティ権限**を求められる。システム設定 → プライバシーとセキュリティ → アクセシビリティで Jinrai を許可すると機能が有効になる。

> [!WARNING]
> ad-hoc 署名は再ビルドで署名が変わり、アクセシビリティ許可が剥がれることがある。
> その場合は `tccutil reset Accessibility com.tadashi-aikawa.jinrai` を実行してから再許可する。

メニューバーの ⚡ アイコン →「設定を再読込」で反映できる。


## ライセンス

MIT
