import CoreGraphics
import ScreenCaptureKit

/// ウィンドウ内容のキャプチャ(隠れウィンドウのプレビュー用。要・画面収録権限)
public enum WindowCapture {
    public static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 画面収録権限を要求(初回はシステムダイアログが出る)
    @discardableResult
    public static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// 複数ウィンドウのスクリーンショットをまとめて取得(別 Space のウィンドウも可)。
    /// ScreenCaptureKit は非同期 API のため、呼び元はヒントを先に組み立ててから
    /// 撮影完了後にプレビューを差し込む
    @MainActor
    public static func captureImages(
        windowIDs: [CGWindowID]
    ) async -> [CGWindowID: CGImage] {
        guard !windowIDs.isEmpty,
            let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)
        else { return [:] }
        var results: [CGWindowID: CGImage] = [:]
        for windowID in windowIDs {
            guard let window = content.windows.first(where: { $0.windowID == windowID })
            else { continue }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            // 元 CGWindowListCreateImage の .nominalResolution 相当(ポイント解像度)
            configuration.width = Int(window.frame.width)
            configuration.height = Int(window.frame.height)
            configuration.captureResolution = .nominal
            configuration.showsCursor = false
            if let image = try? await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: configuration)
            {
                results[windowID] = image
            }
        }
        return results
    }
}
