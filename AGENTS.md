# AGENTS

このファイルは AI エージェント向けの運用ルール置き場です。
ユーザー向けの使い方や機能説明は `README.md` に記載し、AI 固有の指示は `AGENTS.md` に記載してください。

## テスト実行

ユニットテストはリポジトリルートで以下を実行します。

```bash
busted
```

必要に応じて個別実行も可能です。

```bash
busted spec/focus_back_spec.lua
busted spec/init_spec.lua
```
