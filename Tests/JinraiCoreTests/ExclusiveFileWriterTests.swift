import Foundation
import Testing

@testable import JinraiCore

@Suite("ExclusiveFileWriter")
final class ExclusiveFileWriterTests {
    private let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExclusiveFileWriterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    private func entries() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    /// 雛形の書き出しが投げた CocoaError のコード。成功か CocoaError 以外なら nil
    private func writeErrorCode(to url: URL) -> CocoaError.Code? {
        do {
            try ExclusiveFileWriter.write(Data("template".utf8), to: url)
            return nil
        } catch let error as CocoaError {
            return error.code
        } catch {
            return nil
        }
    }

    @Test("ファイルが無ければ書き出し、一時ファイルは残らない")
    func writesNewFile() throws {
        let url = dir.appendingPathComponent("config.jsonc")
        try ExclusiveFileWriter.write(Data("template".utf8), to: url)
        #expect(try String(contentsOf: url, encoding: .utf8) == "template")
        #expect(try entries() == ["config.jsonc"])
    }

    @Test("既存のファイルを上書きせず、一時ファイルも残らない")
    func doesNotOverwriteExistingFile() throws {
        let url = dir.appendingPathComponent("config.jsonc")
        try Data("user".utf8).write(to: url)
        #expect(writeErrorCode(to: url) == .fileWriteFileExists)
        #expect(try String(contentsOf: url, encoding: .utf8) == "user")
        #expect(try entries() == ["config.jsonc"])
    }

    @Test("リンク切れのシンボリックリンクも置き換えず、リンク先も作らない")
    func doesNotReplaceBrokenSymlink() throws {
        let url = dir.appendingPathComponent("config.jsonc")
        let destination = dir.appendingPathComponent("missing.jsonc")
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: destination)
        #expect(writeErrorCode(to: url) == .fileWriteFileExists)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: url.path) == destination.path)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try entries() == ["config.jsonc"])
    }

    @Test("配置先のディレクトリが無く失敗しても、何も残らない")
    func failsWithoutLeavingFiles() throws {
        let url = dir.appendingPathComponent("absent/config.jsonc")
        #expect(throws: (any Error).self) {
            try ExclusiveFileWriter.write(Data("template".utf8), to: url)
        }
        #expect(try entries() == [])
    }
}
