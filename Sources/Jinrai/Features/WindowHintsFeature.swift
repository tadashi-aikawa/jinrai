import AppKit
import Carbon.HIToolbox
import JinraiCore
import JinraiPlatform

/// ウィンドウヒント(元 window_hints.lua の中核)。
/// ホットキーで全ウィンドウにアイコン+キーを重ね、逐次キー入力でフォーカス切替。
@MainActor
final class WindowHintsFeature {
    private let config: WindowHintsConfig
    private let focusHistory: FocusHistoryFeature?
    private var hotkey: Hotkey?
    private let eventTap = EventTap()

    private var overlays: [OverlayWindow] = []
    /// spotlight(暗幕) + アクティブボーダー用のスクリーンごとのオーバーレイ。
    /// ウィンドウ切替時に余韻(穴の移動 + フェードアウト)を残すため、
    /// ヒント本体とは別に管理する
    private struct SpotlightOverlay {
        let overlay: OverlayWindow
        let spotlight: CAShapeLayer
        let highlight: CAShapeLayer?
        let screenFrame: CGRect
    }
    private var spotlightOverlays: [SpotlightOverlay] = []
    private var hints: [HintKeyAssignment.Hint] = []
    private var hintContainers: [String: CALayer] = [:]
    private var hintKeyLayers: [String: CATextLayer] = [:]
    private var hintOverlayFills: [String: CALayer] = [:]
    private var hintOverlayBorders: [String: CAShapeLayer] = [:]
    private var hintFrames: [String: CGRect] = [:]  // top-left 座標(外クリック判定用)
    /// プレビュー画像の差し込み先(windowID → 層)。撮影は非同期のため後から埋める
    private var previewLayersByWindowID: [UInt32: CALayer] = [:]
    private var currentInput = ""
    private var occludedWindowIDs: Set<UInt32> = []
    private var offSpaceWindowIDs: Set<UInt32> = []
    private var windowZOrder: [UInt32: Int] = [:]  // 前面=小(ヒント配置の優先度)
    private var coveringFramesByID: [UInt32: [CGRect]] = [:]  // 自分より前面のフレーム群
    private let macosNativeTabsApps: Set<String>
    private var didRequestScreenCapture = false
    private(set) var isVisible = false

    /// Window Mover のエリア選択画面へ遷移するコールバック(jinraiMode フラグ付き)
    var onOpenWindowMover: ((Bool) -> Void)?
    /// Application Hints へ遷移するコールバック(jinraiMode フラグ付き)
    var onOpenApplicationHints: ((Bool) -> Void)?
    /// JinraiMode 中のウィンドウ選択後(→ 選択ウィンドウを対象にエリア選択画面を開く)
    var onJinraiModeSelect: ((_ windowID: UInt32, _ pid: pid_t) -> Void)?

    // MARK: - JinraiMode 状態(元 window_hints.lua の isJinraiMode / comboCount)

    private let jinraiVisuals: JinraiModeVisuals
    private(set) var isJinraiMode = false
    private var comboCount = 0

    func startJinraiMode() {
        comboCount = 0
        isJinraiMode = true
        jinraiVisuals.clearAnchor()
        jinraiVisuals.showLogo()
        jinraiVisuals.showCombo(count: 0)
    }

    func stopJinraiMode() {
        isJinraiMode = false
        comboCount = 0
        jinraiVisuals.clearAnchor()
        jinraiVisuals.clear()
    }

    /// mode を維持したまま Hints を再表示(元 showJinraiMode)
    func showJinraiMode(fadeIn: Bool = true) {
        show(fadeIn: fadeIn)
    }

    @discardableResult
    func advanceJinraiModeCombo() -> Bool {
        guard isJinraiMode else { return false }
        comboCount += 1
        jinraiVisuals.showLogo()
        jinraiVisuals.showCombo(count: comboCount)
        return true
    }

    init(
        config: WindowHintsConfig,
        focusHistory: FocusHistoryFeature?,
        macosNativeTabs: MacosNativeTabsConfig = .default,
        jinraiMode: JinraiModeConfig = .default
    ) {
        self.config = config
        self.focusHistory = focusHistory
        self.macosNativeTabsApps = Set(macosNativeTabs.apps)
        self.jinraiVisuals = JinraiModeVisuals(config: jinraiMode)

        if let key = config.hotkeyKey {
            hotkey = Hotkey(modifiers: config.hotkeyModifiers, key: key) { [weak self] in
                self?.toggle()
            }
            if hotkey == nil {
                NSLog("[jinrai.window_hints] ホットキーの登録に失敗: %@", key)
            }
        }

        eventTap.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        eventTap.onLeftMouseDown = { [weak self] location in
            self?.handleMouseDown(location) ?? false
        }
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }

    // MARK: - 表示

    /// fadeIn: 直前まで spotlight が出ていた遷移(Area Hints からの受け渡し等)
    /// では false にして瞬間表示し、暗幕の連続性を保つ
    func show(fadeIn: Bool = true) {
        guard !isVisible else { return }

        let entries = collectEntries()
        guard !entries.isEmpty else { return }

        hints = HintKeyAssignment.assign(
            entries: entries,
            hintChars: config.hintChars,
            overrides: config.prefixOverrides,
            reservedChars: reservedChars()
        )
        guard !hints.isEmpty else { return }

        guard eventTap.start() else {
            NSLog("[jinrai.window_hints] キー捕捉を開始できません(権限またはセキュア入力)")
            return
        }

        // プレビューが有効なら画面収録権限を一度だけ要求(未許可時はプレビューなしで続行)
        if config.previewEnabled, hints.contains(where: isDockHint),
            !WindowCapture.hasPermission, !didRequestScreenCapture
        {
            didRequestScreenCapture = true
            WindowCapture.requestPermission()
        }

        currentInput = ""
        isVisible = true
        buildOverlays(fadeIn: fadeIn)

        if config.cursorOnStart,
            let active = hints.first(where: { $0.entry.window.isFocused })
        {
            Mouse.moveToCenter(of: active.entry.window.frame)
        }
    }

