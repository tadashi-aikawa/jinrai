import AppKit
import JinraiCore
import JinraiPlatform

/// フォーカスしたウィンドウを二重枠線で強調しフェードアウトする(元 focus_border.lua)
@MainActor
final class FocusBorderFeature {
    private let config: FocusBorderConfig
    private let observer = FocusObserver()
    private var overlay: OverlayWindow?
    private var lastWindowID: CGWindowID?
    /// 表示中に次のフォーカス変化が来たとき、古いフェード完了処理を無効化する
    private var showGeneration = 0

    init(config: FocusBorderConfig) {
        self.config = config
        observer.onFocusChanged = { [weak self] window in
            self?.handleFocusChange(window)
        }
        observer.start()
    }

    private func handleFocusChange(_ window: AXWindow?) {
        guard let window, window.windowID != lastWindowID else { return }
        lastWindowID = window.windowID
        guard let frame = window.frame else { return }
        // 小さなウィンドウ(ポップアップ等)には表示しない
        guard frame.width >= config.minWindowSize || frame.height >= config.minWindowSize else {
            return
        }
        // 別 Space のウィンドウへのフォーカス(Space 切替を伴う)は、切替完了を
        // 待ってから点灯する。オーバーレイは全 Space 表示のため、即時に出すと
        // 移動前の Space の画面上で光って見えてしまう
        if let spaceID = Spaces.spaceID(of: window.windowID),
            !Spaces.activeSpaceIDs().contains(spaceID)
        {
            let windowID = window.windowID
            Task { @MainActor [weak self] in
                // Space 切替の完了を待つ(最大 1 秒。完了後に少し置いて点灯)
                for _ in 0..<20 {
                    try? await Task.sleep(for: .seconds(0.05))
                    guard let self, self.lastWindowID == windowID else { return }
                    guard
                        let sid = Spaces.spaceID(of: windowID),
                        Spaces.activeSpaceIDs().contains(sid)
                    else { continue }
                    try? await Task.sleep(for: .seconds(0.1))
                    guard self.lastWindowID == windowID else { return }
                    self.show(around: window.frame ?? frame)
                    return
                }
            }
            return
        }
        show(around: frame)
    }

    /// frame(top-left 座標)の内側に外枠+メイン枠を描画してフェードアウト
    func show(around frame: CGRect) {
        let overlay = self.overlay ?? OverlayWindow(frame: frame, level: .border)
        self.overlay = overlay
        overlay.setTopLeftFrame(frame)

        guard let layer = overlay.rootLayer else { return }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let bounds = CGRect(origin: .zero, size: frame.size)
        let outlineWidth = CGFloat(config.outlineWidth)
        let borderWidth = CGFloat(config.borderWidth)
        let cornerRadius: CGFloat = 12

        // 外枠(細い黒)を最外周、メイン枠(太い青)をその内側に
        let outlineLayer = strokeLayer(
            rect: bounds.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2),
            width: outlineWidth,
            cornerRadius: cornerRadius,
            color: config.outlineColor
        )
        let borderLayer = strokeLayer(
            rect: bounds.insetBy(
                dx: outlineWidth + borderWidth / 2, dy: outlineWidth + borderWidth / 2),
            width: borderWidth,
            cornerRadius: cornerRadius,
            color: config.borderColor
        )
        layer.addSublayer(outlineLayer)
        layer.addSublayer(borderLayer)

        overlay.alphaValue = 1
        overlay.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = config.duration
            overlay.animator().alphaValue = 0
        }
        showGeneration += 1
        let generation = showGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.config.duration ?? 0))
            guard let self, self.showGeneration == generation else { return }
            self.overlay?.orderOut(nil)
        }
    }

    private func strokeLayer(
        rect: CGRect, width: CGFloat, cornerRadius: CGFloat, color: ConfigColor
    ) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil)
        shape.fillColor = nil
        shape.lineWidth = width
        shape.strokeColor = CGColor(
            red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        return shape
    }

    func teardown() {
        observer.stop()
        overlay?.orderOut(nil)
        overlay = nil
    }
}
