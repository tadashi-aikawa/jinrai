import Foundation
import Testing

@testable import JinraiCore

private let target = UpdateTarget(appName: "JINRAI", cask: "jinrai")
private let releasePage = URL(string: "https://github.com/tadashi-aikawa/jinrai/releases/tag/v0.9.0")!

private func latestBody(tag: String) -> Data {
    Data(
        """
        {"tag_name": "\(tag)", "html_url": "\(releasePage.absoluteString)", "assets": []}
        """.utf8)
}

private struct NetworkDown: Error {}

@Suite("UpdateTarget")
struct UpdateTargetTests {
    @Test("cask 名から repo・URL・Caskroom・brew のコマンドを組み立てる")
    func derivedValues() {
        #expect(target.repo == "tadashi-aikawa/jinrai")
        #expect(
            target.latestReleaseAPIURL.absoluteString
                == "https://api.github.com/repos/tadashi-aikawa/jinrai/releases/latest")
        #expect(target.releasesPageURL.absoluteString == "https://github.com/tadashi-aikawa/jinrai/releases")
        #expect(target.caskroomPaths == ["/opt/homebrew/Caskroom/jinrai", "/usr/local/Caskroom/jinrai"])
        #expect(target.brewUpgradeCommand == "brew update && brew upgrade --cask jinrai && open -a JINRAI")
    }
}

@Suite("UpdateCheckLogic")
struct UpdateCheckLogicTests {
    @Test("SemVer として読めない現在のバージョンは API を呼ばずに開発ビルド")
    func developmentBuildSkipsFetch() async throws {
        var fetched = false
        let result = try await UpdateCheckLogic.check(currentVersion: "0.0.0-development") {
            fetched = true
            return (200, latestBody(tag: "v0.9.0"))
        }
        #expect(result == .developmentBuild(currentVersion: "0.0.0-development"))
        #expect(!fetched)
    }

    @Test("新しいバージョンがあれば html_url をリリースページにする")
    func updateAvailable() async throws {
        let result = try await UpdateCheckLogic.check(currentVersion: "0.8.0") {
            (200, latestBody(tag: "v0.9.0"))
        }
        #expect(
            result
                == .updateAvailable(
                    current: SemanticVersion(major: 0, minor: 8, patch: 0),
                    latest: SemanticVersion(major: 0, minor: 9, patch: 0),
                    releasePageURL: releasePage))
    }

    @Test("同じか古いバージョンなら最新")
    func upToDate() async throws {
        for current in ["0.9.0", "0.10.0"] {
            let result = try await UpdateCheckLogic.check(currentVersion: current) {
                (200, latestBody(tag: "v0.9.0"))
            }
            #expect(result == .upToDate(current: SemanticVersion(current)!))
        }
    }

    @Test("200 以外は HTTP ステータス付きの API 失敗")
    func apiFailed() async {
        await #expect(throws: UpdateCheckError.apiFailed(statusCode: 403)) {
            try await UpdateCheckLogic.check(currentVersion: "0.8.0") { (403, Data()) }
        }
    }

    @Test("タグを SemVer として読めなければ失敗")
    func invalidTag() async {
        await #expect(throws: UpdateCheckError.invalidTag("nightly")) {
            try await UpdateCheckLogic.check(currentVersion: "0.8.0") {
                (200, latestBody(tag: "nightly"))
            }
        }
    }

    @Test("tag_name の無い応答は失敗")
    func missingTagName() async {
        await #expect(throws: DecodingError.self) {
            try await UpdateCheckLogic.check(currentVersion: "0.8.0") {
                (200, Data(#"{"html_url": "\#(releasePage.absoluteString)"}"#.utf8))
            }
        }
    }

    @Test("assets キーの無い応答は成功")
    func missingAssets() async throws {
        let result = try await UpdateCheckLogic.check(currentVersion: "0.8.0") {
            (200, Data(#"{"tag_name": "v0.9.0", "html_url": "\#(releasePage.absoluteString)"}"#.utf8))
        }
        #expect(
            result
                == .updateAvailable(
                    current: SemanticVersion(major: 0, minor: 8, patch: 0),
                    latest: SemanticVersion(major: 0, minor: 9, patch: 0),
                    releasePageURL: releasePage))
    }

    @Test("通信エラーはそのまま投げる")
    func networkError() async {
        await #expect(throws: NetworkDown.self) {
            try await UpdateCheckLogic.check(currentVersion: "0.8.0") { throw NetworkDown() }
        }
    }

    @Test("エラー文")
    func errorDescriptions() {
        #expect(
            UpdateCheckError.apiFailed(statusCode: 404).localizedDescription
                == "GitHub API の呼び出しに失敗しました (HTTP 404)")
        #expect(UpdateCheckError.invalidTag("nightly").localizedDescription == "リリースタグを解釈できませんでした: nightly")
    }
}

