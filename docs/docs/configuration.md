---
icon: lucide/settings
---

# 全設定

JINRAIの公開設定を、各機能を有効にした場合のデフォルト値でまとめています。
まずこの例で設定の全体像を確認し、値の選択肢や制約は後半および各機能ページを参照してください。

設定は`~/.config/jinrai/config.jsonc`に記述します。JSONC形式のため、コメントと末尾カンマを使用できます。

## エディタ補完 {#editor-completion}

JSON Schema対応エディタでは、設定ファイルの先頭付近に`$schema`を追加すると補完と静的チェックが有効になります。

```json
{
  "$schema": "https://tadashi-aikawa.github.io/jinrai/schemas/config.schema.json"
}
```

JSON Schemaでは設定キー、型、一部の選択肢をチェックします。キー重複やプレフィックス衝突など、実行時の状態に依存する検証はJINRAI起動時に行います。

!!! note
    `focusBorder`、`windowHints`、`focusBack`、`windowMover`、`areaHints`、`applicationHints`、`windowLayouts`は、
    設定ファイルにセクションを記述した機能だけが有効になります。

    `applicationHints.apps`と`windowLayouts.layouts`はデフォルト値が空であり、有効化時に1件以上の指定が必要です。
    そのため、以下では`applicationHints`と`windowLayouts`を省略してデフォルトの無効状態を示し、
    [Application Hints](application-hints.md)と[Window Layouts](window-layouts.md)に有効化例を掲載しています。

## デフォルト設定

