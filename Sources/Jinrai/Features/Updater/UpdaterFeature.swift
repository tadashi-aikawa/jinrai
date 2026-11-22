import AppKit
import JinraiCore

/// メニューの「アップデートを確認…」から起動する確認フロー(NSAlert ベース)。
/// 更新そのものは行わず、Homebrew なら brew のコマンドを、それ以外はリリースページを案内する
@MainActor
final class UpdaterFeature {
    private var checking = false

    func checkForUpdates() {
        guard !checking else { return }
        checking = true
        let currentVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0-development"

        Task { @MainActor in
            // 開発ビルドを含むどのアラートも、閉じるまでは再入させない
            defer { checking = false }
            let content: UpdateAlertContent
            do {
                let result = try await UpdateChecker.check(currentVersion: currentVersion)
                content = .forResult(
                    result, target: UpdateChecker.target,
                    isInstalledViaHomebrew: UpdateChecker.isInstalledViaHomebrew)
            } catch {
                content = .forFailure(
                    errorDescription: error.localizedDescription, target: UpdateChecker.target)
            }
            present(content)
        }
    }

    private func present(_ content: UpdateAlertContent) {
        // クリップボードへ書けなかったときは終了せず、同じアラートを出し直す
        while !presentOnce(content) {}
    }

    /// 出し直しが要らなければ true
    private func presentOnce(_ content: UpdateAlertContent) -> Bool {
        let alert = NSAlert()
        alert.messageText = content.title
        alert.informativeText = content.message
        alert.alertStyle = content.style == .warning ? .warning : .informational
        if let primary = content.primaryButton {
            alert.addButton(withTitle: primary.title)
            alert.addButton(withTitle: UpdateAlertContent.closeButtonTitle)
        }
        let response = alert.runModal()
        guard let primary = content.primaryButton, response == .alertFirstButtonReturn else { return true }

        switch primary.action {
        case .copyCommandAndQuit(let command):
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(command, forType: .string) else { return false }
            NSApp.terminate(nil)
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        }
        return true
    }
}
