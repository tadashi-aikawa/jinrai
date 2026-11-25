import AppKit
import JinraiCore
import JinraiPlatform

/// ミラーリングと拡張表示をホットキーで切り替える
@MainActor
final class DisplayMirroringFeature {
    private let config: DisplayMirroringConfig
    private let indicator: CenterHUD
    private var hotkey: Hotkey?

    init(config: DisplayMirroringConfig, indicator: CenterHUD) {
        self.config = config
        self.indicator = indicator

        if let key = config.hotkeyKey {
            hotkey = Hotkey(modifiers: config.hotkeyModifiers, key: key) { [weak self] in
                self?.toggle()
            }
            if hotkey == nil {
                NSLog("[jinrai.displayMirroring] ホットキーの登録に失敗: %@", key)
            }
        }
    }

    func toggle() {
        let plan = DisplayMirroringPlanner.plan(DisplayMirroring.onlineDisplays())
        let mainID = CGMainDisplayID()
        switch plan {
        case .unavailable:
            indicator.show("ディスプレイが1台です", on: mainID)
        case .mirror(let source, _):
            guard DisplayMirroring.apply(plan) else { return showFailure(plan) }
            indicator.show("ミラーリング", on: source)
        case .extend:
            guard DisplayMirroring.apply(plan) else { return showFailure(plan) }
            indicator.show("拡張表示", on: mainID)
        }
    }

    /// jinrai://<name> の URL イベント名(設定されていれば)
    var urlEventName: String? { config.urlEventName }

    func teardown() {
        hotkey?.unregister()
        hotkey = nil
    }

    private func showFailure(_ plan: DisplayMirroringPlan) {
        NSLog("[jinrai.displayMirroring] 切り替えに失敗: %@", String(describing: plan))
        indicator.show("切り替えに失敗しました", on: CGMainDisplayID())
    }
}
