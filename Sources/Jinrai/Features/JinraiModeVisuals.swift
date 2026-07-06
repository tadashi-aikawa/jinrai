import AppKit
import JinraiCore
import JinraiPlatform

/// JinraiMode の演出(ロゴ・コンボキャラクター・COMBO テキスト)。
/// 元 window_hints.lua の showJinraiModeLogo / showJinraiModeCombo 系。
/// ダブルバッファ(レイヤー2枚)のクロスフェードを Timer + easing で再現する。
@MainActor
final class JinraiModeVisuals {
    private let config: JinraiModeConfig
    private let configDirectoryURL: URL

    private var logoWindow: OverlayWindow?
    private var logoLayer: CALayer?
    private var comboWindow: OverlayWindow?
    private var characterLayers: [CALayer] = []
    private var currentCharacterIndex = 0
    private var textLayers: [(number: CATextLayer, label: CATextLayer, container: CALayer)] = []
    private var currentTextIndex = 0

    private let logoAnimator = AnimationRunner()
    private let characterAnimator = AnimationRunner()
    private let textAnimator = AnimationRunner()

    private var logoImage: NSImage?
    private var bundledComboImages: [Int: NSImage] = [:]
    private var userComboImages: [Int: NSImage] = [:]

    /// 表示先の基準ウィンドウ。frontmostApplication は更新が非同期で遅れるため、
    /// ヒント選択直後などは選択したウィンドウを明示して追従させる
    private var anchor: (windowID: UInt32, pid: pid_t)?

    /// 前回 COMBO を表示したスクリーン(ディスプレイ跨ぎ判定用)
    private var lastComboScreenFrame: CGRect?

    func setAnchor(windowID: UInt32, pid: pid_t) {
        anchor = (windowID, pid)
    }

    func clearAnchor() {
        anchor = nil
    }

    private static let comboTextColor = ConfigColor(red: 1, green: 0.46, blue: 0.08)

    init(config: JinraiModeConfig, configDirectoryURL: URL) {
        self.config = config
        self.configDirectoryURL = configDirectoryURL
    }

    // MARK: - 画像リソース

    private func loadLogoImage() -> NSImage? {
        if let logoImage { return logoImage }
        guard let url = Bundle.main.url(forResource: "jinrai", withExtension: "svg") else {
            NSLog("[jinrai.jinraiMode] jinrai.svg が見つかりません")
            return nil
        }
        logoImage = NSImage(contentsOf: url)
        return logoImage
    }

    private func loadComboImage(index: Int) -> NSImage? {
        if let image = bundledComboImages[index] { return image }
        guard
            let url = Bundle.main.url(forResource: "jinrai\(index)", withExtension: "webp")
        else {
            NSLog("[jinrai.jinraiMode] jinrai%d.webp が見つかりません", index)
            return nil
        }
        let image = NSImage(contentsOf: url)
        bundledComboImages[index] = image
        return image
    }

    private func loadUserComboImage(count: Int) -> NSImage? {
        guard let images = config.comboCharacter.images,
              let imageIndex = JinraiModeLogic.comboUserImageIndex(
                count: count, imageCount: images.count)
        else { return nil }
        if let image = userComboImages[imageIndex] { return image }

        let path = images[imageIndex]
        let url = resolveImageURL(path)
        guard let image = NSImage(contentsOf: url) else {
            NSLog(
                "[jinrai.jinraiMode] combo.character.images[%d] を読み込めません: %@",
                imageIndex, url.path)
            return nil
        }
        userComboImages[imageIndex] = image
        return image
    }