    func close(keepJinraiMode: Bool = false) {
        if !keepJinraiMode {
            stopJinraiMode()
        }
        guard isVisible else { return }
        isVisible = false
        eventTap.stop()
        // ウィンドウ切替を伴う操作では呼び元が dismissSpotlight(movingTo:) 済み
        // (その場合ここは no-op)。escape 等の単純クローズはその場でフェードアウト
        dismissSpotlight(movingTo: nil)
        for overlay in overlays {
            overlay.orderOut(nil)
        }
        overlays = []
        hintContainers = [:]
        hintKeyLayers = [:]
        hintOverlayFills = [:]
        hintOverlayBorders = [:]
        hintFrames = [:]
        previewLayersByWindowID = [:]
        hints = []
        currentInput = ""
    }

    /// 候補収集(現Space の可視標準ウィンドウ。完全に隠れたものは occluded 扱い)
    private func collectEntries() -> [HintKeyAssignment.Entry] {
        var ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        var standard = WindowEnumerator.standardWindows(from: ordered)
        // 最前面ウィンドウの frame を AX で最新化(Window Mover 適用直後は
        // CGWindowList の frame 反映が遅れ、アクティブ枠等が旧位置に描かれるため)
        if let front = standard.first,
            let freshFrame = AXWindow.resolve(windowID: front.id, pid: front.pid)?.frame,
            freshFrame != front.frame
        {
            for i in ordered.indices where ordered[i].id == front.id {
                ordered[i].frame = freshFrame
            }
            standard[0].frame = freshFrame
        }
        occludedWindowIDs = Set(
            standard.filter {
                DirectionScoring.isFullyOccludedWindow(
                    $0, orderedWindows: ordered, config: config.directionScoring)
            }.map(\.id))
        // フォーカス中ウィンドウ = 最前面の標準ウィンドウ(CGWindowList の Z順は
        // window server 由来で速く更新され、frontmostApplication の非同期遅延に強い)
        let focusedID = standard.first?.id
        windowZOrder = Dictionary(
            standard.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        // 各ウィンドウを覆う「自分より前面」のフレーム群(見えている領域の中央計算用)
        coveringFramesByID = [:]
        for win in standard {
            var frames: [CGRect] = []
            for other in ordered {
                if other.id == win.id { break }
                frames.append(other.frame)
            }
            coveringFramesByID[win.id] = frames
        }
        var entries = standard.map { win -> HintKeyAssignment.Entry in
            var win = win
            win.isFocused = (win.id == focusedID)
            return HintKeyAssignment.Entry(
                window: win,
                appKey: win.bundleID ?? win.appName,
                appTitle: win.appName,
                title: win.title
            )
        }
        if !config.includeActiveWindow {
            entries.removeAll { $0.window.isFocused }
        }

        // 別 Space の候補(元 collectCandidateWindows の includeOtherSpaces)
        offSpaceWindowIDs = []
        if config.includeOtherSpaces {
            let onScreenIDs = Set(ordered.map(\.id))
            let activeSpaces = Spaces.activeSpaceIDs()
            let spaceNumbers = Spaces.spaceNumbersByID()
            let others = WindowEnumerator.allSpacesWindows()
                .filter {
                    $0.pid != ProcessInfo.processInfo.processIdentifier
                        && !onScreenIDs.contains($0.id)
                }
            // Space 判定を先に行い、Space 解決不能なゴースト窓を除外する
            // (AX 呼び出し前に絞ることで大量の無関係ウィンドウへの IPC も避ける)
            var offSpace: [WindowInfo] = []
            for var win in others {
                guard let spaceID = Spaces.spaceID(of: win.id) else { continue }
                // 現Space にあるのに画面にない(最小化等)ものは対象外
                guard !activeSpaces.contains(spaceID) else { continue }
                win.spaceNumber = spaceNumbers[spaceID]
                offSpace.append(win)
            }
            for win in WindowEnumerator.offSpaceStandardWindows(from: offSpace) {
                // ネイティブタブアプリで Space 不明な候補は幽霊タブの可能性があるため除外
                let appKey = win.bundleID ?? win.appName
                if macosNativeTabsApps.contains(appKey), win.spaceNumber == nil {
                    continue
                }
                offSpaceWindowIDs.insert(win.id)
                entries.append(
                    HintKeyAssignment.Entry(
                        window: win,
                        appKey: appKey,
                        appTitle: win.appName,
                        title: win.title
                    ))
            }
        }
        // 表示順: アプリ名 → タイトル → x → y(元 collectEntries のソート)
        entries.sort { a, b in
            if a.appTitle != b.appTitle { return a.appTitle < b.appTitle }
            if a.title != b.title { return a.title < b.title }
            if a.window.frame.minX != b.window.frame.minX {
                return a.window.frame.minX < b.window.frame.minX
            }
            return a.window.frame.minY < b.window.frame.minY
        }
        return entries
    }

    /// ナビゲーションキーに予約された文字(ヒントキーから除外)
    private func reservedChars() -> Set<String> {
        var reserved = Set<String>()
        if let key = config.navigationFocusBackKey { reserved.insert(key.uppercased()) }
        if let key = config.windowMoverKey { reserved.insert(key.uppercased()) }
        if let key = config.applicationHintsKey { reserved.insert(key.uppercased()) }
        if let key = config.jinraiModeKey { reserved.insert(key.uppercased()) }
        for key in config.directionHintKeys.keys { reserved.insert(key.uppercased()) }
        if let key = config.prevSpaceKey { reserved.insert(key.uppercased()) }
        if let key = config.nextSpaceKey { reserved.insert(key.uppercased()) }
        return reserved
    }

    // MARK: - 描画

    /// ドック行き(別Space または完全に隠れた)ヒントか
    private func isDockHint(_ hint: HintKeyAssignment.Hint) -> Bool {
        offSpaceWindowIDs.contains(hint.entry.window.id)
            || occludedWindowIDs.contains(hint.entry.window.id)
    }

    /// spotlight とアクティブボーダーを破棄する。targetFrame があれば穴を新しい
    /// アクティブウィンドウへ瞬間的に移してからフェードアウトし、消えゆく残像が
    /// 「移動先が明るい」状態になるようにする(アニメーションで動かすと視線が
    /// 引っ張られて疲れるため移動表現はしない。到着の合図は FocusBorder に任せる)。
    /// nil(escape・別Space 選択等)は穴を動かさずその場でフェードアウト。
    /// animated=false は即時破棄。直後に Area Hints 等が同位置に spotlight を
    /// 瞬間表示する受け渡しで使い、クロスフェードによる画面全体のフラッシュを防ぐ
    private func dismissSpotlight(movingTo targetFrame: CGRect?, animated: Bool = true) {
        let items = spotlightOverlays
        spotlightOverlays = []
        for item in items {
            if !animated {
                item.overlay.orderOut(nil)
                continue
            }
            // ボーダーは即座に消す
            item.highlight?.removeFromSuperlayer()
            if let targetFrame {
                // 穴を移動先へ瞬間切替してから消す。消えゆく残像が
                // 「移動先が明るい」状態になり、到着の合図は FocusBorder に任せる
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                item.spotlight.path = ActiveWindowOverlayLayers.spotlightPath(
                    windowFrame: targetFrame, screenFrame: item.screenFrame,
                    overlayHeight: item.screenFrame.height)
                CATransaction.commit()
            }
            // 高速な連続操作のテンポを削らないよう、表示時と同じ短さでさっと消す
            let overlay = item.overlay
            let duration = 0.15
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                overlay.animator().alphaValue = 0
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                overlay.orderOut(nil)
            }
        }
    }

