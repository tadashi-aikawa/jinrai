import Foundation
import JinraiCore

/// GitHub Releases API で最新版を確認する
enum UpdateChecker {
    static let repo = "tadashi-aikawa/jinrai"

    struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }
    }

    struct LatestRelease {
        let version: SemanticVersion
        let zipURL: URL
        let releasePageURL: URL
    }

    enum CheckResult {
        /// 新しいバージョンがある
        case updateAvailable(LatestRelease)
        /// 既に最新
        case upToDate(SemanticVersion)
        /// 開発ビルド(0.0.0-development)なのでチェック対象外
        case developmentBuild
    }

    static func check(currentVersion: String) async throws -> CheckResult {
        guard let current = SemanticVersion(currentVersion) else {
            return .developmentBuild
        }

        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.apiFailed(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let release = try JSONDecoder().decode(Release.self, from: data)
        guard let latest = SemanticVersion(release.tagName) else {
            throw UpdateError.invalidTag(release.tagName)
        }
        guard current < latest else {
            return .upToDate(current)
        }
        guard
            let asset = release.assets.first(where: {
                $0.name == "JINRAI-\(latest.description).zip"
            })
        else {
            throw UpdateError.assetNotFound(tag: release.tagName)
        }
        return .updateAvailable(
            LatestRelease(
                version: latest,
                zipURL: asset.browserDownloadURL,
                releasePageURL: release.htmlURL))
    }
}

enum UpdateError: LocalizedError {
    case apiFailed(statusCode: Int)
    case invalidTag(String)
    case assetNotFound(tag: String)
    case extractionFailed
    case signatureMismatch
    case notWritable(path: String)

    var errorDescription: String? {
        switch self {
        case .apiFailed(let statusCode):
            return "GitHub API の呼び出しに失敗しました (HTTP \(statusCode))"
        case .invalidTag(let tag):
            return "リリースタグを解釈できませんでした: \(tag)"
        case .assetNotFound(let tag):
            return "リリース \(tag) に JINRAI の zip が見つかりませんでした"
        case .extractionFailed:
            return "ダウンロードした zip の展開に失敗しました"
        case .signatureMismatch:
            return "ダウンロードしたアプリの署名検証に失敗しました"
        case .notWritable(let path):
            return "\(path) に書き込みできないため更新できません"
        }
    }
}