    private func resolveImageURL(_ path: String) -> URL {
        let expanded: String
        if path == "~" {
            expanded = FileManager.default.homeDirectoryForCurrentUser.path
        } else if path.hasPrefix("~/") {
            expanded =
                FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(path.dropFirst(2))).path
        } else {
            expanded = path
        }
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return configDirectoryURL.appendingPathComponent(expanded)
    }

    // MARK: - 表示コンテキスト

    private struct DisplayContext {
        var screenFrame: CGRect  // top-left 座標
        var center: CGPoint
        var screen: NSScreen
    }

    private func displayContext() -> DisplayContext? {
        // アンカーがあれば AX で最新 frame を解決(移動・別ディスプレイへの追従)
        let anchorFrame = anchor.flatMap {
            AXWindow.resolve(windowID: $0.windowID, pid: $0.pid)?.frame
        }
        let focusedFrame = anchorFrame ?? WindowEnumerator.focusedWindow()?.frame
        let screen =
            focusedFrame.flatMap { ScreenUtil.screenContaining($0) } ?? NSScreen.main
        guard let screen else { return nil }
        let screenFrame = ScreenUtil.frame(of: screen)
        let center = JinraiModeLogic.displayCenter(
            position: config.position, windowFrame: focusedFrame, screenFrame: screenFrame)
        return DisplayContext(screenFrame: screenFrame, center: center, screen: screen)
    }

    /// top-left グローバル座標 → overlay ローカル(AppKit)座標
    private func toLocal(_ rect: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: screenFrame.height - (rect.minY - screenFrame.minY) - rect.height,
            width: rect.width, height: rect.height)
    }

    // MARK: - ロゴ

    func showLogo() {
        guard config.logo.enabled else { return }
        guard let image = loadLogoImage(), let context = displayContext() else { return }

        let window = ensureWindow(&logoWindow, screenFrame: context.screenFrame, level: .logo)
        guard let root = window.rootLayer else { return }

        if logoLayer == nil {
            let layer = CALayer()
            layer.contentsGravity = .resizeAspect
            var rect = CGRect(origin: .zero, size: image.size)
            layer.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            root.addSublayer(layer)
            logoLayer = layer
        }
        guard let layer = logoLayer else { return }

        let size = CGFloat(config.logo.size)
        let animation = config.logo.animation
        let center = context.center
        let screenFrame = context.screenFrame

        logoAnimator.run(animation: animation) {
            [weak self] progress in
            guard let self else { return }
            let scale = animation.scale + (1 - animation.scale) * progress
            let scaled = size * scale
            let global = CGRect(
                x: center.x - scaled / 2, y: center.y - scaled / 2,
                width: scaled, height: scaled)
            layer.frame = self.toLocal(global, in: screenFrame)
            layer.opacity = Float(
                (animation.fade ? progress : 1) * self.config.logo.alpha)
        }
        window.orderFrontRegardless()
    }

    // MARK: - コンボ(キャラクター+テキスト)

    func showCombo(count: Int) {
        let characterEnabled = config.comboCharacter.enabled
        let textEnabled = count > 0 && config.comboText.enabled
        guard characterEnabled || textEnabled else {
            clearCombo()
            return
        }
        guard let context = displayContext() else { return }

        let window = ensureWindow(
            &comboWindow, screenFrame: context.screenFrame, level: .combo)
        guard let root = window.rootLayer else { return }

        // ディスプレイを跨いだら旧内容のダブルバッファを破棄
        // (クロスフェードの「前の画像」が新ディスプレイ上に一瞬映るのを防ぐ)
        if lastComboScreenFrame != context.screenFrame {
            for layer in characterLayers { layer.removeFromSuperlayer() }
            characterLayers = []
            for entry in textLayers { entry.container.removeFromSuperlayer() }
            textLayers = []
            currentCharacterIndex = 0
            currentTextIndex = 0
        }
        lastComboScreenFrame = context.screenFrame

        if characterEnabled {
            showCharacter(count: count, context: context, root: root)
        }
        if textEnabled {
            showText(count: count, context: context, root: root)
        } else {
            for (number, label, container) in textLayers {
                number.opacity = 0
                label.opacity = 0
                container.opacity = 0
            }
        }
        window.orderFrontRegardless()
    }

    private func showCharacter(count: Int, context: DisplayContext, root: CALayer) {
        // ダブルバッファ: 2枚のレイヤーを交互に使いクロスフェード
        while characterLayers.count < 2 {
            let layer = CALayer()
            layer.contentsGravity = .resizeAspect
            layer.opacity = 0
            root.addSublayer(layer)
            characterLayers.append(layer)
        }
        let fallbackImageIndex = JinraiModeLogic.comboImageIndex(count: count)
        guard let image = loadUserComboImage(count: count) ?? loadComboImage(index: fallbackImageIndex)
        else { return }

        currentCharacterIndex = (currentCharacterIndex + 1) % 2
        let layer = characterLayers[currentCharacterIndex]
        let previous = characterLayers[(currentCharacterIndex + 1) % 2]

        var rect = CGRect(origin: .zero, size: image.size)
        layer.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)

        let animation = config.comboCharacter.animation
        let alpha = config.comboCharacter.alpha
        let baseSize = JinraiModeLogic.comboBaseSize(screenFrame: context.screenFrame)
        let center = context.center
        let screenFrame = context.screenFrame

        characterAnimator.run(animation: animation) {
            [weak self] progress in
            guard let self else { return }
            let scale = animation.scale + (1 - animation.scale) * progress
            let size = baseSize * scale
            let global = CGRect(
                x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            layer.frame = self.toLocal(global, in: screenFrame)
            layer.opacity = Float((animation.fade ? progress : 1) * alpha)
            previous.opacity = Float((1 - progress) * alpha)
        }
    }

    private func showText(count: Int, context: DisplayContext, root: CALayer) {
        while textLayers.count < 2 {
            let container = CALayer()
            let number = CATextLayer()
            let label = CATextLayer()
            for textLayer in [number, label] {
                textLayer.contentsScale = context.screen.backingScaleFactor
                textLayer.alignmentMode = .center
                textLayer.isWrapped = false
                container.addSublayer(textLayer)
            }
            root.addSublayer(container)
            textLayers.append((number: number, label: label, container: container))
        }

        currentTextIndex = (currentTextIndex + 1) % 2
        let current = textLayers[currentTextIndex]
        let previous = textLayers[(currentTextIndex + 1) % 2]

        let animation = config.comboText.animation
        let alpha = config.comboText.alpha
        let screenFrame = context.screenFrame
        let center = context.center
        let baseSize = JinraiModeLogic.comboBaseSize(screenFrame: context.screenFrame)
        let logoSize = CGFloat(config.logo.size)
        let countText = String(count)

        textAnimator.run(animation: animation) {
            [weak self] progress in
            guard let self else { return }
            let scale = animation.scale + (1 - animation.scale) * progress
            let sizes = JinraiModeLogic.comboTextSizes(baseSize: baseSize)
            let numberFont = sizes.number * scale
            let labelFont = sizes.label * scale

            let numberString = self.comboAttributedText(
                countText, fontSize: numberFont, alpha: alpha, strokeWidth: -5)
            let labelString = self.comboAttributedText(
                "COMBO!", fontSize: labelFont, alpha: alpha, strokeWidth: -4)
            current.number.string = numberString
            current.label.string = labelString

            let numberSize = numberString.size()
            let labelSize = labelString.size()
            let gap = labelFont * 0.22
            let totalWidth = numberSize.width + gap + labelSize.width
            let textHeight = max(numberSize.height, labelSize.height)
            let top = JinraiModeLogic.comboTextTop(
                screenFrame: screenFrame, center: center,
                logoSize: logoSize, textHeight: textHeight)

            let left = center.x - totalWidth / 2
            // ベースライン揃えで数字と COMBO! を横並び。box 下端揃えだと
            // フォントサイズ差の分 descender の高さが違い、大きい数字側が浮いて見える
            let numberDescent = -Self.comboFont(size: numberFont).descender
            let labelDescent = -Self.comboFont(size: labelFont).descender
            let baselineY = top + textHeight - numberDescent
            let numberGlobal = CGRect(
                x: left, y: baselineY + numberDescent - numberSize.height,
                width: numberSize.width, height: numberSize.height)
            let labelGlobal = CGRect(
                x: left + numberSize.width + gap,
                y: baselineY + labelDescent - labelSize.height,
                width: labelSize.width, height: labelSize.height)

            current.number.fontSize = numberFont
            current.label.fontSize = labelFont
            current.number.frame = self.toLocal(numberGlobal, in: screenFrame)
            current.label.frame = self.toLocal(labelGlobal, in: screenFrame)

            let opacity = Float(animation.fade ? progress : 1)
            current.number.opacity = opacity
            current.label.opacity = opacity
            current.container.opacity = 1
            previous.number.opacity = Float(1 - progress)
            previous.label.opacity = Float(1 - progress)
        }
    }

    private static func comboFont(size: CGFloat) -> NSFont {
        NSFont(name: "AvenirNext-Heavy", size: size)
            ?? NSFont.boldSystemFont(ofSize: size)
    }

    private func comboAttributedText(
        _ text: String, fontSize: CGFloat, alpha: Double, strokeWidth: Double
    ) -> NSAttributedString {
        let color = Self.comboTextColor
        let font = Self.comboFont(size: fontSize)
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor(
                    red: color.red, green: color.green, blue: color.blue, alpha: alpha),
                .strokeColor: NSColor(red: 0, green: 0, blue: 0, alpha: alpha),
                // 負値 = 塗り+縁取り(元 hs.styledtext の strokeWidth -5/-4)
                .strokeWidth: strokeWidth,
            ])
    }

    // MARK: - 共通

    private func ensureWindow(
        _ window: inout OverlayWindow?, screenFrame: CGRect, level: OverlayLevel
    ) -> OverlayWindow {
        if let window {
            window.setTopLeftFrame(screenFrame)
            return window
        }
        let created = OverlayWindow(frame: screenFrame, level: level)
        window = created
        return created
    }

    private func clearCombo() {
        characterAnimator.cancel()
        textAnimator.cancel()
        comboWindow?.orderOut(nil)
        comboWindow = nil
        characterLayers = []
        textLayers = []
        lastComboScreenFrame = nil
    }

    func clear() {
        logoAnimator.cancel()
        logoWindow?.orderOut(nil)
        logoWindow = nil
        logoLayer = nil
        clearCombo()
    }
}

