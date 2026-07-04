import AppKit
import CGSPrivate
import JinraiCore

/// Space(仮想デスクトップ)情報(元 hs.spaces 相当)。
/// 列挙は非公開 CGS API、切替はキーストローク送出(Mission Control ショートカット)を使う。
@MainActor
public enum Spaces {
    public struct DisplaySpaces {
        public var displayUUID: String
        /// ユーザー Space の ID(Mission Control の並び順)
        public var spaceIDs: [UInt64]
        public var currentSpaceID: UInt64?
    }

    /// ディスプレイごとの Space 一覧(CGSCopyManagedDisplaySpaces)
    public static func managedDisplaySpaces() -> [DisplaySpaces] {
        guard
            let raw = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue()
                as? [[String: Any]]
        else { return [] }
        return raw.map { display in
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            // type 0 = ユーザー Space(フルスクリーン Space 等を除く)
            let userSpaceIDs = spaces.compactMap { space -> UInt64? in
                guard (space["type"] as? Int ?? 0) == 0 else { return nil }
                return (space["id64"] as? NSNumber)?.uint64Value
                    ?? (space["ManagedSpaceID"] as? NSNumber)?.uint64Value
            }
            let current =
                ((display["Current Space"] as? [String: Any])?["id64"] as? NSNumber)?
                .uint64Value
            return DisplaySpaces(
                displayUUID: display["Display Identifier"] as? String ?? "",
                spaceIDs: userSpaceIDs,
                currentSpaceID: current
            )
        }
    }

    /// Space ID → Mission Control 上の番号(全ディスプレイ通し、1始まり)
    public static func spaceNumbersByID() -> [UInt64: Int] {
        var numbers: [UInt64: Int] = [:]
        var counter = 0
        for display in managedDisplaySpaces() {
            for spaceID in display.spaceIDs {
                counter += 1
                numbers[spaceID] = counter
            }
        }
        return numbers
    }

    /// 現在アクティブな Space の ID 一覧(ディスプレイごとに1つ)
    public static func activeSpaceIDs() -> Set<UInt64> {
        Set(managedDisplaySpaces().compactMap(\.currentSpaceID))
    }

    /// ウィンドウが属する Space の ID(最初の1つ)
    public static func spaceID(of windowID: CGWindowID) -> UInt64? {
        let windowIDs = [NSNumber(value: windowID)] as CFArray
        guard
            let spaces = CGSCopySpacesForWindows(
                CGSMainConnectionID(), kCGSAllSpacesMask, windowIDs)?.takeRetainedValue()
                as? [NSNumber]
        else { return nil }
        return spaces.first?.uint64Value
    }

    /// 指定番号の Space へ切替。その Space のウィンドウをフォーカスして macOS に
    /// 切り替えさせる(Mission Control のショートカット設定に依存しない)。
    /// 観測済みの AX 要素があればそれを focus し(最も確実)、なければ window server
    /// 経由で試みる。ウィンドウが 1 つもない Space へは ctrl+<番号> のキーストロークで
    /// 切替する(こちらのみショートカットが有効な場合に限り動作)
    public static func gotoSpace(number: Int) {
        guard (1...9).contains(number) else { return }
        if let target = spaceNumbersByID().first(where: { $0.value == number })?.key,
            focusWindow(inSpace: target)
        {
            return
        }
        EventTap.postKeyStroke(modifiers: ["ctrl"], key: String(number))
    }

    /// 前後の Space へ切替。数字キー移動と同じくウィンドウフォーカス駆動で
    /// 切り替える(アニメーションが短く、フォーカス確定も速い)。
    /// 隣接 Space が空・解決失敗・端の場合は fn+ctrl+←/→ にフォールバック
    /// (macOS デフォルト有効のショートカット。端では OS 標準のラバーバンド演出になる)
    public static func gotoPrevSpace() {
        if let target = adjacentSpaceID(offset: -1), focusWindow(inSpace: target) { return }
        EventTap.postKeyStroke(modifiers: ["fn", "ctrl"], key: "left")
    }

    public static func gotoNextSpace() {
        if let target = adjacentSpaceID(offset: 1), focusWindow(inSpace: target) { return }
        EventTap.postKeyStroke(modifiers: ["fn", "ctrl"], key: "right")
    }

    /// 対象 Space のウィンドウをフォーカスして macOS に切り替えさせる。
    /// 観測済みの AX 要素があればそれを focus し(最も確実)、なければ window server
    /// 経由で試みる。ウィンドウが 1 つもなければ false(呼び元でフォールバック)
    private static func focusWindow(inSpace target: UInt64) -> Bool {
        // 前面→背面順なので、最初に見つかったものが対象 Space の最前面ウィンドウ
        var fallback: WindowInfo?
        for win in WindowEnumerator.allSpacesWindows() {
            guard spaceID(of: win.id) == target else { continue }
            if let cached = WindowRegistry.shared.window(for: win.id) {
                cached.focus()
                return true
            }
            if fallback == nil { fallback = win }
        }
        if let fallback {
            WindowServerFocus.focus(windowID: fallback.id, pid: fallback.pid)
            return true
        }
        return false
    }

    /// 現在フォーカスのあるスクリーンの Space 一覧上で、現在 Space から offset 隣の
    /// SpaceID。端で隣がない場合は nil(macOS 標準と同じくラップしない)
    private static func adjacentSpaceID(offset: Int) -> UInt64? {
        let displays = managedDisplaySpaces()
        guard !displays.isEmpty else { return nil }
        // キーウィンドウのあるスクリーンのディスプレイを探す(見つからなければ先頭)
        let mainUUID = NSScreen.main.flatMap { ScreenUtil.uuid(of: $0) }
        let display = displays.first { $0.displayUUID == mainUUID } ?? displays[0]
        guard
            let current = display.currentSpaceID,
            let index = display.spaceIDs.firstIndex(of: current)
        else { return nil }
        let targetIndex = index + offset
        guard display.spaceIDs.indices.contains(targetIndex) else { return nil }
        return display.spaceIDs[targetIndex]
    }
}