    private func buildOverlays(fadeIn: Bool = true) {
        let focusedWindowFrame = hints.first {
            !isDockHint($0) && $0.entry.window.isFocused
        }?.entry.window.frame

        // spotlight + アクティブボーダーはヒントと別のオーバーレイに置く
        // (ウィンドウ切替時にヒントだけ即閉じ、こちらは穴を移してフェードアウトする
        //  余韻を残すため)。ヒント用オーバーレイより先に orderFront して背面にする
        if let focusedWindowFrame {
            for screen in NSScreen.screens {
                let screenFrame = ScreenUtil.frame(of: screen)
                let overlay = OverlayWindow(frame: screenFrame, level: .hints)
                guard let root = overlay.rootLayer else { continue }
                // フェードはオーバーレイウィンドウ全体(下記)で行うため層単位では不要
                let spotlight = ActiveWindowOverlayLayers.spotlightLayer(
                    windowFrame: focusedWindowFrame, screenFrame: screenFrame,
                    overlayHeight: screenFrame.height,
                    alpha: CGFloat(config.focusedSpotlightAlpha),
                    fadeIn: false)
                root.addSublayer(spotlight)
                var highlight: CAShapeLayer?
                if screenFrame.intersects(focusedWindowFrame) {
                    let layer = ActiveWindowOverlayLayers.highlightLayer(
                        windowFrame: focusedWindowFrame, screenFrame: screenFrame,
                        overlayHeight: screenFrame.height,
                        borderColor: config.focusedHighlightColor,
                        borderWidth: CGFloat(config.focusedHighlightWidth),
                        cornerRadius: CGFloat(config.cornerRadius))
                    root.addSublayer(layer)
                    highlight = layer
                }
                overlay.orderFrontRegardless()
                spotlightOverlays.append(
                    SpotlightOverlay(
                        overlay: overlay, spotlight: spotlight, highlight: highlight,
                        screenFrame: screenFrame))
            }
        }

        for screen in NSScreen.screens {
            let screenFrame = ScreenUtil.frame(of: screen)
            let overlay = OverlayWindow(frame: screenFrame, level: .hints)
            guard let root = overlay.rootLayer else { continue }

            // 収集: 各ヒントの希望center(ウィンドウ中心、画面内クランプ)とサイズ
            var containers: [String: CALayer] = [:]
            var layoutItems: [HintLayout.Item] = []
            for hint in hints where !isDockHint(hint) {
                let winFrame = hint.entry.window.frame
                guard screenFrame.intersects(winFrame) else { continue }

                let container = hintContainer(for: hint)
                let size = container.bounds.size
                // 見えている(前面ウィンドウに覆われていない)領域の中央に置く。
                // 前面ウィンドウは coveringFrames が空なので幾何中心のまま
                var center = Occlusion.findUncoveredCenter(
                    windowFrame: winFrame,
                    coveringFrames: coveringFramesByID[hint.entry.window.id] ?? [])
                // 画面内に収める
                center.x = min(
                    max(center.x, screenFrame.minX + size.width / 2),
                    screenFrame.maxX - size.width / 2)
                center.y = min(
                    max(center.y, screenFrame.minY + size.height / 2),
                    screenFrame.maxY - size.height / 2)

                containers[hint.key] = container
                layoutItems.append(
                    HintLayout.Item(
                        key: hint.key, center: center,
                        width: size.width, height: size.height,
                        priority: windowZOrder[hint.entry.window.id] ?? Int.max))
            }

            // 解決 → 配置: 前面ウィンドウのヒントを優先して希望位置に置き、重なりは後順が避ける
            var normalFrames: [CGRect] = []
            for placement in HintLayout.layout(items: layoutItems, screenFrame: screenFrame) {
                guard let container = containers[placement.key] else { continue }
                let global = placement.frame
                // overlay 内ローカル座標(AppKit: bottom-left 原点)へ変換
                let localX = global.minX - screenFrame.minX
                let localY =
                    screenFrame.height - (global.minY - screenFrame.minY) - global.height
                container.frame = CGRect(
                    x: localX, y: localY, width: global.width, height: global.height)
                root.addSublayer(container)

                hintContainers[placement.key] = container
                hintFrames[placement.key] = global
                normalFrames.append(global)
            }

            // ドック(別Space・隠れウィンドウの候補)は通常ヒントを避けて配置する
            buildDock(
                root: root, screenFrame: screenFrame, screen: screen,
                obstacles: normalFrames)

            overlay.orderFrontRegardless()
            overlays.append(overlay)
        }

        // ヒントと spotlight を別々の時間で ease-in で立ち上げる(開始は同時)。
        // ヒントは小面積なので短く出して即応感を優先し、画面全体の輝度が変わる
        // spotlight は長めに取ることで、高速な操作では暗転がほぼ知覚されず、
        // 迷った(時間をかけた)ぶんだけ暗幕が満ちてくる
        if fadeIn {
            fadeInOverlays(overlays, duration: config.showFadeInHints)
            fadeInOverlays(
                spotlightOverlays.map(\.overlay), duration: config.showFadeInSpotlight)
        }

        // プレビュー画像を非同期で撮影し、確保済みの層へ差し込む
        // (close 済みなら previewLayersByWindowID が空になっており何もしない)
        if !previewLayersByWindowID.isEmpty {
            let windowIDs = Array(previewLayersByWindowID.keys)
            Task { @MainActor [weak self] in
                let images = await WindowCapture.captureImages(windowIDs: windowIDs)
                guard let self, self.isVisible else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                for (windowID, image) in images {
                    self.previewLayersByWindowID[windowID]?.contents = image
                }
                CATransaction.commit()
            }
        }
    }