/// 0.02s 間隔の Timer で progress(easing 適用済み)を配る(元 animateJinraiModeCanvas)。
/// @MainActor クラスは Sendable なので Timer の @Sendable クロージャから安全に参照できる
@MainActor
private final class AnimationRunner {
    private var timer: Timer?
    private var currentStep = 0
    private var totalSteps = 0
    private var easing: JinraiModeConfig.Easing = .linear
    private var apply: ((Double) -> Void)?

    func run(animation: JinraiModeConfig.Animation, apply: @escaping (Double) -> Void) {
        cancel()
        let steps = JinraiModeLogic.animationSteps(duration: animation.duration)
        let shouldAnimate = steps > 0 && (animation.fade || animation.scale != 1)
        applyWithoutImplicitAnimation(shouldAnimate ? 0 : 1, apply: apply)
        guard shouldAnimate else { return }

        currentStep = 0
        totalSteps = steps
        easing = animation.easing
        self.apply = apply
        timer = Timer.scheduledTimer(
            withTimeInterval: JinraiModeLogic.animationInterval, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let apply, totalSteps > 0 else {
            cancel()
            return
        }
        currentStep += 1
        let progress = JinraiModeLogic.animationProgress(
            Double(currentStep) / Double(totalSteps), easing: easing)
        applyWithoutImplicitAnimation(progress, apply: apply)
        if currentStep >= totalSteps {
            cancel()
        }
    }

    private func applyWithoutImplicitAnimation(
        _ progress: Double, apply: (Double) -> Void
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        apply(progress)
        CATransaction.commit()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        apply = nil
    }
}
