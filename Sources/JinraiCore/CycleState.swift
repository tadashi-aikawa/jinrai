import CoreGraphics
import Foundation

/// サイクルリサイズ(元 window_mover.lua の cycle 系コマンド)。
/// 同一コマンドの反復で比率(既定 1/2 → 1/3 → 2/3)を順に適用する。
public enum CycleCommand: String, CaseIterable, Sendable {
    case cycleLeft, cycleHorizontalCenter, cycleRight
    case cycleTop, cycleVerticalCenter, cycleBottom

    public var isHorizontal: Bool {
        switch self {
        case .cycleLeft, .cycleHorizontalCenter, .cycleRight: return true
        case .cycleTop, .cycleVerticalCenter, .cycleBottom: return false
        }
    }
}

public struct CycleState {
    public static var defaultRatios: [CGFloat] { [1.0 / 2.0, 1.0 / 3.0, 2.0 / 3.0] }
    public static var frameTolerance: CGFloat { 16 }

    private var lastCommand: CycleCommand?
    private var lastIndex: Int?
    /// 前回 setFrame 後に読み直した実 frame(手動リサイズ検出用)
    private var lastActualFrame: CGRect?

    public init() {}

    /// 次に適用すべき比率のインデックスを決める。
    /// 同一コマンドの連続実行で、現 frame が前回適用後の実 frame と近ければ次の比率へ進む。
    /// cycle 以外の手段(Area Hints 等)で配置された場合でも、現 frame がいずれかの比率の
    /// ターゲットと一致すればその次の比率へ進む。どちらにも該当しなければ先頭から再開する。
    public func nextIndex(
        command: CycleCommand, currentFrame: CGRect,
        ratios: [CGFloat], screenFrame: CGRect
    ) -> Int {
        guard !ratios.isEmpty else { return 0 }
        // 記憶ベース判定: アプリの最小サイズ制約などでターゲットどおりに設定できず、
        // 実 frame が理想ターゲットとズレていても、前回適用後の実 frame と一致すれば
        // サイクル継続とみなす
        if lastCommand == command, let lastIndex, let lastActualFrame,
            Geometry.frameNear(currentFrame, lastActualFrame, tolerance: Self.frameTolerance)
        {
            return (lastIndex + 1) % ratios.count
        }
        // 幾何フォールバック: 現 frame がいずれかの比率のターゲットと一致するなら次へ
        if let matched = ratios.firstIndex(where: {
            Geometry.frameNear(
                currentFrame,
                Self.targetFrame(command: command, ratio: $0, screenFrame: screenFrame),
                tolerance: Self.frameTolerance)
        }) {
            return (matched + 1) % ratios.count
        }
        return 0
    }

    /// setFrame 適用後に、読み直した実 frame とともに状態を記録する
    public mutating func recordApplied(
        command: CycleCommand, index: Int, actualFrame: CGRect
    ) {
        lastCommand = command
        lastIndex = index
        lastActualFrame = actualFrame
    }

    public mutating func reset() {
        lastCommand = nil
        lastIndex = nil
        lastActualFrame = nil
    }

    /// コマンドと比率からターゲット frame を算出(スクリーン作業領域基準)
    public static func targetFrame(
        command: CycleCommand, ratio: CGFloat, screenFrame: CGRect
    ) -> CGRect {
        if command.isHorizontal {
            let width = screenFrame.width * ratio
            let x: CGFloat
            switch command {
            case .cycleLeft: x = screenFrame.minX
            case .cycleHorizontalCenter: x = screenFrame.minX + (screenFrame.width - width) / 2
            case .cycleRight: x = screenFrame.maxX - width
            default: x = screenFrame.minX
            }
            return CGRect(x: x, y: screenFrame.minY, width: width, height: screenFrame.height)
        }
        let height = screenFrame.height * ratio
        let y: CGFloat
        switch command {
        case .cycleTop: y = screenFrame.minY
        case .cycleVerticalCenter: y = screenFrame.minY + (screenFrame.height - height) / 2
        case .cycleBottom: y = screenFrame.maxY - height
        default: y = screenFrame.minY
        }
        return CGRect(x: screenFrame.minX, y: y, width: screenFrame.width, height: height)
    }
}
