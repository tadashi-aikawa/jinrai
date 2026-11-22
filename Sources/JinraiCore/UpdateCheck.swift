import Foundation

/// アップデート確認の対象アプリ。repo は `tadashi-aikawa/<cask>`
public struct UpdateTarget: Equatable, Sendable {
    /// メニューや文言に出す表示名(JINRAI)
    public let appName: String
    /// Homebrew の cask 名(jinrai)
    public let cask: String

    public init(appName: String, cask: String) {
        self.appName = appName
        self.cask = cask
    }

    public var repo: String { "tadashi-aikawa/\(cask)" }

    public var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    }

    public var releasesPageURL: URL {
        URL(string: "https://github.com/\(repo)/releases")!
    }

    /// cask の Caskroom ディレクトリ。どちらかがあれば Homebrew でインストールされている
    public var caskroomPaths: [String] {
        ["/opt/homebrew/Caskroom/\(cask)", "/usr/local/Caskroom/\(cask)"]
    }

    /// brew が .app を置き換えても起動中のプロセスは古いまま動き続けるため、
    /// 末尾の open -a で新しいバージョンを起動させる
    public var brewUpgradeCommand: String {
        "brew update && brew upgrade --cask \(cask) && open -a \(appName)"
    }
}

/// GitHub Releases API `releases/latest` の応答のうち、アップデート確認に使う項目
public struct LatestReleaseResponse: Decodable, Equatable, Sendable {
    public let tagName: String
    public let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

public enum UpdateCheckResult: Equatable, Sendable {
    /// 現在のバージョンが SemVer として読めない(0.0.0-development 等)ので確認しない
    case developmentBuild(currentVersion: String)
    /// 既に最新
    case upToDate(current: SemanticVersion)
    /// 新しいバージョンがある
    case updateAvailable(current: SemanticVersion, latest: SemanticVersion, releasePageURL: URL)
}

public enum UpdateCheckError: LocalizedError, Equatable {
    case apiFailed(statusCode: Int)
    case invalidTag(String)

    public var errorDescription: String? {
        switch self {
        case .apiFailed(let statusCode):
            return "GitHub API の呼び出しに失敗しました (HTTP \(statusCode))"
        case .invalidTag(let tag):
            return "リリースタグを解釈できませんでした: \(tag)"
        }
    }
}

public enum UpdateCheckLogic {
    /// 現在のバージョンが SemVer として読めなければ、API を呼ばずに開発ビルドとする。
    /// `fetchLatestRelease` は `releases/latest` の HTTP ステータス(HTTP 以外の応答なら -1)と本文を返す。
    /// 通信エラーは `fetchLatestRelease` が投げたものをそのまま投げる
    public static func check(
        currentVersion: String,
        fetchLatestRelease: () async throws -> (statusCode: Int, body: Data)
    ) async throws -> UpdateCheckResult {
        guard let current = SemanticVersion(currentVersion) else {
            return .developmentBuild(currentVersion: currentVersion)
        }
        let (statusCode, body) = try await fetchLatestRelease()
        guard statusCode == 200 else {
            throw UpdateCheckError.apiFailed(statusCode: statusCode)
        }
        let release = try JSONDecoder().decode(LatestReleaseResponse.self, from: body)
        guard let latest = SemanticVersion(release.tagName) else {
            throw UpdateCheckError.invalidTag(release.tagName)
        }
        guard current < latest else {
            return .upToDate(current: current)
        }
        return .updateAvailable(current: current, latest: latest, releasePageURL: release.htmlURL)
    }
}

/// アップデート確認の結果として出す NSAlert の中身
public struct UpdateAlertContent: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        case informational
        case warning
    }

    public enum Action: Equatable, Sendable {
        /// コマンドをクリップボードへ入れてアプリを終了する
        case copyCommandAndQuit(command: String)
        case openURL(URL)
    }

    public struct Button: Equatable, Sendable {
        public let title: String
        public let action: Action
    }

    /// primaryButton の隣に並べるボタン
    public static let closeButtonTitle = "閉じる"

    public let title: String
    public let message: String
    public let style: Style
    /// nil なら既定の OK だけ。あれば「閉じる」と並べる
    public let primaryButton: Button?

    public static func forResult(
        _ result: UpdateCheckResult, target: UpdateTarget, isInstalledViaHomebrew: Bool
    ) -> UpdateAlertContent {
        switch result {
        case .developmentBuild(let currentVersion):
            return UpdateAlertContent(
                title: "開発ビルドです",
                message: "開発ビルド(\(currentVersion))ではアップデート確認をスキップします。",
                style: .informational,
                primaryButton: nil)

        case .upToDate(let current):
            return UpdateAlertContent(
                title: "最新版です",
                message: "\(target.appName) v\(current.description) は最新です。",
                style: .informational,
                primaryButton: nil)

        case .updateAvailable(let current, let latest, let releasePageURL):
            let title = "v\(latest.description) が利用可能です"
            guard isInstalledViaHomebrew else {
                return UpdateAlertContent(
                    title: title,
                    message: "現在のバージョン: \(current.description)\nリリースページから新しいバージョンを入手できます。",
                    style: .informational,
                    primaryButton: Button(title: "リリースページを開く", action: .openURL(releasePageURL)))
            }
            let command = target.brewUpgradeCommand
            return UpdateAlertContent(
                title: title,
                message: """
                    Homebrew でインストールされているため、以下のコマンドで更新してください。

                    \(command)

                    コピーすると \(target.appName) は終了します(更新完了後に自動で起動します)。
                    """,
                style: .informational,
                primaryButton: Button(
                    title: "コマンドをコピーして終了", action: .copyCommandAndQuit(command: command)))
        }
    }

    public static func forFailure(errorDescription: String, target: UpdateTarget) -> UpdateAlertContent {
        UpdateAlertContent(
            title: "アップデートを確認できませんでした",
            message: "\(errorDescription)\n\nリリースページで最新のバージョンを確認できます。",
            style: .warning,
            primaryButton: Button(title: "リリースページを開く", action: .openURL(target.releasesPageURL)))
    }
}