    private func fadeInOverlays(_ targets: [OverlayWindow], duration: Double) {
        guard duration > 0, !targets.isEmpty else { return }
        for overlay in targets {
            overlay.alphaValue = 0
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for overlay in targets {
                overlay.animator().alphaValue = 1
            }
        }
    }

    /// 別Space・完全に隠れた候補を、そのウィンドウが属するスクリーンに並べる。
    /// dock.windowBlend でウィンドウの実位置(X は 0.65、Y は上半分なら画面上端)へ寄せ、
    /// obstacles(通常ヒント)と重なる場合は dock 側が避ける
    private func buildDock(
        root: CALayer, screenFrame: CGRect, screen: NSScreen, obstacles: [CGRect]
    ) {
        let dockHints = hints.filter {
            isDockHint($0) && ScreenUtil.screenContaining($0.entry.window.frame) == screen
        }
        guard !dockHints.isEmpty else { return }

        // ラベルを natural サイズで構築し、DockLayout(PAV + 画面内シフト + 行分割)で配置
        let containers = Dictionary(
            uniqueKeysWithValues: dockHints.map { ($0.key, hintContainer(for: $0)) })
        let items = dockHints.map { hint -> DockLayout.Item in
            let size = containers[hint.key]!.bounds.size
            let winFrame = hint.entry.window.frame
            return DockLayout.Item(
                key: hint.key, width: size.width, height: size.height,
                windowCenterX: winFrame.midX, windowCenterY: winFrame.midY)
        }

        let placements = DockLayout.layout(
            items: items,
            screenFrame: screenFrame,
            gap: CGFloat(config.dockItemGap),
            dockMargin: CGFloat(config.dockBottomMargin),
            xBlend: CGFloat(config.dockWindowXBlend),
            yBlend: CGFloat(config.dockWindowYBlend))

        // DockLayout の結果を希望位置として、通常ヒント(obstacles)を避ける位置へ再解決。
        // priority は DockLayout の並び順を維持
        let resolveItems = placements.enumerated().map { index, placement in
            HintLayout.Item(
                key: placement.key,
                center: CGPoint(x: placement.frame.midX, y: placement.frame.midY),
                width: placement.frame.width, height: placement.frame.height,
                priority: index)
        }
        let resolved = HintLayout.layout(
            items: resolveItems, screenFrame: screenFrame, obstacles: obstacles,
            gap: CGFloat(config.dockItemGap))

        for placement in resolved {
            guard let container = containers[placement.key] else { continue }
            let global = placement.frame
            let localX = global.minX - screenFrame.minX
            let localY = screenFrame.height - (global.minY - screenFrame.minY) - global.height
            container.frame = CGRect(
                x: localX, y: localY, width: global.width, height: global.height)
            root.addSublayer(container)
            hintContainers[placement.key] = container
            hintFrames[placement.key] = global
        }
    }

    private func hintState(of hint: HintKeyAssignment.Hint) -> HintState {
        if hint.entry.window.isFocused { return .active }
        if isDockHint(hint) { return .occluded }
        return .normal
    }

    /// Space 番号バッジの色パレット(元 spaceBadge.spaceColors: 青/緑/橙/紫/桃)
    private static let spaceBadgeColors: [ConfigColor] = [
        ConfigColor(red: 0.34, green: 0.64, blue: 0.96, alpha: 0.56),
        ConfigColor(red: 0.30, green: 0.78, blue: 0.47, alpha: 0.56),
        ConfigColor(red: 0.95, green: 0.60, blue: 0.25, alpha: 0.56),
        ConfigColor(red: 0.68, green: 0.42, blue: 0.90, alpha: 0.56),
        ConfigColor(red: 0.92, green: 0.38, blue: 0.58, alpha: 0.56),
    ]

