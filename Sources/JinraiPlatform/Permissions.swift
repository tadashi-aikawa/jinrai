import AppKit
import ApplicationServices

/// アクセシビリティ(TCC)権限の要求と許可検知
public enum Permissions {
    public static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// 権限があれば即 onGranted。なければシステムのプロンプトを出し、
    /// 許可されるまで1秒間隔でポーリングして検知後に onGranted を呼ぶ。
    public static func ensureAccessibility(onGranted: @escaping @MainActor () -> Void) {
        // kAXTrustedCheckOptionPrompt は Swift 6 の strict concurrency で参照できないため文字列で指定
        let options = ["AXTrustedCheckOptionPrompt": true]
        if AXIsProcessTrustedWithOptions(options as CFDictionary) {
            Task { @MainActor in onGranted() }
            return
        }
        Task { @MainActor in
            pollUntilGranted(onGranted: onGranted)
        }
    }

    @MainActor
    private static func pollUntilGranted(onGranted: @escaping @MainActor () -> Void) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                Task { @MainActor in onGranted() }
            }
        }
    }
}
