import AppKit
import JinraiCore

/// メニューの「アップデートを確認…」から起動する更新フロー(NSAlert ベース)
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
            defer { checking = false }
            do {
                let result = try await UpdateChecker.check(currentVersion: currentVersion)
                handle(result)
            } catch {
                showError(error)
            }
        }
    }

    private func handle(_ result: UpdateChecker.CheckResult) {
        switch result {
        case .developmentBuild:
            let alert = NSAlert()
            alert.messageText = "開発ビルドです"
            alert.informativeText = "開発ビルド(\(versionString()))ではアップデート確認をスキップします。"
            alert.runModal()

        case .upToDate(let version):
            let alert = NSAlert()
            alert.messageText = "最新版です"
            alert.informativeText = "JINRAI v\(version.description) は最新です。"
            alert.runModal()

        case .updateAvailable(let release):
            if UpdateInstaller.isInstalledViaHomebrew {
                promptBrewUpgrade(release)
            } else {
                promptInstall(release)
            }
        }
    }

    private func promptInstall(_ release: UpdateChecker.LatestRelease) {
        let alert = NSAlert()
        alert.messageText = "v\(release.version.description) が利用可能です"
        alert.informativeText = "現在のバージョン: \(versionString())\n更新すると JINRAI は自動で再起動します。"
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "リリースノートを見る")
        alert.addButton(withTitle: "キャンセル")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            install(release)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(release.releasePageURL)
        default:
            break
        }
    }

    /// brew 管理下では自前更新すると cask の version/sha256 と乖離するため案内のみ
    private func promptBrewUpgrade(_ release: UpdateChecker.LatestRelease) {
        let command = "brew upgrade --cask jinrai"
        let alert = NSAlert()
        alert.messageText = "v\(release.version.description) が利用可能です"
        alert.informativeText =
            "Homebrew でインストールされているため、以下のコマンドで更新してください。\n\n\(command)"
        alert.addButton(withTitle: "コマンドをコピー")
        alert.addButton(withTitle: "閉じる")
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
    }

    private func install(_ release: UpdateChecker.LatestRelease) {
        Task { @MainActor in
            do {
                try await UpdateInstaller.downloadAndInstall(zipURL: release.zipURL)
                UpdateInstaller.relaunch()
            } catch {
                showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "アップデートに失敗しました"
        alert.informativeText = "\(error.localizedDescription)\n\nリリースページから手動で更新できます。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "リリースページを開く")
        alert.addButton(withTitle: "閉じる")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "https://github.com/\(UpdateChecker.repo)/releases")!)
        }
    }

    private func versionString() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0-development"
    }
}