    /// ヒント1個分のレイヤー(角丸背景+アイコン+キー+タイトル)
    private func hintContainer(for hint: HintKeyAssignment.Hint) -> CALayer {
        let state = hintState(of: hint)
        let style = config.states[state] ?? config.states[.normal]!

        let padding = CGFloat(config.padding)
        let iconSize = CGFloat(config.iconSize)

        let keyText = textLayer(
            hint.key, fontSize: config.keyFontSize, color: style.keyColor, bold: true)
        let title =
            config.titleShow
            ? textLayer(
                truncate(
                    hint.entry.title.isEmpty ? hint.entry.appTitle : hint.entry.title,
                    max: config.titleMaxSize),
                fontSize: config.titleFontSize, color: style.titleColor, bold: false)
            : nil

        // 隠れウィンドウのプレビュー(要・画面収録権限。未許可時はスキップ)。
        // ScreenCaptureKit は非同期 API のため、ここではウィンドウの frame から
        // サイズだけ確保し、画像は撮影完了後に差し込む(buildOverlays 末尾の Task)
        let winFrame = hint.entry.window.frame
        let expectsPreview =
            isDockHint(hint) && config.previewEnabled && WindowCapture.hasPermission
            && Geometry.isValidFrame(winFrame)
        var belowPreviewSize = CGSize.zero
        if expectsPreview, config.previewMode == "below" {
            // アスペクト比はキャプチャ画像と同じなので frame から算出できる
            let width = CGFloat(config.previewWidth)
            belowPreviewSize = CGSize(
                width: width,
                height: width * winFrame.height / winFrame.width)
        }

        let contentWidth = max(
            iconSize + 8 + keyText.preferredFrameSize().width,
            title?.preferredFrameSize().width ?? 0,
            belowPreviewSize.width,
            CGFloat(config.keyMinWidth))
        let contentHeight =
            max(iconSize, keyText.preferredFrameSize().height)
            + (title != nil ? title!.preferredFrameSize().height + 8 : 0)
            + (belowPreviewSize.height > 0
                ? belowPreviewSize.height + CGFloat(config.previewPadding) : 0)

        var containerWidth = contentWidth + padding * 2
        var containerHeight = contentHeight + padding * 2
        // mode "background": ウィンドウの実サイズに比例した box にする
        // (元実装: scaleFactor = 2 * previewWidth / 画面高さ)
        if expectsPreview, config.previewMode == "background" {
            if let screen = ScreenUtil.screenContaining(winFrame) {
                // スクリーンの短辺を基準にする(元実装はスクリーン高さ基準だったが、
                // 縦長ディスプレイでは高さ=長辺のためスケールが過小になり
                // ボックスの高さが潰れる。横長では高さ=短辺なので挙動は変わらない)
                let screenFrame = ScreenUtil.frame(of: screen)
                let shorterSide = min(screenFrame.width, screenFrame.height)
                if shorterSide > 0 {
                    let scaleFactor = 2 * CGFloat(config.previewWidth) / shorterSide
                    containerWidth = max(containerWidth, (winFrame.width * scaleFactor).rounded(.down))
                    containerHeight = max(containerHeight, (winFrame.height * scaleFactor).rounded(.down))
                }
            }
        }

        let container = CALayer()
        container.bounds = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
        container.backgroundColor = cgColor(style.bgColor)
        container.cornerRadius = CGFloat(config.cornerRadius)

        // ヒント箱の overlay 塗り(アクティブ=橙 / 通常=青)。dock(occluded)には描かない
        let isDock = isDockHint(hint)
        if !isDock {
            let colors = overlayColors(
                isActiveWindow: hint.entry.window.isFocused, matched: true)
            let fill = CALayer()
            fill.frame = container.bounds
            fill.cornerRadius = CGFloat(config.cornerRadius)
            fill.backgroundColor = cgColor(colors.fill)
            container.addSublayer(fill)
            hintOverlayFills[hint.key] = fill
        }

        // mode "background": プレビューをヒント全体の背景として敷く。
        // 角丸クリップは preview 層側で行う(container を masksToBounds にすると
        // 下で付けるシャドウごと切られて描画されないため)
        if expectsPreview, config.previewMode == "background" {
            let previewLayer = CALayer()
            previewLayer.contentsGravity = .resizeAspectFill
            previewLayer.masksToBounds = true
            previewLayer.cornerRadius = container.cornerRadius
            previewLayer.frame = container.bounds
            previewLayer.opacity = Float(config.previewAlpha)
            container.addSublayer(previewLayer)
            previewLayersByWindowID[hint.entry.window.id] = previewLayer
        }

        // プレビュー付きヒントは背後のウィンドウと色が近いと境界が消えるため、
        // シャドウ(明るい背景で効く)と淡い縁取り(暗い背景で効く)を併用する
        if expectsPreview {
            container.borderWidth = 1
            container.borderColor = NSColor(white: 1, alpha: 0.3).cgColor
            container.shadowColor = NSColor.black.cgColor
            container.shadowOpacity = 0.5
            container.shadowRadius = 6
            container.shadowOffset = CGSize(width: 0, height: -2)
            container.shadowPath = CGPath(
                roundedRect: container.bounds,
                cornerWidth: container.cornerRadius, cornerHeight: container.cornerRadius,
                transform: nil)
        }

        // コンテンツ(アイコン+キー+タイトル)は container 内で上下中央に置く
        var bottomY = padding + max(0, (containerHeight - contentHeight - padding * 2) / 2)
        if expectsPreview, belowPreviewSize.height > 0 {
            let previewLayer = CALayer()
            previewLayer.contentsGravity = .resizeAspectFill
            previewLayer.masksToBounds = true
            previewLayer.cornerRadius = 4
            // ヒント箱の背景色とプレビュー内容が近くても境界が分かるよう縁取り
            previewLayer.borderWidth = 1
            previewLayer.borderColor = NSColor(white: 1, alpha: 0.3).cgColor
            previewLayer.opacity = Float(config.previewAlpha)
            previewLayer.frame = CGRect(
                x: (container.bounds.width - belowPreviewSize.width) / 2,
                y: bottomY,
                width: belowPreviewSize.width, height: belowPreviewSize.height)
            container.addSublayer(previewLayer)
            previewLayersByWindowID[hint.entry.window.id] = previewLayer
            bottomY += belowPreviewSize.height + CGFloat(config.previewPadding)
        }

        // アイコン+キーの行をセットで左右中央に、タイトルを下段に
        let topRowY = bottomY + (title != nil ? title!.preferredFrameSize().height + 8 : 0)
        let keySize = keyText.preferredFrameSize()
        let topRowWidth = iconSize + 8 + keySize.width
        let topRowX = (container.bounds.width - topRowWidth) / 2
        if let app = NSRunningApplication(processIdentifier: hint.entry.window.pid) {
            let iconLayer = CALayer()
            let icon = app.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
            var rect = CGRect(origin: .zero, size: icon.size)
            iconLayer.contents = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            iconLayer.frame = CGRect(x: topRowX, y: topRowY, width: iconSize, height: iconSize)
            iconLayer.opacity = Float(style.iconAlpha)
            container.addSublayer(iconLayer)
        }

        keyText.frame = CGRect(
            x: topRowX + iconSize + 8,
            y: topRowY + (iconSize - keySize.height) / 2,
            width: keySize.width, height: keySize.height)
        container.addSublayer(keyText)
        hintKeyLayers[hint.key] = keyText

        if let title {
            let titleSize = title.preferredFrameSize()
            title.frame = CGRect(
                x: (container.bounds.width - titleSize.width) / 2,
                y: bottomY,
                width: titleSize.width, height: titleSize.height)
            container.addSublayer(title)
        }

        // Space 番号バッジ(別Space候補のみ、右上に表示)
        if let spaceNumber = hint.entry.window.spaceNumber {
            let badgeSize: CGFloat = 32
            let color = Self.spaceBadgeColors[(spaceNumber - 1) % Self.spaceBadgeColors.count]
            let badge = CATextLayer()
            badge.string = String(spaceNumber)
            badge.font = NSFont.boldSystemFont(ofSize: 18)
            badge.fontSize = 18
            badge.alignmentMode = .center
            badge.foregroundColor = CGColor(gray: 1, alpha: 0.92)
            badge.backgroundColor = CGColor(
                red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            badge.borderColor = CGColor(red: 0.98, green: 0.99, blue: 1.00, alpha: 0.72)
            badge.borderWidth = 1
            badge.cornerRadius = badgeSize / 2
            badge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            badge.frame = CGRect(
                x: container.bounds.width - badgeSize - 4,
                y: container.bounds.height - badgeSize - 4,
                width: badgeSize, height: badgeSize)
            container.addSublayer(badge)
        }

        // ヒント箱の枠線(アクティブ=橙 / 通常=青 / 候補外=灰)
        if !isDock {
            let colors = overlayColors(
                isActiveWindow: hint.entry.window.isFocused, matched: true)
            let bw = CGFloat(config.overlayBorderWidth)
            let border = CAShapeLayer()
            border.path = CGPath(
                roundedRect: container.bounds.insetBy(dx: bw / 2, dy: bw / 2),
                cornerWidth: CGFloat(config.cornerRadius),
                cornerHeight: CGFloat(config.cornerRadius), transform: nil)
            border.fillColor = nil
            border.lineWidth = bw
            border.strokeColor = cgColor(colors.border)
            container.addSublayer(border)
            hintOverlayBorders[hint.key] = border
        }

        return container
    }

    /// ヒント箱の overlay 塗り・枠線の色(元 resolveHintOverlayFill/BorderColor)。
    /// matched=false は入力で候補外になった状態
    private func overlayColors(isActiveWindow: Bool, matched: Bool)
        -> (fill: ConfigColor, border: ConfigColor)
    {
        let fill =
            (matched && isActiveWindow)
            ? config.activeOverlayFillColor : config.overlayFillColor
        let border: ConfigColor
        if isActiveWindow {
            border = matched ? config.activeOverlayBorderColor : config.dimmedOverlayBorderColor
        } else {
            border = matched ? config.overlayBorderColor : config.dimmedOverlayBorderColor
        }
        return (fill, border)
    }

    private func textLayer(
        _ text: String, fontSize: Double, color: ConfigColor, bold: Bool
    ) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = text
        layer.font = bold
            ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        layer.fontSize = fontSize
        layer.foregroundColor = cgColor(color)
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer.alignmentMode = .center
        return layer
    }