```json
{
  "$schema": "https://tadashi-aikawa.github.io/jinrai/schemas/config.schema.json",

  // ディスプレイUUIDへ任意の別名を付けるマップです。
  "displayAliases": {},

  // Window HintsとArea Hintsを連続して操作するモードです。
  "jinraiMode": {
    // ロゴなどの中心位置です。
    "position": "activeWindow",
    // 各機能の表示中にJINRAI Modeを開始するキーです。1文字または特殊キー名(space / return / tab)で指定します。
    "triggers": {
      // Window Hints表示中にJINRAI Modeを開始するキーです。
      "windowHints": { "key": null },
      // Application Hints表示中にJINRAI Modeを開始するキーです。
      "applicationHints": { "key": null },
      // Area Hints表示中にJINRAI Modeを開始するキーです。
      "areaHints": { "key": null }
    },
    "logo": {
      // JINRAI Mode中にJINRAIロゴを表示します。
      "enabled": true,
      // ロゴの大きさです。
      "size": 480,
      // ロゴの透明度です。
      "alpha": 0.25,
      "animation": {
        // 表示切り替え時にフェードします。
        "fade": true,
        // アニメーション開始時の倍率です。
        "scale": 1.0,
        // アニメーション時間（秒）です。
        "duration": 0.16,
        // アニメーションの補間方式です。
        "easing": "linear"
      }
    },
    "combo": {
      "character": {
        // 操作回数に応じたキャラクター画像を表示します。
        "enabled": false,
        // キャラクター画像のパス配列です。未指定なら同梱画像を使用します。
        // 1枚だけならすべてのcomboで同じ画像、2枚以上なら0枚目を開始用、
        // 1枚目以降をcombo用として巡回します。
        // "images": ["~/Pictures/jinrai-combo.png"],
        // キャラクター画像の透明度です。
        "alpha": 0.7,
        "animation": {
          // 表示切り替え時にフェードします。
          "fade": true,
          // アニメーション開始時の倍率です。
          "scale": 1.18,
          // アニメーション時間（秒）です。
          "duration": 0.16,
          // アニメーションの補間方式です。
          "easing": "linear"
        }
      },
      "text": {
        // 継続回数をCOMBOテキストで表示します。
        "enabled": false,
        // COMBOテキストの透明度です。
        "alpha": 0.7,
        "animation": {
          // 表示切り替え時にフェードします。
          "fade": true,
          // アニメーション開始時の倍率です。
          "scale": 1.0,
          // アニメーション時間（秒）です。
          "duration": 0.16,
          // アニメーションの補間方式です。
          "easing": "linear"
        }
      }
    }
  },

  // フォーカスしたウィンドウを枠線で強調します。
  "focusBorder": {
    "visual": {
      "border": {
        // メイン枠線の太さです。
        "width": 10,
        // メイン枠線の色です。
        "color": { "red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.95 }
      },
      "outline": {
        // 外側の枠線の太さです。
        "width": 2,
        // 外側の枠線の色です。
        "color": { "red": 0, "green": 0, "blue": 0, "alpha": 0.70 }
      }
      // フォーカス時に表示するロゴです（未指定で非表示）。
      // "logo": { "source": null, "size": 480, "alpha": 0.95 }
    },
    "animation": {
      // 枠線が消えるまでの時間（秒）です。
      "duration": 0.5,
      // フェードアニメーションの分割数です。
      "fadeSteps": 18,
      // Space切り替え後に表示を待つ時間（秒）です。
      "spaceSwitchDelay": 0.30
    },
    "window": {
      // 枠線を表示する最小ウィンドウサイズです。
      "minSize": 480
    }
  },

  // キーヒントからウィンドウを選択します。
  "windowHints": {
    "hotkey": {
      // Window Hintsを開く修飾キーです。
      "modifiers": null,
      // Window Hintsを開くキーです。未指定ならホットキーは登録されません。
      "key": null
    },
    "hint": {
      // ヒントキーに使用する文字です。
      "chars": [
        "A", "S", "D", "F", "G", "H", "J", "K", "L",
        "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
        "Z", "X", "C", "V", "B", "N", "M"
      ],
      // アプリやタイトルごとのヒント先頭文字ルールです。
      "prefixOverrides": [],
      // ヒント内側の余白です。
      "padding": 12,
      // ヒント背景の角丸です。
      "cornerRadius": 12,
      // 隠れたウィンドウのヒント倍率です。
      "occludedScale": 0.85,
      "highlight": {
        // ヒントが指すウィンドウ上の枠線の太さです。
        "borderWidth": 6
      },
      "state": {
        "normal": {
          // 通常時のヒント背景色です。
          "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.80 },
          "highlight": {
            // 通常時の対象ウィンドウ塗りつぶし色です。
            "fillColor": { "red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.56 },
            // 通常時の対象ウィンドウ枠線色です。
            "borderColor": { "red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.85 }
          }
        },
        "dimmed": {
          // 候補から外れたヒントの背景色です。
          "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.14 },
          "highlight": {
            // 候補から外れた対象ウィンドウの枠線色です。
            "borderColor": { "red": 0.45, "green": 0.45, "blue": 0.48, "alpha": 0.30 }
          }
        },
        "occluded": {
          // 完全に隠れたウィンドウのヒント背景色です。
          "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.70 }
        },
        "active": {
          // 現在のウィンドウに表示するヒント背景色です。
          "bgColor": { "red": 0.08, "green": 0.05, "blue": 0.03, "alpha": 0.88 },
          "highlight": {
            // 現在のウィンドウの塗りつぶし色です。
            "fillColor": { "red": 0.95, "green": 0.68, "blue": 0.40, "alpha": 0.56 },
            // 現在のウィンドウの枠線色です。
            "borderColor": { "red": 0.95, "green": 0.68, "blue": 0.40, "alpha": 0.95 }
          }
        }
      },
      "icon": {
        // アプリアイコンの大きさです。
        "size": 72,
        "state": {
          // 通常時のアイコン透明度です。
          "normal": { "alpha": 0.95 },
          // 候補から外れたアイコンの透明度です。
          "dimmed": { "alpha": 0.30 },
          // 完全に隠れたウィンドウのアイコン透明度です。
          "occluded": { "alpha": 0.46 },
          // 現在のウィンドウのアイコン透明度です。
          "active": { "alpha": 1.0 }
        }
      },
      "key": {
        // キー表示部分の最小幅です。
        "minWidth": 72,
        // キー表示の文字サイズです。
        "fontSize": 48,
        // 入力済み部分を示す文字色です。
        "keyHighlightColor": { "red": 0.84, "green": 0.84, "blue": 0.86, "alpha": 0.35 },
        "state": {
          // 通常時のキー文字色です。
          "normal": { "color": { "red": 1, "green": 1, "blue": 1, "alpha": 1 } },
          // 候補から外れたキー文字色です。
          "dimmed": { "color": { "red": 0.85, "green": 0.85, "blue": 0.88, "alpha": 0.28 } },
          // 隠れたウィンドウは通常時の色を継承します。
          "occluded": {},
          // 現在のウィンドウのキー文字色です。
          "active": { "color": { "red": 1.00, "green": 0.93, "blue": 0.86, "alpha": 1.00 } }
        }
      },
      "title": {
        // ウィンドウタイトルを表示します。
        "show": true,
        // タイトルの文字サイズです。
        "fontSize": 16,
        // 表示するタイトルの最大文字数です。
        "maxSize": 72,
        "state": {
          // 通常時のタイトル文字色です。
          "normal": { "color": { "red": 0.90, "green": 0.92, "blue": 0.96, "alpha": 1.00 } },
          // 候補から外れたタイトル文字色です。
          "dimmed": { "color": { "red": 0.90, "green": 0.92, "blue": 0.96, "alpha": 0.30 } },
          // 隠れたウィンドウは通常時の色を継承します。
          "occluded": {},
          // 現在のウィンドウのタイトル文字色です。
          "active": { "color": { "red": 0.99, "green": 0.90, "blue": 0.78, "alpha": 1.00 } }
        }
      }
    },
    "focusedWindowHighlight": {
      // 現在のウィンドウを示す枠線色です。
      "borderColor": { "red": 0.95, "green": 0.68, "blue": 0.40, "alpha": 0.95 },
      // 現在のウィンドウを示す枠線の太さです。
      "borderWidth": 13
    },
    "focusedWindowSpotlight": {
      // 現在のウィンドウ以外を覆う暗幕の透明度です。
      "alpha": 0.5
    },
    "occlusion": {
      "sampling": {
        // ウィンドウの隠れ具合をサンプリングで判定します。
        "enabled": true,
        // サンプリング密度の基準画面幅です。
        "baseWidth": 1920,
        // サンプリング密度の基準画面高さです。
        "baseHeight": 1080,
        // 横方向の最小サンプル数です。
        "minCols": 4,
        // 縦方向の最小サンプル数です。
        "minRows": 4,
        // 横方向の最大サンプル数です。
        "maxCols": 8,
        // 縦方向の最大サンプル数です。
        "maxRows": 8
      },
      "preview": {
        // 完全に隠れたウィンドウのプレビューを表示します（要・画面収録権限）。
        "enabled": true,
        // プレビューの表示方式です。
        "mode": "background",
        // プレビューの幅です。
        "width": 140,
        // ヒントとプレビューの間隔です。
        "padding": 6,
        // プレビューの透明度です。
        "alpha": 0.64,
        // backgroundモードのプレビュー箱の合計面積が画面面積に占めてよい最大割合です。
        // 超過するとすべての箱を一律に縮小し、候補が多いときの重なりを防ぎます。
        "maxFillRatio": 0.5
      }
    },
    "dock": {
      // 画面下部に並べる候補の下余白です。
      "bottomMargin": 96,
      // 画面下部に並べる候補の間隔です。
      "itemGap": 12,
      "windowBlend": {
        // 候補の横位置へ元ウィンドウ位置を反映する割合です。
        "x": 0.65,
        // 候補の縦位置へ元ウィンドウ位置を反映する割合です。
        "y": 1
      }
    },
    "navigation": {
      "focusBack": {
        // 表示中にFocus Backを実行するキーです。
        "key": null
      },
      "direction": {
        "hints": {
          // 表示中に方向で候補を選ぶキーです。
          "keys": null
        },
        "direct": {
          // Window Hintsを開かず方向移動する修飾キーです。
          "modifiers": null,
          // Window Hintsを開かず方向移動するキーです。
          "keys": null
        },
        "scoring": {
          // 上下左右の候補評価で重なりを同等とみなす差です。
          "cardinalOverlapTieThresholdPx": 720,
          // 離れた候補とみなす主軸方向の最大重なり率です。
          "maxPrimaryOverlapRatioForDetached": 0.2,
          // 候補として優先する直交方向の最小重なり率です。
          "minOrthogonalOverlapRatio": 0.5,
          // 可視領域を優先評価する基準割合です。
          "preferredVisibleRatio": 0.4
        }
      },
      "spaces": {
        // 数字キーで対応するSpaceへ移動します。
        "numbers": true,
        // 前のSpaceへ移動するキーです。
        "prev": { "key": null },
        // 次のSpaceへ移動するキーです。
        "next": { "key": null }
      },
      "areaHints": {
        // Area Hintsへ移るキーです。
        "key": null
      },
      "windowLayouts": {
        // Window Layoutsのレイアウト選択ピッカーへ移るキーです。
        "key": null,
        // Window Layoutsへの移動時にJINRAI Modeを開始します。
        "jinraiMode": false
      },
      "applicationHints": {
        // Application Hintsへ移るキーです。
        "key": null,
        // Application Hintsへの移動時にJINRAI Modeを開始します。
        "jinraiMode": false
      }
    },
    "behavior": {
      "selection": {
        "swapWindowFrame": {
          // 押しながら選択すると移動元と移動先の位置・サイズを交換する修飾キーです。
          "modifiers": null
        }
      },
      "cursor": {
        // 選択後にカーソルを対象ウィンドウ中央へ移動します。
        "onSelect": true,
        // 起動時にカーソルを現在のウィンドウ中央へ移動します。
        "onStart": true
      },
      "candidates": {
        // 別のSpaceにあるウィンドウを候補に含めます。
        "includeOtherSpaces": true,
        // 現在のウィンドウを候補に含めます。
        "includeActiveWindow": true
      },
      "showFadeIn": {
        // ヒントのフェードイン時間（秒）です。0で即時表示します。
        "hints": 0.05,
        // 暗幕と枠線のフェードイン時間（秒）です。0で即時表示します。
        "spotlight": 0.4
      }
    }
  },

  // 直前にアクティブだったウィンドウへ戻ります。
  "focusBack": {
    "hotkey": {
      // Focus Backを実行する修飾キーです。
      "modifiers": null,
      // Focus Backを実行するキーです。未指定ならホットキーは登録されません。
      "key": null
    },
    "urlEvent": {
      // jinrai://<名前> のURLから実行する場合の名前です。
      "name": null
    },
    "behavior": {
      "cursor": {
        // 切り替え後にカーソルをウィンドウ中央へ移動します。
        "onSelect": true
      }
    }
  },

  // アクティブウィンドウを移動・リサイズします。
  "windowMover": {
    "commands": {
      // 次のディスプレイへ移動して最大化します。
      "moveToNextDisplay": { "hotkey": { "modifiers": null, "key": null } },
      // 現在のディスプレイの最大空き領域へ移動します。
      "moveToActiveDisplayFreeArea": { "hotkey": { "modifiers": null, "key": null } },
      // ウィンドウを最小化します。
      "minimizeWindow": { "hotkey": { "modifiers": null, "key": null } },
      // ウィンドウを最大化します。
      "maximizeWindow": { "hotkey": { "modifiers": null, "key": null } },
      // 左端で横幅を順番に切り替えます。
      "cycleLeft": { "hotkey": { "modifiers": null, "key": null } },
      // 横方向中央で横幅を順番に切り替えます。
      "cycleHorizontalCenter": { "hotkey": { "modifiers": null, "key": null } },
      // 右端で横幅を順番に切り替えます。
      "cycleRight": { "hotkey": { "modifiers": null, "key": null } },
      // 上端で高さを順番に切り替えます。
      "cycleTop": { "hotkey": { "modifiers": null, "key": null } },
      // 縦方向中央で高さを順番に切り替えます。
      "cycleVerticalCenter": { "hotkey": { "modifiers": null, "key": null } },
      // 下端で高さを順番に切り替えます。
      "cycleBottom": { "hotkey": { "modifiers": null, "key": null } }
      // このほか、[利用可能なエリア](window-mover-areas.md)の各エリア名も
      // そのままコマンド名として使用できます（freeAreaと固定サイズを除く）。
      // 例: "halfLeft": { "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" } }
    },
    "behavior": {
      "cursor": {
        // 移動後にカーソルをウィンドウ中央へ移動します。
        "afterMove": true
      },
      "cycle": {
        // 横幅を切り替える順番です。
        "horizontalRatios": [0.5, 0.3333, 0.6667],
        // 高さを切り替える順番です。
        "verticalRatios": [0.5, 0.3333, 0.6667]
      },
      "freeArea": {
        // 前面ウィンドウに隠れた背面ウィンドウをfreeArea計算から除外するかを指定します。
        "excludeHiddenWindows": true,
        // 前面ウィンドウに隠れた背面ウィンドウをfreeArea計算から除外するしきい値です。
        "hiddenWindowThreshold": 0.5
      }
    }
  },

  // エリアとキーを表示してウィンドウの移動先を選択します。
  "areaHints": {
    "hotkey": {
      // Area Hintsを開く修飾キーです。
      "modifiers": null,
      // Area Hintsを開くキーです。
      "key": null
    },
    "jinraiMode": {
      "hotkey": {
        // JINRAI ModeとしてArea Hintsを開く修飾キーです。
        "modifiers": null,
        // JINRAI ModeとしてArea Hintsを開くキーです。
        "key": null
      }
    },
    // screensに設定がないディスプレイで使うエリア名と選択キーのマップです。ディスプレイ数ごとの分岐も指定できます。
    "defaultScreen": null,
    // ディスプレイUUIDまたはdisplayAliasesの別名ごとのエリア名と選択キーです。ディスプレイ数ごとの分岐も指定できます。
    "screens": {},
    "actions": {
      // 選択中にウィンドウを閉じるキーです。
      "closeWindow": null,
      // 選択中にウィンドウを最小化するキーです。
      "minimizeWindow": null,
      // 選択中にウィンドウを最大化するキーです。
      "maximizeWindow": null,
      // 選択中にアプリケーションを終了するキーです。
      "quitApplication": null,
      // 選択中にGoogle Chromeの現在のタブを新しいChromeウィンドウとして分離するキーです。
      "detachChromeTabToNewWindow": null
      // このほか、エリア名(halfLeft等)をキーにすると、選択中にアクティブウィンドウを
      // アクティブディスプレイ内の該当エリアへ移動できます。
    },
    "navigation": {
      "windowHints": {
        // 選択画面を閉じてWindow Hintsを開くキーです。
        "key": null
      }
    },
    "labels": {
      // エリアと選択キーのラベルを画面上に表示します。
      "show": true
    },
    "activeWindowHighlight": {
      // アクティブウィンドウを示す枠線色です。
      "borderColor": { "red": 0.95, "green": 0.68, "blue": 0.40, "alpha": 0.95 },
      // アクティブウィンドウを示す枠線の太さです。
      "borderWidth": 13,
      // アクティブウィンドウを示す枠線の角丸です。
      "cornerRadius": 12
    },
    "activeWindowSpotlight": {
      // アクティブウィンドウ以外を覆う暗幕の透明度です。
      "alpha": 0.5
    },
    "appearance": {
      "state": {
        "normal": {
          // 通常時のラベル背景色です。
          "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.88 },
          // 通常時の選択キー文字色です。
          "textColor": { "red": 0.96, "green": 1.0, "blue": 0.98, "alpha": 1.0 },
          // 入力済み部分を示す文字色です。
          "typedTextColor": { "red": 0.96, "green": 1.0, "blue": 0.98, "alpha": 0.38 }
        },
        "dimmed": {
          // 候補から外れたラベルの背景色です。
          "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.30 },
          // 候補から外れた選択キーの文字色です。
          "textColor": { "red": 0.96, "green": 1.0, "blue": 0.98, "alpha": 0.32 }
        }
      }
    }
  }

  // "applicationHints" は登録アプリが必須のため、デフォルトでは無効です。
  // "windowLayouts" はレイアウト定義が必須のため、デフォルトでは無効です。
}
```

