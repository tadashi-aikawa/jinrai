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
        /// マッチするウィンドウが無く、起動(reopen / URL open)→出現待ちに回すエントリのインデックス
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
        screens: [ScreenInput]
    ) -> Plan {
        var placements: [Placement] = []
        var pendingLaunchIndices: [Int] = []
        let bundleIDsWithWindows = Set(
            onScreenWindows.compactMap(\.bundleID) + minimizedWindows.compactMap(\.bundleID))
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
                switch entry.launch {
                case .none:
                    break
                case .app:
                    // reopen は既存ウィンドウがあると新規ウィンドウを作れないため、
                    // bundleID のウィンドウが1枚も無いときだけ起動する
                    if !bundleIDsWithWindows.contains(entry.bundleID) {
                        pendingLaunchIndices.append(index)
                    }
                case .newWindowURL:
                    // URL スキームは起動済みアプリにも目的のウィンドウを開かせられるため、
                    // 同アプリの別ウィンドウがあっても発火する
                    pendingLaunchIndices.append(index)
                }
                continue
            }
            guard
                let frame = resolveFrame(
                    entry: entry, screens: screens, windowFrame: matched.window.frame)
            else { continue }
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

        // Pass 2: 未確保のオンスクリーンウィンドウのうち、ちょうど1エントリにだけ
        // マッチするものは、そのエントリと同じ位置へ追加配置する(全取り)。
        // 複数エントリにマッチしうるウィンドウは競合とみなし、先勝ち1枚の Pass 1 の結果に任せる
        for window in onScreenWindows where !claimedIDs.contains(window.id) {
            let matchedIndices = entries.indices.filter { matches(entry: entries[$0], window: window) }
            guard matchedIndices.count == 1, let index = matchedIndices.first else { continue }
            guard
                let frame = resolveFrame(
                    entry: entries[index], screens: screens, windowFrame: window.frame)
            else { continue }
            claimedIDs.insert(window.id)
            placements.append(
                .init(
                    entryIndex: index,
                    windowID: window.id,
                    pid: window.pid,
                    frame: frame,
                    needsUnminimize: false
                ))
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
            !claimedIDs.contains(window.id) && matches(entry: entry, window: window)
        }
    }

    /// bundleID 完全一致 + titleGlob のマッチ判定
    public static func matches(
        entry: WindowLayoutsConfig.WindowEntry, window: WindowInfo
    ) -> Bool {
        guard window.bundleID == entry.bundleID else { return false }
        guard let glob = entry.titleGlob else { return true }
        return HintKeyAssignment.globMatch(glob, window.title)
    }

    /// レイアウト適用で確保したウィンドウ以外を、閉じる候補として返す。
    /// 呼び出し側でオンスクリーン標準ウィンドウに絞ったスナップショットを渡す。
    public static func unlistedWindows(
        from windows: [WindowInfo], keeping keptIDs: Set<UInt32>
    ) -> [WindowInfo] {
        windows.filter { !keptIDs.contains($0.id) }
    }

    /// screen UUID → エリア frame の解決。未指定・未接続時はウィンドウが現在いる
    /// ディスプレイ、それも判定できなければメインディスプレイへフォールバック
    public static func resolveFrame(
        entry: WindowLayoutsConfig.WindowEntry, screens: [ScreenInput],
        windowFrame: CGRect? = nil
    ) -> CGRect? {
        resolveFrame(
            screenUUID: entry.screenUUID, area: entry.area, screens: screens,
            windowFrame: windowFrame)
    }

    /// screen UUID → エリア frame の解決。未指定・未接続時はウィンドウが現在いる
    /// ディスプレイ、それも判定できなければメインディスプレイへフォールバック
    public static func resolveFrame(
        screenUUID: String?, area: String, screens: [ScreenInput],
        windowFrame: CGRect? = nil
    ) -> CGRect? {
        var screen: ScreenInput?
        if let uuid = screenUUID {
            screen = screens.first { $0.uuid?.caseInsensitiveCompare(uuid) == .orderedSame }
        }
        if screen == nil, let windowFrame {
            screen = Self.screen(containing: windowFrame, in: screens)
        }
        if screen == nil {
            screen = screens.first(where: \.isMain) ?? screens.first
        }
        guard let screen else { return nil }
        return AreaSpec.frame(for: area, screenFrame: screen.visibleFrame)
    }

    /// ウィンドウ frame との交差面積が最大の画面(交差しなければ nil)
    static func screen(containing frame: CGRect, in screens: [ScreenInput]) -> ScreenInput? {
        var best: (screen: ScreenInput, area: CGFloat)?
        for screen in screens {
            let intersection = screen.visibleFrame.intersection(frame)
            guard !intersection.isNull else { continue }
            let area = intersection.width * intersection.height
            guard area > 0 else { continue }
            if best == nil || area > best!.area {
                best = (screen, area)
            }
        }
        return best?.screen
    }
}
