import AppKit
import JinraiCore
import JinraiPlatform

/// ~/.config/jinrai/config.jsonc の読込($XDG_CONFIG_HOME 尊重)
enum ConfigLoader {
    static var configFileURL: URL {
        let base: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config")
        }
        return base.appendingPathComponent("jinrai/config.jsonc")
    }

    /// 設定ファイルがシンボリックリンクで、リンク先が無いか
    /// (dotfiles 管理などでリンクにしている場合、テンプレートで実体を作るとリンクを潰す)
    static func isBrokenSymlink(_ url: URL) -> Bool {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            attributes[.type] as? FileAttributeType == .typeSymbolicLink
        else { return false }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    /// ファイルが無ければテンプレートを生成する。リンク切れのときは作らずにエラーにする
    static func ensureConfigFileExists() throws {
        let url = configFileURL
        let brokenSymlinkError = ConfigError("設定ファイルのシンボリックリンクのリンク先がありません: \(url.path)")
        if isBrokenSymlink(url) {
            throw brokenSymlinkError
        }
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // 確かめてから書くまでに別のプロセスがファイルやリンクを作っても、上書きしない。
        // 書き切ってから配置するので、途中までのファイルも残らない
        do {
            try ExclusiveFileWriter.write(Data(DefaultConfigTemplate.text.utf8), to: url)
        } catch CocoaError.fileWriteFileExists {
            if isBrokenSymlink(url) {
                throw brokenSymlinkError
            }
        }
    }

    /// 設定を読み込む。ファイルがなければテンプレートを生成して読み込む
    @MainActor
    static func load() throws -> RootConfig {
        try? ensureConfigFileExists()
        let text = try String(contentsOf: configFileURL, encoding: .utf8)
        return try RootConfigBuilder.build(
            text: text, connectedDisplayUUIDs: ScreenUtil.connectedDisplayUUIDs())
    }

    /// 設定ファイルをエディタで開く。.jsonc を開くアプリが無いか開けなければテキストエディットで開く
    @MainActor
    static func openInEditor() {
        do {
            try ensureConfigFileExists()
        } catch {
            showOpenError("\(error)")
            return
        }
        let url = configFileURL
        if NSWorkspace.shared.urlForApplication(toOpen: url) != nil, NSWorkspace.shared.open(url) {
            return
        }
        guard
            let textEdit = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.TextEdit")
        else {
            showOpenError(url.path)
            return
        }
        NSWorkspace.shared.open(
            [url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard let error else { return }
            Task { @MainActor in showOpenError("\(error.localizedDescription)\n\n\(url.path)") }
        }
    }

    @MainActor
    private static func showOpenError(_ detail: String) {
        let alert = NSAlert()
        alert.messageText = "設定ファイルを開けません"
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.runModal()
    }
}