## Application Hintsを有効にする

Application Hintsは`apps`が1件以上必要なため、実行可能なデフォルト設定を定義できません。
有効にする場合は、次の全項目例を参考に`applicationHints`セクションを追加してください。
`apps`内の`bundleID`と`key`だけが利用環境に合わせて指定する必須値で、それ以外はデフォルト値です。

```json
"applicationHints": {
  "hotkey": {
    // Application Hintsを直接開く修飾キーです。
    "modifiers": null,
    // Application Hintsを直接開くキーです。
    "key": null
  },
  // 新規ウィンドウが現れるまで待つ最大時間（秒）です。
  "windowWaitTimeout": 10,
  "apps": [
    {
      // 起動するアプリのbundle IDです。
      "bundleID": "com.google.Chrome",
      // アプリを選択する1文字または2文字のキーです。
      "key": "C",
      // 画面に表示するアプリ名です（未指定で自動解決）。
      "name": null,
      "newWindow": {
        "hotkey": {
          // 起動済みアプリで新規ウィンドウを作る修飾キーです。
          "modifiers": ["cmd"],
          // 起動済みアプリで新規ウィンドウを作るキーです。
          "key": "n"
        }
        // ホットキーの代わりに開くURLです。指定するとhotkeyより優先されます。
        // "url": "obsidian://open?path=/path/to/vault"
      }
    }
  ],
  "appearance": {
    // アプリ項目の幅です。
    "itemWidth": 220,
    // アプリ項目の高さです。
    "itemHeight": 112,
    // アプリ項目同士の間隔です。
    "gap": 12,
    // 1行に表示するアプリ数です。
    "columns": 3,
    // アプリアイコンの大きさです。
    "iconSize": 64,
    // アプリ項目背景の角丸です。
    "cornerRadius": 12,
    // 通常時の背景色です。
    "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.80 },
    // 候補から外れた項目の背景色です。
    "dimmedBgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.30 },
    // 通常時の文字色です。
    "textColor": { "red": 0.96, "green": 0.97, "blue": 1.00, "alpha": 1.00 },
    // 候補から外れた項目の文字色です。
    "dimmedTextColor": { "red": 0.82, "green": 0.84, "blue": 0.88, "alpha": 0.30 },
    // OPENまたはNEWの状態表示色です。
    "stateColor": { "red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 1.00 },
    // 入力済み部分を示す文字色です。
    "keyHighlightColor": { "red": 0.84, "green": 0.84, "blue": 0.86, "alpha": 0.35 }
  }
}
```

