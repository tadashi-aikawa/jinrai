import AppKit
import JinraiPlatform

/// 短い文言を画面中央へ一瞬出す HUD。ミラーリング・拡張表示の切替結果や、
/// セキュア入力中でモーダル機能を開けなかったことを知らせる。
/// 切替でディスプレイの UUID 集合が変わると、表示中に設定が再読込され Feature は作り直される。
/// 表示とフェードが途切れないよう、AppDelegate が Feature とは別に持ち続ける
@MainActor
final class CenterHUD {
    /// 本体(塗りと青い枠)の大きさ。幅は文言に合わせて広がる。外枠の分だけウィンドウは大きくなる
    private static let bodyMinWidth: CGFloat = 240
    private static let bodyHeight: CGFloat = 64
    /// 文言の左右に空ける余白
    private static let bodyHorizontalPadding: CGFloat = 32
    private static let bodyCornerRadius: CGFloat = 14
    private static let font = NSFont.systemFont(ofSize: 22, weight: .bold)
    /// 暗い背景でも白い背景でも輪郭が出るよう、Focus Border のデフォルトと同じ
    /// 青い枠+黒い外枠の組み方にする
    private static let borderWidth: CGFloat = 3
    private static let borderColor = NSColor(
        calibratedRed: 0.40, green: 0.68, blue: 0.98, alpha: 0.95)
    private static let outlineWidth: CGFloat = 2
    private static let outlineColor = NSColor.black.withAlphaComponent(0.70)
    private static let holdSeconds = 0.8
    private static let fadeSeconds = 0.25

    private var window: OverlayWindow?
    private var label: NSTextField?
    private var outlineLayer: CALayer?
    private var bodyLayer: CALayer?
    private var generation = 0
    /// 表示中の HUD を置いているディスプレイ。構成変更のたびにこの画面の中央へ置き直す
    private var displayedDisplayID: CGDirectDisplayID?
    private var screenObserver: NSObjectProtocol?

    init() {
        // 即時表示のあとも外部ディスプレイの再同期で画面の原点・解像度が変わり得る。
        // 表示中だけ中央へ置き直す(表示時間は延ばさない)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recenter()
            }
        }
    }

    /// text を displayID のディスプレイ中央にすぐ出す。
    /// 外部ディスプレイの再同期(数秒)を待たない。映し元の内蔵・メイン画面は切替中も暗転しないため
    func show(_ text: String, on displayID: CGDirectDisplayID) {
        generation += 1
        let current = generation
        // 前回の表示が残っていれば消す(フェード待ちの Task は世代違いで何もしなくなるため)。
        // 進行中のフェードは duration 0 で animator に値を入れて止め、新しい表示の透明度へ干渉させない
        if let window {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                window.animator().alphaValue = 1
            }
            window.orderOut(nil)
        }
        present(text, on: displayID, generation: current)
    }

    func teardown() {
        generation += 1
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        displayedDisplayID = nil
        window?.orderOut(nil)
        window = nil
        label = nil
        outlineLayer = nil
        bodyLayer = nil
    }

    private func present(_ text: String, on displayID: CGDirectDisplayID, generation: Int) {
        guard let frame = Self.centeredFrame(on: displayID, size: Self.size(for: text)) else {
            return
        }
        let window = self.window ?? makeWindow(frame: frame)
        self.window = window
        displayedDisplayID = displayID
        window.setTopLeftFrame(frame)
        layoutLayers(in: CGRect(origin: .zero, size: frame.size))
        label?.stringValue = text
        window.alphaValue = 1
        window.orderFrontRegardless()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.holdSeconds))
            guard let self, self.generation == generation else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fadeSeconds
                window.animator().alphaValue = 0
            }
            guard self.generation == generation else { return }
            window.orderOut(nil)
            self.displayedDisplayID = nil
        }
    }

    private func recenter() {
        guard let window, window.isVisible, let displayID = displayedDisplayID,
            let frame = Self.centeredFrame(on: displayID, size: window.frame.size)
        else { return }
        window.setTopLeftFrame(frame)
    }

    /// 文言ごとに幅が変わるため、表示のたびに外枠と本体をウィンドウの大きさへ合わせ直す
    private func layoutLayers(in bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outlineLayer?.frame = bounds
        bodyLayer?.frame = bounds.insetBy(dx: Self.outlineWidth, dy: Self.outlineWidth)
        CATransaction.commit()
    }

    /// text を収めるウィンドウの大きさ(外枠を含む)
    private static func size(for text: String) -> CGSize {
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let bodyWidth = max(bodyMinWidth, textWidth + bodyHorizontalPadding * 2)
        return CGSize(width: bodyWidth + outlineWidth * 2, height: bodyHeight + outlineWidth * 2)
    }

    /// displayID のディスプレイ中央に置く HUD の frame(top-left 座標)。見つからなければ先頭の画面
    private static func centeredFrame(on displayID: CGDirectDisplayID, size: CGSize) -> CGRect? {
        guard let screen = screen(for: displayID) ?? NSScreen.screens.first else { return nil }
        let screenFrame = ScreenUtil.frame(of: screen)
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width, height: size.height)
    }

    private func makeWindow(frame: CGRect) -> OverlayWindow {
        let window = OverlayWindow(frame: frame, level: .hints)
        if let layer = window.rootLayer {
            // 外枠: 本体を囲む黒い輪(CALayer の border は内側に描かれる)
            let outline = CALayer()
            outline.cornerRadius = Self.bodyCornerRadius + Self.outlineWidth
            outline.borderWidth = Self.outlineWidth
            outline.borderColor = Self.outlineColor.cgColor
            layer.addSublayer(outline)
            outlineLayer = outline
            // 本体: 黒い塗りと青い枠
            let body = CALayer()
            body.cornerRadius = Self.bodyCornerRadius
            body.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
            body.borderWidth = Self.borderWidth
            body.borderColor = Self.borderColor.cgColor
            layer.addSublayer(body)
            bodyLayer = body
        }
        let label = NSTextField(labelWithString: "")
        label.font = Self.font
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = window.contentView {
            contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
        }
        self.label = label
        return window
    }

    private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID) == displayID
        }
    }
}
