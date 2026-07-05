import AppKit
import Foundation

/// zip のダウンロード → 展開 → 実行中 .app の置き換え → 再起動。
/// 実行中でも .app バンドルの rename は可能(実行バイナリは inode でマップ済み)なので、
/// Sparkle のような終了後置換ヘルパーは不要。
enum UpdateInstaller {
    /// Homebrew cask でインストールされている場合は brew と version/sha256 が
    /// 乖離するため自前更新しない(brew upgrade を案内する)
    static var isInstalledViaHomebrew: Bool {
        ["/opt/homebrew/Caskroom/jinrai", "/usr/local/Caskroom/jinrai"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    static func downloadAndInstall(zipURL: URL) async throws {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("jinrai-update-\(UUID().uuidString)")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        // ダウンロード
        let (downloaded, _) = try await URLSession.shared.download(from: zipURL)
        let zipPath = workDir.appendingPathComponent("JINRAI.zip")
        try fm.moveItem(at: downloaded, to: zipPath)

        // 展開(ditto は xattr も復元する)
        let extractDir = workDir.appendingPathComponent("extracted")
        try runProcess("/usr/bin/ditto", ["-x", "-k", zipPath.path, extractDir.path])
        let newApp = extractDir.appendingPathComponent("JINRAI.app")
        guard fm.fileExists(atPath: newApp.path) else {
            throw UpdateError.extractionFailed
        }

        // 万一 quarantine が付いていても除去(自プロセスのダウンロードには通常付かないが防御的に)
        try? runProcess("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

        // 署名検証: 破損・改ざん zip での置き換え事故を防ぐ
        try verifySignature(of: newApp)

        // 置き換え(rename 2 回方式)。旧 .app と同じ親ディレクトリ内で rename する
        // (別ボリュームへの move は実行中バンドルでは失敗しうるため)
        let currentApp = Bundle.main.bundleURL
        let parent = currentApp.deletingLastPathComponent()
        guard fm.isWritableFile(atPath: parent.path) else {
            throw UpdateError.notWritable(path: parent.path)
        }
        let backup = parent.appendingPathComponent(".JINRAI.app.old")
        try? fm.removeItem(at: backup)
        try fm.moveItem(at: currentApp, to: backup)
        do {
            try fm.moveItem(at: newApp, to: currentApp)
        } catch {
            // 失敗したら旧版を戻す
            try? fm.moveItem(at: backup, to: currentApp)
            throw error
        }
        try? fm.removeItem(at: backup)
    }

    /// 新しいバンドルを起動して自分は終了する。
    /// open は LaunchServices 経由なので置換後の新バンドルが確実に起動される。
    /// -n は付けない(旧プロセスは直後に terminate するため同時起動を避ける)
    static func relaunch() {
        let appPath = Bundle.main.bundleURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"\(appPath)\""]
        try? process.run()
        NSApp.terminate(nil)
    }

    /// codesign --verify に加え、現行アプリと署名者(designated requirement)が
    /// 一致することを確認する。一致しない更新は TCC 許可が剥がれるため拒否する。
    /// ただし現行が ad-hoc / 開発ビルドの場合は比較をスキップする
    private static func verifySignature(of newApp: URL) throws {
        do {
            try runProcess("/usr/bin/codesign", ["--verify", "--deep", newApp.path])
        } catch {
            throw UpdateError.signatureMismatch
        }

        guard
            let currentDR = designatedRequirement(of: Bundle.main.bundleURL),
            currentDR.contains("jinrai-dev")
        else { return }
        guard designatedRequirement(of: newApp) == currentDR else {
            throw UpdateError.signatureMismatch
        }
    }

    private static func designatedRequirement(of app: URL) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dr", "-", app.path]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .split(separator: "\n")
            .first { $0.hasPrefix("designated =>") }
            .map(String.init)
    }

    private static func runProcess(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.extractionFailed
        }
    }
}