## Window Layoutsを有効にする {#window-layouts}

Window Layoutsは`layouts`が1件以上必要なため、実行可能なデフォルト設定を定義できません。
有効にする場合は、次の全項目例を参考に`windowLayouts`セクションを追加してください。

```json
"windowLayouts": {
  "hotkey": {
    // レイアウト選択モーダル（ピッカー）を開く修飾キーです。
    "modifiers": null,
    // レイアウト選択モーダル（ピッカー）を開くキーです。
    "key": null
  },
  // launchで起動したアプリのウィンドウが現れるまで待つ最大時間（秒）です。
  "windowWaitTimeout": 10,
  // レイアウト定義の一覧です。ピッカーには記載順に表示されます。
  "layouts": [
    {
      // レイアウト名です（必須・重複不可）。ピッカーに表示・検索されます。
      "name": "dev",
      // レイアウトを直接適用するホットキーです。他のレイアウトやピッカーと重複できません。
      // 省略した場合はピッカーからのみ呼び出せます
      // （windowLayouts.hotkey / windowHints.navigation.windowLayouts.key のどちらも未設定ならエラー）。
      "hotkey": { "modifiers": ["ctrl", "alt"], "key": "1" },
      // ピッカーに表示・検索される説明です（任意）。
      "description": "開発用の配置",
      // 現在のSpaceで表示されている標準ウィンドウのうち、配置対象に選ばれなかったものの扱いです。
      // "close"で閉じる、{ "screen": <UUIDまたは別名(任意)>, "area": <エリア名> }で指定位置へ一律配置、
      // 省略時は何もしません。
      "unlistedWindows": "close",
      // レイアウト適用時に必ず閉じるウィンドウの一覧です（任意）。
      // マッチしたすべてのウィンドウを配置より先に閉じます（アプリは終了しません）。
      // windowsの配置マッチより優先され、閉じたウィンドウは配置・unlistedWindowsの対象になりません。
      "closeWindows": [
        {
          // 対象アプリのbundle IDです。完全一致で照合します。
          "bundleID": "com.tinyspeck.slackmacgap",
          // ウィンドウタイトルのglobパターンです（省略でタイトルを問いません）。
          "titleGlob": "*"
        }
      ],
      // 配置対象のウィンドウ一覧です。closeWindowsかunlistedWindowsの指定時は省略できます
      // （windows / closeWindows / unlistedWindowsのいずれかが必要）。
      "windows": [
        {
          // 対象アプリのbundle IDです。完全一致で照合します。
          "bundleID": "com.google.Chrome",
          // ウィンドウタイトルのglobパターンです（省略でタイトルを問いません）。
          "titleGlob": "*GitHub*",
          // 配置先ディスプレイのUUIDまたはdisplayAliasesの別名です
          // （省略・未接続時はウィンドウが現在いるディスプレイ）。
          "screen": "desk",
          // 配置先のエリア名です。
          "area": "halfLeft",
          // ウィンドウが存在しなければアプリを起動してウィンドウの出現を待ちます。
          "launch": false,
          // レイアウト適用後にこのウィンドウへフォーカスします（1レイアウトに1件まで）。
          "focus": false
        }
      ]
    }
  ],
  "appearance": {
    // ピッカーの幅です。
    "pickerWidth": 480,
    // ピッカーのレイアウト1行の高さです。
    "rowHeight": 32,
    // ピッカーに同時表示する最大行数です。超えた分はスクロールします。
    "maxVisibleRows": 8,
    // ピッカー背景の角丸です。
    "cornerRadius": 12,
    // ピッカーの背景色です。
    "bgColor": { "red": 0.03, "green": 0.03, "blue": 0.04, "alpha": 0.88 },
    // レイアウト名とクエリの文字色です。
    "textColor": { "red": 0.96, "green": 0.97, "blue": 1.00, "alpha": 1.00 },
    // 説明・プレースホルダ・件数表示の文字色です。
    "dimmedTextColor": { "red": 0.82, "green": 0.84, "blue": 0.88, "alpha": 0.45 },
    // 選択行の背景色です。
    "selectedBgColor": { "red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.35 },
    // 選択行の文字色です。
    "selectedTextColor": { "red": 0.96, "green": 1.00, "blue": 0.98, "alpha": 1.00 }
  }
}
```

