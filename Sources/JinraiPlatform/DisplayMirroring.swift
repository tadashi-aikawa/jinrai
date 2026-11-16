import CoreGraphics
import JinraiCore

/// ミラーリングと拡張表示の切替(CoreGraphics のディスプレイ構成 API)
public enum DisplayMirroring {
    /// 接続中の全ディスプレイの状態。ミラー先のディスプレイも含めるため online の一覧を使う
    /// (active の一覧はハードウェアミラーの映し先を含まない)
    public static func onlineDisplays() -> [DisplayMirrorState] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        let mainID = CGMainDisplayID()
        return ids.prefix(Int(count)).map { id in
            let source = CGDisplayMirrorsDisplay(id)
            return DisplayMirrorState(
                id: id,
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                isMain: id == mainID,
                mirrorSource: source == kCGNullDirectDisplay ? nil : source
            )
        }
    }

    /// 計画を適用する。失敗したら構成を取り消して false を返す。
    /// システム設定で切り替えたときと同じく、macOS がディスプレイの組み合わせごとに覚えるよう永続化する
    @discardableResult
    public static func apply(_ plan: DisplayMirroringPlan) -> Bool {
        let pairs: [(display: CGDirectDisplayID, source: CGDirectDisplayID)]
        switch plan {
        case .mirror(let source, let targets):
            pairs = targets.map { ($0, source) }
        case .extend(let displays):
            pairs = displays.map { ($0, kCGNullDirectDisplay) }
        case .unavailable:
            return false
        }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        for pair in pairs {
            let error = CGConfigureDisplayMirrorOfDisplay(config, pair.display, pair.source)
            if error != .success {
                CGCancelDisplayConfiguration(config)
                return false
            }
        }
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}
