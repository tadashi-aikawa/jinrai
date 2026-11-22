import Foundation
import JinraiCore

/// GitHub Releases API で最新版を確認する
enum UpdateChecker {
    static let target = UpdateTarget(appName: "JINRAI", cask: "jinrai")

    /// Homebrew cask でインストールされているか。brew 管理下は brew upgrade を案内する
    static var isInstalledViaHomebrew: Bool {
        target.caskroomPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    static func check(currentVersion: String) async throws -> UpdateCheckResult {
        try await UpdateCheckLogic.check(currentVersion: currentVersion) {
            var request = URLRequest(url: target.latestReleaseAPIURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            return ((response as? HTTPURLResponse)?.statusCode ?? -1, data)
        }
    }
}