    private func truncate(_ text: String, max maxSize: Int) -> String {
        text.count <= maxSize ? text : String(text.prefix(maxSize)) + "…"
    }

    private func cgColor(_ color: ConfigColor) -> CGColor {
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    // MARK: - 入力処理

    /// ナビゲーションキー比較用のキー名("space" "return" 等の特殊キー名に正規化)
    private func keyName(of event: EventTap.KeyEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space: return "space"
        case kVK_Return: return "return"
        case kVK_Tab: return "tab"
        default: return event.character?.lowercased()
        }
    }

    private func handleKeyDown(_ event: EventTap.KeyEvent) -> Bool {
        guard isVisible else { return false }

        // Escape で閉じる
        if event.keyCode == UInt32(kVK_Escape) {
            close()
            return true
        }
        // ホットキー再押下でトグル(モーダル中は Carbon ホットキーに届かないため自前判定)
        if let hotkeyKey = config.hotkeyKey,
            let hotkeyCode = KeyCodes.keyCode(for: hotkeyKey),
            event.keyCode == hotkeyCode,
            event.flags.contains(KeyCodes.cgEventFlags(for: config.hotkeyModifiers))
        {
            close()
            return true
        }
        // Backspace で1文字戻す
        if event.keyCode == UInt32(kVK_Delete) || event.keyCode == UInt32(kVK_ForwardDelete) {
            currentInput = HintInputMatcher.backspace(currentInput: currentInput)
            updateHighlight()
            return true
        }
        // focusBack キー(JinraiMode 中は選択と同じ扱いでエリア選択へ)
        if let name = keyName(of: event),
            name == config.navigationFocusBackKey,
            let focusHistory
        {
            if isJinraiMode {
                // 直後にエリア選択(または Hints 再表示)の spotlight が出るため即時破棄
                dismissSpotlight(movingTo: nil, animated: false)
                close(keepJinraiMode: true)
                if let target = focusHistory.focusBack(centerCursor: config.cursorOnSelect) {
                    jinraiModeAdvance(windowID: target.windowID, pid: target.pid)
                } else {
                    // 戻り先がない場合は Hints を再表示してループ継続
                    show(fadeIn: false)
                }
            } else {
                // 戻り先(=直前のウィンドウ)へ spotlight の穴を移して消す
                dismissSpotlight(movingTo: focusHistory.previousWindow()?.frame)
                close()
                focusHistory.focusBack(centerCursor: config.cursorOnSelect)
            }
            return true
        }
        // 数字キー 1〜9 で該当 Space へ移動
        if config.spacesNumbers,
            let character = event.character,
            let number = Int(character), (1...9).contains(number)
        {
            close()
            Spaces.gotoSpace(number: number)
            return true
        }
        // 前後の Space へ移動
        if let name = keyName(of: event) {
            if name == config.prevSpaceKey {
                close()
                Spaces.gotoPrevSpace()
                return true
            }
            if name == config.nextSpaceKey {
                close()
                Spaces.gotoNextSpace()
                return true
            }
        }
        // JinraiMode 開始(triggers.windowHints.key。Hints は開いたまま)
        if let name = keyName(of: event),
            name == config.jinraiModeKey
        {
            if !isJinraiMode {
                startJinraiMode()
            }
            return true
        }
        // Window Mover のエリア選択へ遷移
        if let name = keyName(of: event),
            name == config.windowMoverKey,
            let onOpenWindowMover
        {
            let jinrai = isJinraiMode
            // 直後にエリア選択の spotlight が同位置に出るため即時破棄(受け渡し)
            dismissSpotlight(movingTo: nil, animated: false)
            close(keepJinraiMode: jinrai)
            onOpenWindowMover(jinrai)
            return true
        }
        // Application Hints へ遷移(navigation.applicationHints.jinraiMode で mode 開始)
        if let name = keyName(of: event),
            name == config.applicationHintsKey,
            let onOpenApplicationHints
        {
            let jinrai = isJinraiMode || config.applicationHintsJinraiMode
            if jinrai && !isJinraiMode {
                startJinraiMode()
            }
            // 以後のフォーカス先はアプリ起動側で決まるため、選択アンカーを解除
            if jinrai {
                jinraiVisuals.clearAnchor()
            }
            close(keepJinraiMode: jinrai)
            onOpenApplicationHints(jinrai)
            return true
        }
        // 方向キー(8方向ナビゲーション)
        if let name = keyName(of: event),
            let direction = config.directionHintKeys[name]
        {
            runDirectionalMove(direction)
            return true
        }

        // ヒント文字の逐次マッチ
        guard let character = event.character, !character.isEmpty,
            character.rangeOfCharacter(from: .alphanumerics) != nil
        else { return true }

        switch HintInputMatcher.advance(
            currentInput: currentInput, char: character, keys: hints.map(\.key))
        {
        case .selected(let key):
            if let hint = hints.first(where: { $0.key == key }) {
                let swap =
                    config.swapModifiers.map {
                        event.flags.contains(KeyCodes.cgEventFlags(for: $0))
                    } ?? false
                selectWindow(hint, swap: swap)
            }
        case .partial(let input):
            currentInput = input
            updateHighlight()
        case .reset:
            currentInput = ""
            updateHighlight()
        }
        return true  // 表示中は全キーを消費
    }

