# jinrai-native

[Jinrai](https://github.com/tadashi-aikawa/jinrai)(Hammerspoon Spoon)を Swift + AppKit で macOS ネイティブアプリとして再実装したもの。Hammerspoon に依存せず単体で動作する。

## 機能(フェーズ1)

- **Window Hints**: ホットキーで全ウィンドウにアプリアイコン+キーヒントを表示し、キー入力でフォーカス切替。別 Space・完全に隠れたウィンドウは画面下部のドックに表示。8方向ナビゲーション、frame 交換(swap)、Space 移動対応
- **Window Mover**: 約50種の固定エリアへの移動、サイクルリサイズ(1/2→1/3→2/3)、最大空き領域(freeArea)、エリア選択画面、ウィンドウ操作アクション
- **Focus Back**: option+w で直前のウィンドウへ復帰(`jinrai://` URL スキーム対応)
- **Focus Border**: フォーカス移動時にウィンドウを二重枠線で強調

フェーズ2(未実装): Application Hints / JinraiMode 演出 / 自動アップデート

## 必要環境

- macOS 14 以降
- Swift 6 toolchain(Xcode または Command Line Tools)

## ビルドと起動

```bash
./scripts/make-app.sh          # swift build + .app 組み立て + ad-hoc 署名
open .build/Jinrai.app
```

初回起動時に**アクセシビリティ権限**を求められる。システム設定 → プライバシーとセキュリティ → アクセシビリティで Jinrai を許可すると機能が有効になる。

> [!WARNING]
> ad-hoc 署名は再ビルドで署名が変わり、アクセシビリティ許可が剥がれることがある。
> その場合は `tccutil reset Accessibility com.tadashi-aikawa.jinrai` を実行してから再許可する。

## 設定

`~/.config/jinrai/config.json`(JSONC: コメント・末尾カンマ可)。初回起動時にテンプレートが生成される。
各機能は**セクションが存在するときだけ有効**になる(元 Jinrai の `setup()` と同じ)。

```jsonc
{
    "focus_border": {},
    "focus_back": {},
    "window_hints": {
        "hotkey": { "modifiers": ["alt"], "key": "f20" },
        "navigation": {
            "focusBack": { "key": ";" },
            "direction": { "hints": { "keys": { "left": "h", "down": "j", "up": "k", "right": "l" } } },
            "windowMover": { "moveToSelectedArea": { "key": "," } }
        }
    },
    "window_mover": {
        "commands": {
            "moveToNextDisplay": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "n" } },
            "cycleLeft": { "hotkey": { "modifiers": ["cmd", "alt"], "key": "h" } }
        },
        "selectedArea": {
            "defaultScreen": {
                "halfLeft": "H", "halfRight": "L", "full": "F", "freeArea": "S"
            }
        }
    }
}
```

設定リファレンスは元 Jinrai の [configuration.md](https://github.com/tadashi-aikawa/jinrai/blob/main/docs/docs/configuration.md) にほぼ準拠(Lua テーブル → JSON オブジェクト、`nil` → キー省略)。

メニューバーの ⚡ アイコン →「設定を再読込」で反映できる。

### Space 移動について

Space の列挙は非公開 CGS API、切替は Mission Control のキーボードショートカット送出(ctrl+数字 / ctrl+←→)で行う。
数字キーでの Space 移動には、システム設定 → キーボード → キーボードショートカット → Mission Control で「デスクトップ n へ切り替え」を有効にしておく必要がある。

## 開発

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

### 手動テストチェックリスト

- [ ] 初回起動でアクセシビリティ権限フローが動く
- [ ] Window Hints: 表示 → キー選択 → フォーカス移動(Escape / 外クリックで閉じる)
- [ ] 別 Space のウィンドウがドックに表示され、選択で Space が切り替わる
- [ ] 方向キーで隣のウィンドウへ移動できる
- [ ] Window Mover: cycle 反復で比率が巡回する / エリア選択画面から移動できる
- [ ] Focus Back で直前ウィンドウへ交互にトグルできる
- [ ] マルチディスプレイ・解像度混在で座標がずれない
- [ ] パスワード入力(セキュア入力)中にヒントを開いた場合の挙動
- [ ] スリープ復帰後もホットキー・eventtap が生きている

## ライセンス

MIT
