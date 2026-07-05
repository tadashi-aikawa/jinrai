import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("JinraiModeLogic")
struct JinraiModeLogicTests {
    @Test("コンボ画像 index: 0 は開始、1〜9 を巡回")
    func comboImageIndex() {
        #expect(JinraiModeLogic.comboImageIndex(count: 0) == 0)
        #expect(JinraiModeLogic.comboImageIndex(count: -1) == 0)
        #expect(JinraiModeLogic.comboImageIndex(count: 1) == 1)
        #expect(JinraiModeLogic.comboImageIndex(count: 9) == 9)
        #expect(JinraiModeLogic.comboImageIndex(count: 10) == 1)
        #expect(JinraiModeLogic.comboImageIndex(count: 18) == 9)
        #expect(JinraiModeLogic.comboImageIndex(count: 19) == 1)
    }

    @Test("アニメーション進捗と easing")
    func animationProgress() {
        #expect(JinraiModeLogic.animationProgress(0.5, easing: .linear) == 0.5)
        #expect(JinraiModeLogic.animationProgress(1.2, easing: .linear) == 1)
        #expect(JinraiModeLogic.animationProgress(-0.1, easing: .linear) == 0)
        // easeOut は前半が速い
        #expect(JinraiModeLogic.animationProgress(0.5, easing: .easeOut) == 0.75)
        // easeInOut は中間で 0.5
        #expect(JinraiModeLogic.animationProgress(0.5, easing: .easeInOut) == 0.5)
        #expect(JinraiModeLogic.animationProgress(0.25, easing: .easeInOut) == 0.125)
    }

    @Test("ステップ数 = duration / 0.02 切り上げ")
    func animationSteps() {
        #expect(JinraiModeLogic.animationSteps(duration: 0.16) == 8)
        #expect(JinraiModeLogic.animationSteps(duration: 0) == 0)
        #expect(JinraiModeLogic.animationSteps(duration: 0.05) == 3)
    }

    @Test("コンボ基準サイズ = min(560, 幅*0.46, 高さ*0.7)")
    func comboBaseSize() {
        let wide = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        #expect(JinraiModeLogic.comboBaseSize(screenFrame: wide) == 560)
        let narrow = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(JinraiModeLogic.comboBaseSize(screenFrame: narrow) == 460)
        let short = CGRect(x: 0, y: 0, width: 2000, height: 500)
        #expect(JinraiModeLogic.comboBaseSize(screenFrame: short) == 350)
    }

    @Test("表示中心: activeWindow はウィンドウ中央、なければ画面中央")
    func displayCenter() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let window = CGRect(x: 100, y: 100, width: 200, height: 200)
        #expect(
            JinraiModeLogic.displayCenter(
                position: "activeWindow", windowFrame: window, screenFrame: screen)
                == CGPoint(x: 200, y: 200))
        #expect(
            JinraiModeLogic.displayCenter(
                position: "activeWindow", windowFrame: nil, screenFrame: screen)
                == CGPoint(x: 500, y: 400))
        #expect(
            JinraiModeLogic.displayCenter(
                position: "activeDisplay", windowFrame: window, screenFrame: screen)
                == CGPoint(x: 500, y: 400))
    }
}

@Suite("JinraiModeConfigBuilder")
struct JinraiModeConfigTests {
    @Test("デフォルト値(元 DEFAULT_JINRAI_MODE)")
    func defaults() throws {
        let config = try JinraiModeConfigBuilder.build()
        #expect(config.position == "activeWindow")
        #expect(config.windowHintsTriggerKey == nil)
        #expect(config.logo.enabled)
        #expect(config.logo.size == 480)
        #expect(config.logo.alpha == 0.25)
        #expect(config.logo.animation.duration == 0.16)
        #expect(!config.comboCharacter.enabled)
        #expect(config.comboCharacter.animation.scale == 1.18)
        #expect(!config.comboText.enabled)
    }

    @Test("ユーザー設定(triggers=return, combo enabled)を読める")
    func userConfig() throws {
        let config = try JinraiModeConfigBuilder.build([
            "triggers": [
                "windowHints": ["key": "return"],
                "applicationHints": ["key": "return"],
                "windowMover": ["key": "return"],
            ],
            "combo": [
                "character": ["enabled": true],
                "text": ["enabled": true],
            ],
        ])
        #expect(config.windowHintsTriggerKey == "return")
        #expect(config.applicationHintsTriggerKey == "return")
        #expect(config.windowMoverTriggerKey == "return")
        #expect(config.comboCharacter.enabled)
        #expect(config.comboText.enabled)
        // enabled 以外はデフォルト維持
        #expect(config.comboCharacter.alpha == 0.7)
    }

    @Test("不正な position はエラー")
    func invalidPosition() {
        #expect(throws: ConfigError.self) {
            try JinraiModeConfigBuilder.build(["position": "center"])
        }
    }

    @Test("RootConfig 経由でトリガキーが各機能へ配布される")
    func rootConfigDistributesTriggers() throws {
        let config = try RootConfigBuilder.build(text: """
            {
                "windowHints": {},
                "windowMover": {},
                "applicationHints": { "apps": [{ "bundleID": "a.b", "key": "G" }] },
                "jinraiMode": {
                    "triggers": {
                        "windowHints": { "key": "return" },
                        "applicationHints": { "key": "return" },
                        "windowMover": { "key": "return" }
                    }
                }
            }
            """)
        #expect(config.windowHints?.jinraiModeKey == "return")
        #expect(config.windowMover?.jinraiModeKey == "return")
        #expect(config.applicationHints?.jinraiModeKey == "return")
    }
}
