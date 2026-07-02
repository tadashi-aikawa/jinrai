import AppKit
import ApplicationServices

/// フォーカスウィンドウの変化を監視する(元 hs.window.filter の windowFocused 購読相当)。
/// アプリごとに AXObserver(kAXFocusedWindowChanged)を登録し、
/// アプリ切替は NSWorkspace.didActivateApplicationNotification で捕捉する。
@MainActor
public final class FocusObserver {
    public var onFocusChanged: ((AXWindow?) -> Void)?

    private var axObservers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []

    public init() {}

    public func start() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.append(
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil, queue: .main
            ) { [weak self] notification in
                let app =
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
                Task { @MainActor in
                    guard let self else { return }
                    if let app {
                        self.registerAXObserver(pid: app.processIdentifier)
                    }
                    self.notifyFocusChanged()
                }
            })
        workspaceTokens.append(
            center.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil, queue: .main
            ) { [weak self] notification in
                let app =
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
                Task { @MainActor in
                    guard let self, let app else { return }
                    self.removeAXObserver(pid: app.processIdentifier)
                }
            })

        // 既存の起動中アプリにも observer を張る
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            registerAXObserver(pid: app.processIdentifier)
        }
        notifyFocusChanged()
    }

    public func stop() {
        for token in workspaceTokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        workspaceTokens = []
        for pid in Array(axObservers.keys) {
            removeAXObserver(pid: pid)
        }
    }

    func notifyFocusChanged() {
        onFocusChanged?(WindowEnumerator.focusedWindow())
    }

    private func registerAXObserver(pid: pid_t) {
        guard axObservers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let this = Unmanaged<FocusObserver>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                this.notifyFocusChanged()
            }
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
            return
        }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(
            observer, appElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(
            observer, appElement, kAXMainWindowChangedNotification as CFString, refcon)
        CFRunLoopAddSource(
            CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        axObservers[pid] = observer
    }

    private func removeAXObserver(pid: pid_t) {
        guard let observer = axObservers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }
}
