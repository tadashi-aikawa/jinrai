import AppKit
import JinraiCore

/// Window Hints / Area Hints で使うアクティブウィンドウ強調レイヤー。
enum ActiveWindowOverlayLayers {
    static func highlightLayer(
        windowFrame: CGRect,
        screenFrame: CGRect,
        overlayHeight: CGFloat,
        borderColor: ConfigColor,
        borderWidth: CGFloat,
        cornerRadius: CGFloat
    ) -> CAShapeLayer {
        let local = localWindowFrame(
            windowFrame: windowFrame, screenFrame: screenFrame, overlayHeight: overlayHeight)
        let shape = CAShapeLayer()
        shape.path = CGPath(
            roundedRect: local.insetBy(dx: borderWidth / 2, dy: borderWidth / 2),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil)
        shape.fillColor = nil
        shape.lineWidth = borderWidth
        shape.strokeColor = cgColor(borderColor)
        return shape
    }

    static func spotlightLayer(
        windowFrame: CGRect,
        screenFrame: CGRect,
        overlayHeight: CGFloat,
        alpha: CGFloat
    ) -> CAShapeLayer {
        let local = localWindowFrame(
            windowFrame: windowFrame, screenFrame: screenFrame, overlayHeight: overlayHeight)
        let path = CGMutablePath()
        path.addRect(CGRect(origin: .zero, size: screenFrame.size))
        path.addRect(local)

        let shape = CAShapeLayer()
        shape.frame = CGRect(origin: .zero, size: screenFrame.size)
        shape.bounds = CGRect(origin: .zero, size: screenFrame.size)
        shape.path = path
        shape.fillRule = .evenOdd
        shape.fillColor = CGColor(gray: 0, alpha: alpha)
        // 瞬時に暗転すると目に刺さるため、フェードインで暗くする
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.15
        shape.add(fade, forKey: "fadeIn")
        return shape
    }

    private static func localWindowFrame(
        windowFrame: CGRect, screenFrame: CGRect, overlayHeight: CGFloat
    ) -> CGRect {
        let localTopY = windowFrame.minY - screenFrame.minY
        return CGRect(
            x: windowFrame.minX - screenFrame.minX,
            y: overlayHeight - localTopY - windowFrame.height,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    private static func cgColor(_ color: ConfigColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
