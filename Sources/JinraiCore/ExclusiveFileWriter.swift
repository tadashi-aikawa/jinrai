import Foundation

/// 既存のファイルを置き換えずにファイルを作る。
/// テストを書くため Core に置く(AppKit には依存しない)
public enum ExclusiveFileWriter {
    /// data を同じディレクトリの一時ファイルへ書き切ってから、`link(2)` で url へ配置する。
    /// 途中までのファイルが url に残らず、url に何か(リンク切れのシンボリックリンクを含む)があれば
    /// 置き換えずに `CocoaError(.fileWriteFileExists)` を投げる。一時ファイルは成否によらず消す
    public static func write(_ data: Data, to url: URL) throws {
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temp) }
        try data.write(to: temp, options: .withoutOverwriting)

        guard link(temp.path, url.path) == 0 else {
            let code = errno
            if code == EEXIST {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: url.path])
            }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
    }
}
