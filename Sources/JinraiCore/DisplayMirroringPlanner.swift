import Foundation

/// ミラーリング判定に使うディスプレイ1台分の状態(CGDirectDisplayID を UInt32 で持つ)
public struct DisplayMirrorState: Equatable, Sendable {
    public var id: UInt32
    public var isBuiltin: Bool
    public var isMain: Bool
    /// このディスプレイが映している元のディスプレイ(ミラーしていなければ nil)
    public var mirrorSource: UInt32?

    public init(id: UInt32, isBuiltin: Bool, isMain: Bool, mirrorSource: UInt32? = nil) {
        self.id = id
        self.isBuiltin = isBuiltin
        self.isMain = isMain
        self.mirrorSource = mirrorSource
    }
}

/// ミラーリングと拡張表示のトグルで行う操作
public enum DisplayMirroringPlan: Equatable, Sendable {
    /// targets のディスプレイに source を映す
    case mirror(source: UInt32, targets: [UInt32])
    /// displays のミラーリングを解除して拡張表示に戻す
    case extend(displays: [UInt32])
    /// ディスプレイが1台以下で切り替える相手がいない
    case unavailable
}

public enum DisplayMirroringPlanner {
    /// 現在の状態からトグル後の操作を決める。
    /// - 1台でもミラーしていれば、ミラーしている全ディスプレイを解除して拡張表示にする
    /// - どれもミラーしていなければ、内蔵ディスプレイ(無ければメイン)を残りの全ディスプレイへ映す
    public static func plan(_ displays: [DisplayMirrorState]) -> DisplayMirroringPlan {
        guard displays.count >= 2 else { return .unavailable }

        let mirroring = displays.filter { $0.mirrorSource != nil }.map(\.id)
        if !mirroring.isEmpty {
            return .extend(displays: mirroring)
        }

        guard
            let source = displays.first(where: \.isBuiltin) ?? displays.first(where: \.isMain)
                ?? displays.first
        else { return .unavailable }
        let targets = displays.map(\.id).filter { $0 != source.id }
        return .mirror(source: source.id, targets: targets)
    }
}
