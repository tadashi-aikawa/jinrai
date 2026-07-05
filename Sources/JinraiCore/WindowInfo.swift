import CoreGraphics
import Foundation

/// JinraiCore が扱うウィンドウの値型表現。
/// JinraiPlatform が CGWindowList / AX から生成して渡す(Z順: 前面が先頭)。
/// 座標系は CG/AX 準拠(プライマリスクリーン左上原点・Y下向き)で統一する。
public struct WindowInfo: Equatable, Sendable {
    public var id: UInt32
    public var pid: pid_t
    public var bundleID: String?
    public var appName: String
    public var title: String
    public var frame: CGRect
    public var spaceNumber: Int?
    /// フルスクリーン Space(番号を持たない専用 Space)に属するか
    public var isFullscreenSpace: Bool
    public var isFocused: Bool

    public init(
        id: UInt32,
        pid: pid_t = 0,
        bundleID: String? = nil,
        appName: String = "",
        title: String = "",
        frame: CGRect = .zero,
        spaceNumber: Int? = nil,
        isFullscreenSpace: Bool = false,
        isFocused: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.frame = frame
        self.spaceNumber = spaceNumber
        self.isFullscreenSpace = isFullscreenSpace
        self.isFocused = isFocused
    }
}
