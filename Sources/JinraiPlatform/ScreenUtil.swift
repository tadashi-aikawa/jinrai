import AppKit

/// 座標系変換。
/// 内部表現は CG/AX 準拠の top-left 原点(Y下向き)に統一し、
/// NSWindow / NSScreen(bottom-left 原点・Y上向き)との境界でのみ変換する。
@MainActor
public enum ScreenUtil {
    /// プライマリスクリーン(メニューバーのあるスクリーン)の高さ。変換の基準
    public static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// top-left 座標の矩形 → NSWindow 用の bottom-left 座標
    public static func toAppKit(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: primaryScreenHeight - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    /// NSScreen などの bottom-left 座標の矩形 → top-left 座標
    public static func fromAppKit(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: primaryScreenHeight - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    /// 指定 frame(top-left 座標)と最も重なる NSScreen
    public static func screenContaining(_ frame: CGRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let screenFrame = fromAppKit(screen.frame)
            let overlap = screenFrame.intersection(frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main
    }

    /// スクリーンの frame / 作業領域(Dock・メニューバー除く)を top-left 座標で
    public static func frame(of screen: NSScreen) -> CGRect {
        fromAppKit(screen.frame)
    }

    public static func visibleFrame(of screen: NSScreen) -> CGRect {
        fromAppKit(screen.visibleFrame)
    }

    /// ディスプレイの UUID(元 hs.screen:getUUID()。selectedArea.screens のキー)
    public static func uuid(of screen: NSScreen) -> String? {
        guard
            let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
            let uuidString = CFUUIDCreateString(nil, cfUUID)
        else { return nil }
        return uuidString as String
    }

    /// 接続中の全ディスプレイの UUID(profiles のマッチ判定に使う)
    public static func connectedDisplayUUIDs() -> [String] {
        NSScreen.screens.compactMap { uuid(of: $0) }
    }

    /// 次のディスプレイ(元 hs.screen:next())
    public static func nextScreen(after screen: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = screens.firstIndex(of: screen) else { return screens.first }
        return screens[(index + 1) % screens.count]
    }
}
