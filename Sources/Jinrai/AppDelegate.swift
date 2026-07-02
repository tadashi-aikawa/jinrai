import AppKit
import JinraiCore
import JinraiPlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItem?
    private var focusHistory: FocusHistoryFeature?
    private var focusBack: FocusBackFeature?
    private var focusBorder: FocusBorderFeature?
    private var windowHints: WindowHintsFeature?
    private var accessibilityGranted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItem()
        statusItem?.onReloadConfig = { [weak self] in
            self?.reloadConfig()
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        Permissions.ensureAccessibility { [weak self] in
            guard let self else { return }
            self.accessibilityGranted = true
            self.statusItem?.setAccessibilityGranted(true)
            self.startFeatures()
        }
    }

    /// 設定を読み込んで各機能を結線する(元 Jinrai の init.lua setup 相当)
    private func startFeatures() {
        let config: RootConfig
        do {
            config = try ConfigLoader.load()
        } catch {
            showConfigError(error)
            return
        }

        if let focusBorderConfig = config.focusBorder {
            focusBorder = FocusBorderFeature(config: focusBorderConfig)
        }

        // focus_back が有効なときだけ履歴を生成し、後で window_hints と共有する
        if let focusBackConfig = config.focusBack {
            let history = FocusHistoryFeature(macosNativeTabs: config.macosNativeTabs)
            focusHistory = history
            focusBack = FocusBackFeature(config: focusBackConfig, focusHistory: history)
        }

        if let windowHintsConfig = config.windowHints {
            windowHints = WindowHintsFeature(
                config: windowHintsConfig, focusHistory: focusHistory)
        }
    }

    private func teardownFeatures() {
        windowHints?.teardown()
        windowHints = nil
        focusBack?.teardown()
        focusBack = nil
        focusHistory?.teardown()
        focusHistory = nil
        focusBorder?.teardown()
        focusBorder = nil
    }

    func reloadConfig() {
        guard accessibilityGranted else { return }
        teardownFeatures()
        startFeatures()
    }

    @objc private func handleURLEvent(
        _ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString),
            url.scheme == "jinrai"
        else { return }
        let name = url.host ?? ""
        if let focusBack, focusBack.urlEventName == name {
            focusBack.run()
        }
    }

    private func showConfigError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Jinrai の設定読み込みに失敗しました"
        alert.informativeText = "\(error)\n\n\(ConfigLoader.configFileURL.path)"
        alert.alertStyle = .warning
        alert.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) {
        teardownFeatures()
    }
}
