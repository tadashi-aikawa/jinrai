<div align="center">
    <h1>JINRAI</h1>
    <img src="./attachments/jinrai.svg" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>思考の速度で素早くウィンドウの切り替えや認識を行うためのHammerspoonスクリプト</div>
    </p>
    <p>
        <a href="https://github.com/tadashi-aikawa/jinrai/releases/latest"><img src="https://img.shields.io/github/release/tadashi-aikawa/jinrai" alt="release" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml"><img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE"><img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" /></a>
    </p>
</div>

---

JINRAIは、キーボードを中心にmacOSのウィンドウを素早く選択・移動するためのHammerspoon Spoonです。

## 主な機能

- **[Window Hints](window-hints.md)**
    - アプリアイコンとキーヒントからウィンドウを選択
    - 別のSpaceや他のウィンドウに隠れたウィンドウも候補として表示
    - キー入力、方向キー、マウスクリックによる選択
- **[Application Hints](application-hints.md)**
    - 固定キーからアプリを起動、または新しいウィンドウを作成
    - JinraiModeで作成したウィンドウを続けて配置
- **[Window Mover](window-mover.md)**
    - ウィンドウを別ディスプレイ、空き領域、指定した画面領域へ移動
    - 最大化、最小化、画面分割レイアウトへの配置
- **[JinraiMode](jinrai-mode.md)**
    - [Window Hints](window-hints.md)と[Window Mover](window-mover.md)を交互に連続実行
- **[Focus Border](focus-border.md)**
    - フォーカスしたウィンドウを一時的な枠線で強調
- **[Focus Back](focus-back.md)**
    - 直前に使用していたウィンドウへ戻る

## はじめる

[セットアップ](setup.md)では、HammerspoonとJINRAIのインストール、最小設定、アップデート方法を説明します。

各機能の使い方や設定は、次のページを参照してください。

- [Window Hints](window-hints.md)
- [Application Hints](application-hints.md)
- [Window Mover](window-mover.md)
- [JinraiMode](jinrai-mode.md)
- [Focus Border](focus-border.md)
- [Focus Back](focus-back.md)

補足設定やリファレンスは、次のページを参照してください。

- [全設定](configuration.md)
- [利用可能なエリア](window-mover-areas.md)
- [macOS Native Tabs](macos-native-tabs.md)

## デモ動画

<iframe width="700" height="393" src="https://www.youtube.com/embed/clwLqNw0kXw?si=O4erjEct74Pt4Lvj" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="700" height="393" src="https://www.youtube.com/embed/KPzN_dWQKaA?si=fPjtHrxLwNuRsWOF" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="700" height="393" src="https://www.youtube.com/embed/UnIfdg4emzU?si=e71kGttbS3O_CBfy" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## 関連リンク

- [GitHub](https://github.com/tadashi-aikawa/jinrai)
- [Deep Wiki](https://deepwiki.com/tadashi-aikawa/jinrai)
- [至高のウィンドウ切り替えを目指して『JINRAI(迅雷)』をつくった](https://minerva.mamansoft.net/2026-03-01-jinrai-ultimate-window-switching)

## ライセンス

[MIT License](https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE)
