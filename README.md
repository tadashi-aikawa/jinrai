<div align="center">
    <h1>JINRAI</h1>
    <img src="./jinrai.svg" width="256" />
    <p>
    <h3>迅雷</h3>
    <div>思考の速度で素早くウィンドウの切り替えや認識を行うためのhammerspoonスクリプト</div>
    </p>
    <p>
        <a href="https://github.com/tadashi-aikawa/jinrai/releases/latest"><img src="https://img.shields.io/github/release/tadashi-aikawa/jinrai" alt="release" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml"><img src="https://github.com/tadashi-aikawa/jinrai/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
        <a href="https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE"><img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" /></a>
    </p>
</div>

## ドキュメント

- [JINRAI(迅雷)](https://tadashi-aikawa.github.io/jinrai/)
- [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/tadashi-aikawa/jinrai)

## デモ動画

[![JINRAI Demo](https://img.youtube.com/vi/clwLqNw0kXw/hqdefault.jpg)](https://youtu.be/clwLqNw0kXw?si=gdetaK7lY0Eovjpp)

[![Jinrai Mode](https://utfs.io/f/nGnSqDveMsqxhHlukstMhHULDOxCZ0brc5TpPYdWQt8vJ2Bg)](https://www.youtube.com/watch?v=Dg_fxulwFok)

## 開発者ブログ記事（日本語）

[📘至高のウィンドウ切り替えを目指して『JINRAI(迅雷)』をつくった - Minerva](https://minerva.mamansoft.net/2026-03-01-jinrai-ultimate-window-switching)

## 開発

ソースから symlink で導入しておくと、`Jinrai.spoon/` 配下の変更を Hammerspoon の `Reload Config` ですぐ確認できます。

### Gitフックの設定

```bash
git config core.hooksPath hooks
```

## テスト

ユニットテストは `busted` で実行します。

```bash
busted
```

特定のテストだけ実行したい場合:

```bash
busted spec/focus_back_spec.lua
busted spec/init_spec.lua
```

## リリース

https://github.com/tadashi-aikawa/jinrai/actions/workflows/release.yml

## ライセンス

<img src="https://img.shields.io/github/license/tadashi-aikawa/jinrai" alt="License" />
