---
icon: lucide/tag
---

# ディスプレイ別名

トップレベルの`displayAliases`に、ディスプレイUUIDへ任意の別名を定義できます。
定義した別名は[プロファイル](profiles.md)の`displays`、[Area Hints](area-hints.md)の`screens`、[Window Layouts](window-layouts.md)の`screen`でUUIDの代わりに使用できます。

ディスプレイUUIDの確認方法は[Area Hints](area-hints.md#display-uuid)を参照してください。

```json
{
  "displayAliases": {
    "macbook": "37D8832A-2D66-02CA-B9F7-8F30A301B230",
    "desk": "11111111-2222-3333-4444-555555555555"
  },
  "profiles": [
    { "displays": ["desk"], "overrides": { "focusBorder": {} } }
  ],
  "areaHints": {
    "screens": {
      "macbook": { "full": "F" }
    }
  }
}
```

- 別名は空文字とUUID形式を避けてください。
- 未定義の別名を指定すると設定エラーになります。UUIDを直接指定する既存設定も引き続き使用できます。
- `profiles[].overrides`内で`displayAliases`は変更できません。
