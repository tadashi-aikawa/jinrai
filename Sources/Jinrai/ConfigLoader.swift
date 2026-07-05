import AppKit
import JinraiCore

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

    /// 設定を読み込む。ファイルがなければテンプレートを生成して読み込む
    static func load() throws -> RootConfig {
        let url = configFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? DefaultConfigTemplate.text.write(to: url, atomically: true, encoding: .utf8)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try RootConfigBuilder.build(text: text)
    }
}
