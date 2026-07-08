import CoreGraphics
import Foundation

/// Window Layouts の適用計画を算出する純ロジック。
/// AX / NSScreen へのアクセスは呼び出し側(WindowLayoutsFeature)が担い、
/// ここではスナップショット(WindowInfo / ScreenInput)だけを見る。
public enum WindowLayoutPlanner {
    /// NSScreen を触らないためのスクリーン情報 DTO
    public struct ScreenInput: Sendable {
        /// ディスプレイ UUID(取得失敗時は nil)
        public var uuid: String?
        /// 作業領域(top-left 原点)
        public var visibleFrame: CGRect
        /// メインディスプレイか(screen 未指定・未接続時のフォールバック先)
        public var isMain: Bool

        public init(uuid: String?, visibleFrame: CGRect, isMain: Bool) {
            self.uuid = uuid
            self.visibleFrame = visibleFrame
            self.isMain = isMain
        }
    }

    /// 1ウィンドウ分の配置指示
    public struct Placement: Equatable, Sendable {
        /// 対応する windows 配列のインデックス
        public var entryIndex: Int
        public var windowID: UInt32
        public var pid: pid_t
        /// 適用先 frame(top-left 原点)
        public var frame: CGRect
        /// 最小化ウィンドウのため、適用前に解除が必要か
        public var needsUnminimize: Bool
    }

    /// 適用計画
    public struct Plan: Equatable, Sendable {
        /// 即時配置するウィンドウ
        public var placements: [Placement]
        /// 未起動かつ launch=true で、起動→出現待ちに回すエントリのインデックス
        public var pendingLaunchIndices: [Int]
        /// 明示フォーカス指定があればそのエントリ、なければ最後にマッチしたエントリのインデックス
        public var focusEntryIndex: Int?
        /// windows[] で focus=true が指定されたエントリのインデックス
        public var preferredFocusEntryIndex: Int?
        /// 従来互換のフォールバック先(最後にマッチしたエントリのインデックス)
        public var fallbackFocusEntryIndex: Int?
    }

    /// エントリ列とスナップショットから適用計画を算出する。
    /// - onScreenWindows: 前面順のオンスクリーンウィンドウ
    /// - minimizedWindows: AX から合成した最小化ウィンドウ(オンスクリーンに無い場合の候補)
    public static func makePlan(
        entries: [WindowLayoutsConfig.WindowEntry],
        onScreenWindows: [WindowInfo],
        minimizedWindows: [WindowInfo],
        runningBundleIDs: Set<String>,
        screens: [ScreenInput]
    ) -> Plan {
        var placements: [Placement] = []
        var pendingLaunchIndices: [Int] = []
        let preferredFocusEntryIndex = entries.firstIndex(where: \.focus)
        var preferredMatchedFocusEntryIndex: Int?
        var fallbackFocusEntryIndex: Int?
        var claimedIDs: Set<UInt32> = []

        for (index, entry) in entries.enumerated() {
            let matched =
                match(entry: entry, in: onScreenWindows, excluding: claimedIDs)
                .map { (window: $0, needsUnminimize: false) }
                ?? match(entry: entry, in: minimizedWindows, excluding: claimedIDs)
                .map { (window: $0, needsUnminimize: true) }
            guard let matched else {
                if entry.launch, !runningBundleIDs.contains(entry.bundleID) {
                    pendingLaunchIndices.append(index)
                }
                continue
            }
            guard let frame = resolveFrame(entry: entry, screens: screens) else { continue }
            claimedIDs.insert(matched.window.id)
            placements.append(
                .init(
                    entryIndex: index,
                    windowID: matched.window.id,
                    pid: matched.window.pid,
                    frame: frame,
                    needsUnminimize: matched.needsUnminimize
                ))
            fallbackFocusEntryIndex = index
            if index == preferredFocusEntryIndex {
                preferredMatchedFocusEntryIndex = index
            }
        }

        return Plan(
            placements: placements,
            pendingLaunchIndices: pendingLaunchIndices,
            focusEntryIndex: preferredMatchedFocusEntryIndex ?? fallbackFocusEntryIndex,
            preferredFocusEntryIndex: preferredFocusEntryIndex,
            fallbackFocusEntryIndex: fallbackFocusEntryIndex
        )
    }

    /// bundleID 完全一致 + titleGlob で最初の1枚を返す(claim 済み ID は除外)。
    /// launch 待機中の再マッチにも使う
    public static func match(
        entry: WindowLayoutsConfig.WindowEntry,
        in windows: [WindowInfo],
        excluding claimedIDs: Set<UInt32> = []
    ) -> WindowInfo? {
        windows.first { window in
            guard !claimedIDs.contains(window.id) else { return false }
            guard window.bundleID == entry.bundleID else { return false }
            guard let glob = entry.titleGlob else { return true }
            return HintKeyAssignment.globMatch(glob, window.title)
        }
    }

    /// screen UUID → エリア frame の解決。未指定・未接続はメインディスプレイへフォールバック
    public static func resolveFrame(
        entry: WindowLayoutsConfig.WindowEntry, screens: [ScreenInput]
    ) -> CGRect? {
        let screen =
            entry.screenUUID.flatMap { uuid in
                screens.first { $0.uuid?.caseInsensitiveCompare(uuid) == .orderedSame }
            }
            ?? screens.first(where: \.isMain)
            ?? screens.first
        guard let screen else { return nil }
        return AreaSpec.frame(for: entry.area, screenFrame: screen.visibleFrame)
    }
}
