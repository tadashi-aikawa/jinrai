---
icon: lucide/zap
---

<div align="center">
    <h1>JINRAI</h1>
    <img src="./attachments/jinrai.svg" width="256" />
    <h3>迅雷</h3>
    <p>『思考の速度でウィンドウ操作を』</p>
    <p>
        <a href="https://github.com/tadashi-aikawa/jinrai/releases/latest"><img src="https://img.shields.io/github/release/tadashi-aikawa/jinrai" alt="release" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml"><img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE"><img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" /></a>
    </p>
    <p><a href="/jinrai/">🌐 プロモーションサイト</a></p>
</div>

---

JINRAIは、ウィンドウを素早く選択・移動できるmacOSの常駐アプリです。

## 主な機能

| 機能 | 説明 |
| --- | --- |
| [Window Hints](window-hints.md) | ウィンドウに表示したキーヒントから、切り替え先のウィンドウを選択します。別のSpaceや他のウィンドウに隠れたウィンドウも候補にできます。 |
| [Application Hints](application-hints.md) | 固定キーからアプリを起動、または新しいウィンドウを作成します。 |
| [Area Hints](area-hints.md) | 画面上に表示したエリアとキーヒントから、ウィンドウの移動先を選択します。 |
| [Window Mover](window-mover.md) | ホットキーでウィンドウを別ディスプレイ、空き領域、指定した画面領域へ移動します。 |
| [Window Layouts](window-layouts.md) | 定義済みレイアウトへ複数のウィンドウを一括配置します。 |
| [JINRAI Mode](jinrai-mode.md) | Window HintsとArea Hintsを交互に連続実行します。 |
| [Focus Border](focus-border.md) | フォーカスしたウィンドウを一時的な枠線で強調します。 |
| [Focus Back](focus-back.md) | 直前に使用していたウィンドウへ戻ります。 |

## はじめる

[セットアップ](setup.md)では、JINRAIのインストール、権限の許可、設定ファイル、アップデート方法を説明します。
各機能の使い方と設定は、上の表の各ページを参照してください。

## リファレンス

| ページ | 内容 |
| --- | --- |
| [全設定](configuration.md) | 全機能の設定項目、デフォルト値、各項目の説明です。 |
| [ディスプレイ別名](display-aliases.md) | ディスプレイUUIDへ付ける任意の別名です。 |
| [プロファイル](profiles.md) | 接続ディスプレイによる設定の切り替えです。 |
| [利用可能なエリア](window-mover-areas.md) | ウィンドウの移動先に指定できるエリアの一覧です。 |
| [macOS Native Tabs](macos-native-tabs.md) | macOSネイティブタブを使うアプリのウィンドウ追跡の補正です。 |

## 関連リンク

- [GitHub](https://github.com/tadashi-aikawa/jinrai)
- [Deep Wiki](https://deepwiki.com/tadashi-aikawa/jinrai)

## ライセンス

[MIT License](https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE)
