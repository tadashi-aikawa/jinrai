import AppKit

/// メニューバー常駐アイコン(元 Jinrai の updater.lua のメニューバー相当)
@MainActor
final class StatusItem {
    private let item: NSStatusItem
    private let permissionMenuItem: NSMenuItem

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

    @objc private func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}
