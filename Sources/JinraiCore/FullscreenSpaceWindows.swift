import CoreGraphics

/// フルスクリーン Space 上のウィンドウから「本体ウィンドウ」とみなせるものを選ぶ。
/// フルスクリーン Space には本体のほかに補助ウィンドウ(Chrome のステータスバブルや
/// タブプレビュー等。layer 0 だが AX の標準ウィンドウ判定では弾かれるもの)が載るため、
/// 面積で足切りする
public enum FullscreenSpaceWindows {
    /// Space 内の最大面積に対してこの割合未満のウィンドウは補助ウィンドウとみなす。
    /// Split View(2アプリで画面を分け合う)の両ウィンドウは通る値にしている
    static let minAreaRatio: CGFloat = 0.25

    public static func mainWindowIDs(
        windows: [(id: UInt32, spaceID: UInt64, frame: CGRect)]
    ) -> Set<UInt32> {
        var result: Set<UInt32> = []
        for wins in Dictionary(grouping: windows, by: \.spaceID).values {
            let maxArea = wins.map { $0.frame.width * $0.frame.height }.max() ?? 0
            guard maxArea > 0 else { continue }
            for win in wins
            where win.frame.width * win.frame.height >= maxArea * minAreaRatio {
                result.insert(win.id)
            }
        }
        return result
    }
}
