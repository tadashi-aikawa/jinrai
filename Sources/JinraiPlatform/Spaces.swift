import AppKit
import CGSPrivate

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

    /// 指定番号の Space へ切替(ctrl+<番号> のキーストローク。
    /// システム設定で Mission Control のショートカットが有効な必要がある)
    public static func gotoSpace(number: Int) {
        guard (1...9).contains(number) else { return }
        EventTap.postKeyStroke(modifiers: ["ctrl"], key: String(number))
    }

    /// 前後の Space へ切替(ctrl+←/→)
    public static func gotoPrevSpace() {
        EventTap.postKeyStroke(modifiers: ["fn", "ctrl"], key: "left")
    }

    public static func gotoNextSpace() {
        EventTap.postKeyStroke(modifiers: ["fn", "ctrl"], key: "right")
    }
}
