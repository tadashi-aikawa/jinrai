---
icon: lucide/monitor-cog
---

# プロファイル

トップレベルの`profiles`に、特定のディスプレイが接続されているときだけ設定を上書きするプロファイルを指定できます。
たとえば「会議室のモニタに投影するときだけCOMBO演出を非表示にする」といった切り替えができます。

```json
{
  "displayAliases": {
    "meeting": "A1B2C3D4-5E6F-7890-ABCD-EF1234567890"
  },
  "profiles": [
    {
      // 会議室モニタが接続されているときはCOMBO演出を無効にします。
      "displays": ["meeting"],
      "overrides": {
        "jinraiMode": {
          "combo": {
            "character": { "enabled": false },
            "text": { "enabled": false }
          }
        }
      }
    }
  ]
}
```

| キー | 説明 |
| --- | --- |
| `displays` | ディスプレイUUIDまたは[ディスプレイ別名](display-aliases.md)の一覧です。いずれか1つでも接続されていればプロファイルが適用されます。UUIDの大文字小文字は区別しません。 |
| `overrides` | 上書きする設定です。ルートと同じ構造で任意のセクションを指定できます（`$schema`、`profiles`、`displayAliases`を除く）。 |

適用ルールは次のとおりです。

- 複数のプロファイルがマッチした場合、定義順にdeep mergeされます（後のプロファイルが優先）。
- deep mergeでは辞書はキー単位で再帰的にマージされ、配列は丸ごと置換されます。
- ベース設定にないセクションを`overrides`に記述すると、その機能が有効になります。
- ディスプレイの接続・切断には自動で追従します。構成が変わると設定が再読込されるため、JINRAIの再起動は不要です。
- ミラーリング中は集約されたディスプレイのみが接続扱いになります。自席モニタへのミラーリング投影時はプロファイルが適用されない場合があります。

ディスプレイUUIDの確認方法は[Area Hints](area-hints.md#display-uuid)を参照してください。
