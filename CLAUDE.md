# CLAUDE

## コミットメッセージ

Conventional Commits 形式で日本語で書く。

### フォーマット

```
<type>(<scope>): <description>
```

- `type`: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`, `build`, `ci`, `test`
  - 破壊的変更がある場合は `feat!` のように `!` を付ける
- `scope`: `window_hints`, `focus_back` など機能単位 (省略可)
- `description`: ユーザー視点で何が変わったかを簡潔に書く

### description の書き方

- ユーザーにとって何が変わるかを書く (実装詳細ではなく体験の変化)
- 「〜を追加」「〜を修正」「〜に変更」のように結果を述べる
- 内部的なリファクタリングの場合のみ実装視点で書いてよい

### 良い例

```
feat(window_hints): ヒント表示中に数字キーでスペースを切り替える機能を追加
fix(window_hints): 表示中に関係のないキー操作ができてしまう
feat!: 設定ファイルの構造化
```

### 悪い例

```
feat(window_hints): eventtap.keyStroke を gotoSpace に変更  ← 実装詳細
fix: バグ修正  ← 何が変わったか不明
```

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

## リリース方法

リリースはリポジトリルートで以下を実行します。

```bash
scripts/release.sh <バージョン>
```

例:

```bash
scripts/release.sh 0.13.0
```

スクリプトは `Jinrai.spoon/init.lua` のバージョン更新、テスト、配布物のbuild/validate、`chore: v<バージョン>` コミット、`v<バージョン>` タグ作成、`main` とタグのpushまで実行します。タグpush後、GitHub Actionsが `spoons` ブランチへ配布物を公開します。

Codex CLIが使えない環境やBluesky投稿文生成を省略したい場合は `--skip-codex` を指定します。

```bash
scripts/release.sh --skip-codex 0.13.0
```