## ディスプレイ別名とプロファイル

ディスプレイUUIDへ任意の別名を付ける`displayAliases`は[ディスプレイ別名](display-aliases.md)、
接続ディスプレイによって設定を切り替える`profiles`は[プロファイル](profiles.md)を参照してください。

## 選択肢と共通ルール

### 機能の有効・無効

`focusBorder`、`windowHints`、`focusBack`、`windowMover`、`areaHints`は、設定ファイルにセクション（`{}`でも可）を記述すると有効になります。
セクションを記述しない場合は無効です。

`applicationHints`と`windowLayouts`も同様ですが、有効化する場合はそれぞれ`apps`と`layouts`へ1件以上の指定が必要です。

Area Hints経由の移動は、`windowMover.behavior`(カーソル追従・freeAreaのしきい値)の設定に従います。
`windowMover`セクションがない場合はデフォルト値が使われます。

### 修飾キー

修飾キーには`cmd`、`alt`、`ctrl`、`shift`、`fn`を使用できます。
`command`、`option`、`control`はそれぞれ`cmd`、`alt`、`ctrl`の別名です。

`navigation.direction.direct.modifiers`では`fn`を使用できません。

### 色

色は`red`、`green`、`blue`、`alpha`を持つオブジェクトで指定します。いずれも`0`から`1`の値です。

