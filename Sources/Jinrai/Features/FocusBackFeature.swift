import AppKit
import JinraiCore
import JinraiPlatform

/// 直前ウィンドウへの復帰(元 focus_back.lua)
@MainActor
final class FocusBackFeature {
    private let config: FocusBackConfig
    private let focusHistory: FocusHistoryFeature
    private var hotkey: Hotkey?

    init(config: FocusBackConfig, focusHistory: FocusHistoryFeature) {
        self.config = config
        self.focusHistory = focusHistory

        if let key = config.hotkeyKey {
            hotkey = Hotkey(modifiers: config.hotkeyModifiers, key: key) { [weak self] in
                self?.run()
            }
            if hotkey == nil {
                NSLog("[jinrai.focusBack] ホットキーの登録に失敗: %@", key)
            }
        }
    }

    func run() {
        focusHistory.focusBack(centerCursor: config.centerCursor)
    }

    /// jinrai://<name> の URL イベント名(設定されていれば)
    var urlEventName: String? { config.urlEventName }

    func teardown() {
        hotkey?.unregister()
        hotkey = nil
    }
}
