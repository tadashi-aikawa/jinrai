import AppKit
import JinraiPlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItem()

        Permissions.ensureAccessibility { [weak self] in
            self?.startFeatures()
        }
    }

    private func startFeatures() {
        // 機能モジュールはここで結線する(元 Jinrai の init.lua 相当)
        statusItem?.setAccessibilityGranted(true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // teardown
    }
}