```json
{ "red": 0.40, "green": 0.68, "blue": 0.98, "alpha": 0.95 }
```

### JINRAI Modeの位置とアニメーション

`jinraiMode.position`の値と各`animation`の指定方法は
[JINRAI Mode](jinrai-mode.md#position-and-animation)を参照してください。

### Window Hintsの状態

見た目の`state`には次の状態があります。値が空の状態は`normal`の値を継承します。

| 状態 | 説明 |
| --- | --- |
| `normal` | 選択候補になっている通常のウィンドウです。 |
| `dimmed` | 入力したキーによって候補から外れたウィンドウです。 |
| `occluded` | 他のウィンドウに完全に隠れたウィンドウです。 |
| `active` | Window Hintsを開いた時点でアクティブなウィンドウです。 |

`occlusion.preview.mode`は`background`または`below`から指定します。
`background`はヒント全体の背景、`below`はタイトル下にプレビューを表示します。

方向移動キー、ヒントキー、機能切り替えキーの指定方法と競合時の扱いは
[Window Hints](window-hints.md)を参照してください。

### Area Hintsのエリア

`areaHints.screens`には、ディスプレイUUIDまたは[ディスプレイ別名](display-aliases.md)ごとにエリア名と1〜3文字の選択キーを指定します。
使用できるエリア名は[利用可能なエリア](window-mover-areas.md)を参照してください。

```json
"areaHints": {
  "defaultScreen": {
    "full": "A",
    "halfLeft": "S",
    "halfRight": "F"
  },
  "screens": {
    "desk": {
      "full": "A",
      "halfLeft": "S",
      "halfRight": "F",
      "1920x1080Center": "M"
    }
  }
}
```

`defaultScreen`には、`screens`に設定がないディスプレイで使うエリア名と選択キーのマップを指定します。
キーが他のディスプレイのキー（`screens`の明示設定や、複数ディスプレイに適用された`defaultScreen`同士）と
衝突する場合、`defaultScreen`側のキーには自動で数字プレフィックス（`2`, `3`, …）が付きます（例: `H`→`2H`）。

エリアマップの代わりに、接続中のディスプレイ数（または`default`）をキーにしたマップを指定すると、
ディスプレイ数ごとに割り当てを切り替えられます。数字とエリア名は混在できません。
詳細は[Area Hints](area-hints.md#display-count-branches)を参照してください。

```json
"areaHints": {
  "screens": {
    "desk": {
      "1": { "halfLeft": "H" },
      "2": { "halfLeft": "JH" },
      "default": { "halfLeft": "H" }
    }
  }
}
```

同じ選択画面で使うキーの重複禁止ルールは[Area Hints](area-hints.md#key-constraints)の「キーの制約」を参照してください。