    private func handleMouseDown(_ location: CGPoint) -> Bool {
        guard isVisible else { return false }
        // ヒント上のクリック → 選択、外側 → 閉じる
        if let hint = hints.first(where: { hintFrames[$0.key]?.contains(location) == true }) {
            selectWindow(hint)
            return true
        }
        close()
        return false  // 外クリックはアプリに透過
    }

    /// JinraiMode 中にフォーカス済みウィンドウを「選択」として扱い、エリア選択へ遷移する。
    /// アンカー設定で別ディスプレイでも演出が追従する
    /// (frontmostApplication の更新は非同期で、focus 直後は旧ウィンドウを指すため)
    private func jinraiModeAdvance(windowID: UInt32, pid: pid_t) {
        jinraiVisuals.setAnchor(windowID: windowID, pid: pid)
        jinraiVisuals.showLogo()
        onJinraiModeSelect?(windowID, pid)
    }

    private func selectWindow(_ hint: HintKeyAssignment.Hint, swap: Bool = false) {
        let window = hint.entry.window
        let isOffSpace = offSpaceWindowIDs.contains(window.id)

        // JinraiMode 中の選択: mode 維持で閉じる → focus → エリア選択へ
        if isJinraiMode {
            // 直後にエリア選択の spotlight が選択先に出るため即時破棄(受け渡し)
            dismissSpotlight(movingTo: nil, animated: false)
            close(keepJinraiMode: true)
            if let ax = AXWindow.resolve(windowID: window.id, pid: window.pid) {
                ax.focus()
                if config.cursorOnSelect {
                    Mouse.moveToCenter(of: ax.frame ?? window.frame)
                }
            } else if isOffSpace {
                // 別Space の候補は Space 切替とフォーカス完了を待ってからエリア選択へ
                focusOffSpaceWindow(window) { [weak self] in
                    self?.jinraiModeAdvance(windowID: window.id, pid: window.pid)
                }
                return
            }
            jinraiModeAdvance(windowID: window.id, pid: window.pid)
            return
        }

        // 選択先へ spotlight の穴を移して消す(別Space は Space 切替を伴うため対象外)
        dismissSpotlight(movingTo: isOffSpace ? nil : window.frame)
        close()
        guard let ax = AXWindow.resolve(windowID: window.id, pid: window.pid) else {
            if isOffSpace {
                focusOffSpaceWindow(window)
            }
            return
        }
        if swap, let focused = WindowEnumerator.focusedWindow(),
            focused.windowID != ax.windowID,
            let fromFrame = focused.frame, let toFrame = ax.frame
        {
            // 移動元と移動先の frame を交換(元 swapWindowFrames)
            focused.setFrame(toFrame)
            ax.setFrame(fromFrame)
        }
        ax.focus()
        if config.cursorOnSelect {
            Mouse.moveToCenter(of: ax.frame ?? window.frame)
        }
    }