@Suite("UpdateAlertContent")
struct UpdateAlertContentTests {
    private let current = SemanticVersion(major: 0, minor: 8, patch: 0)
    private let latest = SemanticVersion(major: 0, minor: 9, patch: 0)

    @Test("開発ビルド")
    func developmentBuild() {
        let content = UpdateAlertContent.forResult(
            .developmentBuild(currentVersion: "0.0.0-development"), target: target,
            isInstalledViaHomebrew: false)
        #expect(content.title == "開発ビルドです")
        #expect(content.message == "開発ビルド(0.0.0-development)ではアップデート確認をスキップします。")
        #expect(content.style == .informational)
        #expect(content.primaryButton == nil)
    }

    @Test("最新")
    func upToDate() {
        let content = UpdateAlertContent.forResult(
            .upToDate(current: current), target: target, isInstalledViaHomebrew: true)
        #expect(content.title == "最新版です")
        #expect(content.message == "JINRAI v0.8.0 は最新です。")
        #expect(content.primaryButton == nil)
    }

    @Test("新しいバージョンあり・Homebrew はコマンドをコピーして終了")
    func updateAvailableViaHomebrew() {
        let content = UpdateAlertContent.forResult(
            .updateAvailable(current: current, latest: latest, releasePageURL: releasePage),
            target: target, isInstalledViaHomebrew: true)
        let command = "brew update && brew upgrade --cask jinrai && open -a JINRAI"
        #expect(content.title == "v0.9.0 が利用可能です")
        #expect(
            content.message
                == "Homebrew でインストールされているため、以下のコマンドで更新してください。\n\n\(command)\n\nコピーすると JINRAI は終了します(更新完了後に自動で起動します)。"
        )
        #expect(content.style == .informational)
        #expect(
            content.primaryButton
                == .init(title: "コマンドをコピーして終了", action: .copyCommandAndQuit(command: command)))
    }

    @Test("新しいバージョンあり・Homebrew 以外は html_url のリリースページを開く")
    func updateAvailableWithoutHomebrew() {
        let content = UpdateAlertContent.forResult(
            .updateAvailable(current: current, latest: latest, releasePageURL: releasePage),
            target: target, isInstalledViaHomebrew: false)
        #expect(content.title == "v0.9.0 が利用可能です")
        #expect(content.message == "現在のバージョン: 0.8.0\nリリースページから新しいバージョンを入手できます。")
        #expect(content.primaryButton == .init(title: "リリースページを開く", action: .openURL(releasePage)))
    }

    @Test("失敗は警告スタイルで、リリース一覧のページを開く")
    func failure() {
        let content = UpdateAlertContent.forFailure(
            errorDescription: "GitHub API の呼び出しに失敗しました (HTTP 404)", target: target)
        #expect(content.title == "アップデートを確認できませんでした")
        #expect(
            content.message
                == "GitHub API の呼び出しに失敗しました (HTTP 404)\n\nリリースページで最新のバージョンを確認できます。")
        #expect(content.style == .warning)
        #expect(
            content.primaryButton
                == .init(
                    title: "リリースページを開く",
                    action: .openURL(URL(string: "https://github.com/tadashi-aikawa/jinrai/releases")!)))
        #expect(UpdateAlertContent.closeButtonTitle == "閉じる")
    }
}
