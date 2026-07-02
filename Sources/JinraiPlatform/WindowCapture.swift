import CoreGraphics

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

    /// ウィンドウのスクリーンショット。別 Space のウィンドウも取得できる。
    /// CGWindowListCreateImage は macOS 14 で非推奨だが動作する
    /// (ScreenCaptureKit 移行はフェーズ2で検討)
    public static func captureImage(windowID: CGWindowID) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        )
    }
}