    /// 別Space のウィンドウは AX で列挙できず resolve が失敗する(macOS の制限)ため、
    /// 観測済みの AX 要素キャッシュから focus する(FocusBack と同じ経路。
    /// macOS が対象の Space へ自動的に切り替える。元 hs.window:focus() 相当)
    private func focusOffSpaceWindow(_ window: WindowInfo, completion: (() -> Void)? = nil) {
        if let cached = WindowRegistry.shared.window(for: window.id) {
            cached.focus()
            if config.cursorOnSelect {
                Mouse.moveToCenter(of: cached.frame ?? window.frame)
            }
            completion?()
            return
        }
        // 未観測(起動後その Space を訪れていない)場合は window server 経由で試みる
        WindowServerFocus.focus(windowID: window.id, pid: window.pid)
        Task { @MainActor [weak self] in
            // Space 切替完了後は AX で解決できるようになるため、
            // 再試行して raise とカーソル移動を仕上げる(最大 1 秒)
            for _ in 0..<10 {
                try? await Task.sleep(for: .seconds(0.1))
                if let ax = AXWindow.resolve(windowID: window.id, pid: window.pid) {
                    ax.focus()
                    if self?.config.cursorOnSelect == true {
                        Mouse.moveToCenter(of: ax.frame ?? window.frame)
                    }
                    break
                }
            }
            completion?()
        }
    }

    /// 方向ナビゲーション: 現Space の非オクルージョン候補から最良を選んでフォーカス。
    /// JinraiMode 中は選択と同じ扱いでエリア選択へ遷移する
    private func runDirectionalMove(_ direction: Direction) {
        let ordered = WindowEnumerator.orderedWindows()
            .filter { $0.pid != ProcessInfo.processInfo.processIdentifier }
        let standard = WindowEnumerator.standardWindows(from: ordered)
        // フォーカス中 = 最前面の標準ウィンドウ(collectEntries と同じ判定)
        guard let current = standard.first else {
            close(keepJinraiMode: isJinraiMode)
            return
        }
        let candidates = standard
            .filter {
                !DirectionScoring.isFullyOccludedWindow(
                    $0, orderedWindows: ordered, config: config.directionScoring)
            }
        let previous = focusHistory?.previousWindow().flatMap { prev in
            ordered.first { $0.id == prev.windowID }
        }
        let target = DirectionScoring.findDirectionalWindowTarget(
            current: current,
            candidates: candidates,
            direction: direction,
            previous: previous,
            orderedWindows: ordered,
            config: config.directionScoring
        )
        if isJinraiMode {
            // 直後にエリア選択(または Hints 再表示)の spotlight が出るため即時破棄
            dismissSpotlight(movingTo: nil, animated: false)
        } else {
            dismissSpotlight(movingTo: target?.frame)
        }
        close(keepJinraiMode: isJinraiMode)
        guard let target,
            let ax = AXWindow.resolve(windowID: target.id, pid: target.pid)
        else {
            // JinraiMode 中に移動先がない(画面端など)場合は再表示してループ継続
            if isJinraiMode {
                show(fadeIn: false)
            }
            return
        }
        ax.focus()
        if config.cursorOnSelect {
            Mouse.moveToCenter(of: ax.frame ?? target.frame)
        }
        if isJinraiMode {
            jinraiModeAdvance(windowID: target.id, pid: target.pid)
        }
    }

    /// 入力中の接頭辞に一致しないヒントを dimmed に、
    /// 一致するヒントは押下済みプレフィックス文字を keyHighlightColor でグレーアウトする
    private func updateHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for hint in hints {
            guard let container = hintContainers[hint.key] else { continue }
            let matches = currentInput.isEmpty || hint.key.hasPrefix(currentInput)
            let state: HintState = matches ? hintState(of: hint) : .dimmed
            let style = config.states[state] ?? config.states[.normal]!
            container.backgroundColor = cgColor(style.bgColor)
            container.opacity = matches ? 1.0 : 0.35

            // ヒント箱の overlay 塗り・枠線を状態に合わせて更新
            if let fill = hintOverlayFills[hint.key],
                let border = hintOverlayBorders[hint.key]
            {
                let colors = overlayColors(
                    isActiveWindow: hint.entry.window.isFocused, matched: matches)
                fill.backgroundColor = cgColor(colors.fill)
                border.strokeColor = cgColor(colors.border)
            }

            guard let keyLayer = hintKeyLayers[hint.key] else { continue }
            let prefixLength =
                matches && !currentInput.isEmpty
                ? min(currentInput.count, hint.key.count) : 0
            if prefixLength > 0 {
                let attributed = NSMutableAttributedString()
                attributed.append(
                    NSAttributedString(
                        string: String(hint.key.prefix(prefixLength)),
                        attributes: [
                            .font: NSFont.boldSystemFont(ofSize: config.keyFontSize),
                            .foregroundColor: nsColor(config.keyHighlightColor),
                        ]))
                attributed.append(
                    NSAttributedString(
                        string: String(hint.key.dropFirst(prefixLength)),
                        attributes: [
                            .font: NSFont.boldSystemFont(ofSize: config.keyFontSize),
                            .foregroundColor: nsColor(style.keyColor),
                        ]))
                keyLayer.string = attributed
            } else {
                keyLayer.string = hint.key
                keyLayer.foregroundColor = cgColor(style.keyColor)
            }
        }
        CATransaction.commit()
    }

    private func nsColor(_ color: ConfigColor) -> NSColor {
        NSColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    func teardown() {
        close()
        stopJinraiMode()
        hotkey?.unregister()
        hotkey = nil
    }
}
