import AppKit
import JinraiPlatform

/// メニューバー常駐アイコン(元 Jinrai の updater.lua のメニューバー相当)
@MainActor
final class StatusItem {
    private let item: NSStatusItem
    private let permissionMenuItem: NSMenuItem
    var onReloadConfig: (() -> Void)?

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "bolt.fill",
                accessibilityDescription: "Jinrai"
            )
            image?.isTemplate = true
            button.image = image
        }

        permissionMenuItem = NSMenuItem(
            title: "アクセシビリティ権限: 未許可",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )

        let menu = NSMenu()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let versionItem = NSMenuItem(
            title: "Jinrai \(version ?? "0.0.0-development")",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        permissionMenuItem.target = self
        menu.addItem(permissionMenuItem)
        menu.addItem(.separator())
        let dumpItem = NSMenuItem(
            title: "ウィンドウ一覧をダンプ",
            action: #selector(dumpWindows),
            keyEquivalent: ""
        )
        dumpItem.target = self
        menu.addItem(dumpItem)
        let reloadItem = NSMenuItem(
            title: "設定を再読込",
            action: #selector(reloadConfig),
            keyEquivalent: "r"
        )
        reloadItem.target = self
        menu.addItem(reloadItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Jinrai",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        item.menu = menu
    }

    func setAccessibilityGranted(_ granted: Bool) {
        permissionMenuItem.title = granted ? "アクセシビリティ権限: 許可済み" : "アクセシビリティ権限: 未許可"
    }

    @objc private func reloadConfig() {
        onReloadConfig?()
    }

    @objc private func dumpWindows() {
        let windows = WindowEnumerator.orderedWindows()
        NSLog("=== Jinrai window dump: %d windows (Z順) ===", windows.count)
        for (index, win) in windows.enumerated() {
            let ax = AXWindow.resolve(windowID: win.id, pid: win.pid)
            NSLog(
                "%2d. id=%u pid=%d app=%@ title=%@ frame=(%.0f,%.0f %.0fx%.0f) ax=%@ standard=%@",
                index, win.id, win.pid, win.appName, win.title,
                win.frame.minX, win.frame.minY, win.frame.width, win.frame.height,
                ax == nil ? "NG" : "OK",
                ax?.isStandard == true ? "yes" : "no"
            )
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}
