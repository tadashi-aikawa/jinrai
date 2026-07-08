import CoreGraphics
import Foundation

/// エリア選択画面のラベルボックス配置(元 window_mover.lua の
/// areaLabelFrameForCandidate / resolveAreaLabelFrames)。
/// エリア矩形は描画せず、小さなラベルボックスだけを配置する。
/// 座標は top-left 原点。
public enum AreaLabelLayout {
    public static var labelHeight: CGFloat { 52 }
    public static var labelHeightWithDetail: CGFloat { 66 }
    public static var minMargin: CGFloat { 8 }
    public static var gap: CGFloat { 8 }
    public static var keyFontSize: CGFloat { 26 }
    public static var detailFontSize: CGFloat { 13 }
    public static var iconWidth: CGFloat { 38 }
    public static var iconHeight: CGFloat { 30 }

    /// ミニアイコン(38x30)の塗り方(元 areaSpecForName の slotInfo)
    public enum IconSpec: Equatable, Sendable {
        /// N 分割の index 番目から span 個分の帯(vertical=false は横分割)
        case slot(slots: Int, index: Int, span: Int, vertical: Bool)
        /// グリッドの該当セル
        case grid(cols: Int, rows: Int, col: Int, row: Int)
        /// 中央に比率縮小の矩形
        case centeredRatio(Double)
        /// 四隅ドット(freeArea)
        case free
        /// 四隅+中央ドット(WxHCenter)
        case fixedSizeCenter
    }

    /// エリア名 → アイコン仕様(freeArea 含む)
    public static func iconSpec(for areaName: String) -> IconSpec? {
        switch areaName {
        case "full": return .slot(slots: 1, index: 1, span: 1, vertical: false)
        case "freeArea": return .free

        case "halfLeft": return .slot(slots: 2, index: 1, span: 1, vertical: false)
        case "halfHorizontalCenter": return .slot(slots: 4, index: 2, span: 2, vertical: false)
        case "halfRight": return .slot(slots: 2, index: 2, span: 1, vertical: false)
        case "halfTop": return .slot(slots: 2, index: 1, span: 1, vertical: true)
        case "halfVerticalCenter": return .slot(slots: 4, index: 2, span: 2, vertical: true)
        case "halfBottom": return .slot(slots: 2, index: 2, span: 1, vertical: true)

        case "thirdLeft": return .slot(slots: 3, index: 1, span: 1, vertical: false)
        case "thirdHorizontalCenter": return .slot(slots: 3, index: 2, span: 1, vertical: false)
        case "thirdRight": return .slot(slots: 3, index: 3, span: 1, vertical: false)
        case "thirdTop": return .slot(slots: 3, index: 1, span: 1, vertical: true)
        case "thirdVerticalCenter": return .slot(slots: 3, index: 2, span: 1, vertical: true)
        case "thirdBottom": return .slot(slots: 3, index: 3, span: 1, vertical: true)

        case "quarterLeft": return .slot(slots: 4, index: 1, span: 1, vertical: false)
        case "quarterHorizontalLeftCenter": return .slot(slots: 4, index: 2, span: 1, vertical: false)
        case "quarterHorizontalRightCenter": return .slot(slots: 4, index: 3, span: 1, vertical: false)
        case "quarterRight": return .slot(slots: 4, index: 4, span: 1, vertical: false)
        case "quarterTop": return .slot(slots: 4, index: 1, span: 1, vertical: true)
        case "quarterVerticalTopCenter": return .slot(slots: 4, index: 2, span: 1, vertical: true)
        case "quarterVerticalBottomCenter": return .slot(slots: 4, index: 3, span: 1, vertical: true)
        case "quarterBottom": return .slot(slots: 4, index: 4, span: 1, vertical: true)

        case "quarterTopLeft": return .grid(cols: 2, rows: 2, col: 1, row: 1)
        case "quarterTopRight": return .grid(cols: 2, rows: 2, col: 2, row: 1)
        case "quarterBottomLeft": return .grid(cols: 2, rows: 2, col: 1, row: 2)
        case "quarterBottomRight": return .grid(cols: 2, rows: 2, col: 2, row: 2)

        case "sixthLeft": return .slot(slots: 6, index: 1, span: 1, vertical: false)
        case "sixthRight": return .slot(slots: 6, index: 6, span: 1, vertical: false)
        case "sixthTopLeft": return .grid(cols: 3, rows: 2, col: 1, row: 1)
        case "sixthTopCenter": return .grid(cols: 3, rows: 2, col: 2, row: 1)
        case "sixthTopRight": return .grid(cols: 3, rows: 2, col: 3, row: 1)
        case "sixthBottomLeft": return .grid(cols: 3, rows: 2, col: 1, row: 2)
        case "sixthBottomCenter": return .grid(cols: 3, rows: 2, col: 2, row: 2)
        case "sixthBottomRight": return .grid(cols: 3, rows: 2, col: 3, row: 2)

        case "twoThirdsLeft": return .slot(slots: 3, index: 1, span: 2, vertical: false)
        case "twoThirdsHorizontalCenter": return .slot(slots: 6, index: 2, span: 4, vertical: false)
        case "twoThirdsRight": return .slot(slots: 3, index: 2, span: 2, vertical: false)
        case "twoThirdsTop": return .slot(slots: 3, index: 1, span: 2, vertical: true)
        case "twoThirdsVerticalCenter": return .slot(slots: 6, index: 2, span: 4, vertical: true)
        case "twoThirdsBottom": return .slot(slots: 3, index: 2, span: 2, vertical: true)
        case "twoThirdsCenter": return .centeredRatio(2.0 / 3.0)

        case "threeQuartersLeft": return .slot(slots: 4, index: 1, span: 3, vertical: false)
        case "threeQuartersHorizontalCenter": return .slot(slots: 8, index: 2, span: 6, vertical: false)
        case "threeQuartersRight": return .slot(slots: 4, index: 2, span: 3, vertical: false)
        case "threeQuartersTop": return .slot(slots: 4, index: 1, span: 3, vertical: true)
        case "threeQuartersVerticalCenter": return .slot(slots: 8, index: 2, span: 6, vertical: true)
        case "threeQuartersBottom": return .slot(slots: 4, index: 2, span: 3, vertical: true)
        case "threeQuartersCenter": return .centeredRatio(3.0 / 4.0)

        default:
            if AreaSpec.parseFixedSizeCenter(areaName) != nil {
                return .fixedSizeCenter
            }
            return nil
        }
    }

    /// ラベル下部の補足テキスト(freeArea="Free"、"1280x720Center"→"1280x720")
    public static func detailLabel(for areaName: String) -> String? {
        if areaName == "freeArea" { return "Free" }
        if AreaSpec.parseFixedSizeCenter(areaName) != nil {
            return String(areaName.dropLast("Center".count))
        }
        return nil
    }

    /// キー文字ボックスの幅(実測テキスト幅 + パディング6、最小30、切り上げ)
    public static func keyBoxWidth(measuredTextWidth: CGFloat) -> CGFloat {
        (max(30, measuredTextWidth + 6)).rounded(.up)
    }

    /// detail テキストの幅(元 areaDetailTextWidth: max(64, 文字数*8))
    public static func detailTextWidth(_ text: String) -> CGFloat {
        max(64, CGFloat(text.count) * 8)
    }

    /// ラベルボックスのサイズ(幅 = 9 + キー幅 + 5 + アイコン38 + 10)
    public static func labelSize(keyBoxWidth: CGFloat, detailLabel: String?) -> CGSize {
        var width = 9 + keyBoxWidth + 5 + iconWidth + 10
        if let detailLabel {
            width = max(width, detailTextWidth(detailLabel) + 12)
        }
        let height = detailLabel != nil ? labelHeightWithDetail : labelHeight
        return CGSize(width: width, height: height)
    }

    /// 配置対象
    public struct Candidate {
        public var key: String
        public var areaName: String
        /// エリアの矩形(freeArea は画面全体)
        public var areaFrame: CGRect
        public var labelSize: CGSize
        /// freeArea の右上固定フラグ
        public var fixedTopRight: Bool

        public init(
            key: String, areaName: String, areaFrame: CGRect,
            labelSize: CGSize, fixedTopRight: Bool = false
        ) {
            self.key = key
            self.areaName = areaName
            self.areaFrame = areaFrame
            self.labelSize = labelSize
            self.fixedTopRight = fixedTopRight
        }
    }

    /// 全幅・横分割系エリアの種別ごとの初期縦オフセット(元 labelOffsetYByKind)。
    /// 左端で水平中央が重なる full/half/third/quarter を最初から縦にずらしておく
    static func offsetY(forAreaName name: String) -> CGFloat {
        guard let kind = AreaSpec.kind(of: name) else { return 0 }
        switch kind {
        case .full: return -72
        case .half: return -28
        case .third: return 28
        case .quarter: return 52
        case .sixth: return 64
        case .freeArea, .fixedSizeCenter: return 72
        case .twoThirds, .threeQuarters: return 0
        }
    }

    /// 初期位置(元 areaLabelFrameForCandidate)。絶対座標(top-left)
    static func initialLabelFrame(_ candidate: Candidate, screenFrame: CGRect) -> CGRect {
        let size = candidate.labelSize
        let frame = candidate.areaFrame

        if candidate.fixedTopRight {
            return CGRect(
                x: frame.maxX - size.width - minMargin,
                y: frame.minY + minMargin,
                width: size.width, height: size.height)
        }

        let labelX = frame.minX + (frame.width - size.width) / 2
        var areaCenter: CGFloat?
        switch iconSpec(for: candidate.areaName) {
        case .grid(_, let rows, _, let row):
            areaCenter = (CGFloat(row) - 0.5) / CGFloat(rows)
        case .slot(let slots, let index, let span, true):
            if span > 1 {
                areaCenter = (CGFloat(index) - 1 + CGFloat(span) / 2) / CGFloat(slots)
            } else {
                areaCenter = (CGFloat(index) - 0.5) / CGFloat(slots)
            }
        default:
            areaCenter = nil
        }

        var labelY: CGFloat
        if let areaCenter {
            labelY = frame.minY + (frame.height - size.height) * areaCenter
        } else {
            labelY =
                frame.minY + (frame.height - size.height) / 2
                + offsetY(forAreaName: candidate.areaName)
        }
        labelY = max(
            frame.minY + minMargin,
            min(frame.maxY - size.height - minMargin, labelY))
        return CGRect(x: labelX, y: labelY, width: size.width, height: size.height)
    }

    static func overlapsHorizontally(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX
    }

    /// 初期配置 → 水平重なりグループ内で縦スタック(元 resolveAreaLabelFrames)。
    /// 返り値は candidates と同じ順序のラベル絶対 frame
    public static func resolveLabelFrames(
        candidates: [Candidate], screenFrame: CGRect
    ) -> [CGRect] {
        var frames = candidates.map { initialLabelFrame($0, screenFrame: screenFrame) }

        // 右上固定(freeArea)はスタック対象外
        let stackable = candidates.indices.filter { !candidates[$0].fixedTopRight }

        // 水平方向に重なるラベルを推移的にグループ化
        var groups: [[Int]] = []
        for index in stackable {
            var mergedGroup = [index]
            var remaining: [[Int]] = []
            for group in groups {
                let overlaps = group.contains { other in
                    overlapsHorizontally(frames[other], frames[index])
                        || mergedGroup.contains { mine in
                            overlapsHorizontally(frames[other], frames[mine])
                        }
                }
                if overlaps {
                    mergedGroup.append(contentsOf: group)
                } else {
                    remaining.append(group)
                }
            }
            remaining.append(mergedGroup)
            groups = remaining
        }

        let minTop = screenFrame.minY + minMargin
        let maxBottom = screenFrame.maxY - minMargin

        for group in groups where group.count > 1 {
            // y → x → key 順で上から積む
            let sorted = group.sorted { a, b in
                if frames[a].minY != frames[b].minY { return frames[a].minY < frames[b].minY }
                if frames[a].minX != frames[b].minX { return frames[a].minX < frames[b].minX }
                return candidates[a].key < candidates[b].key
            }
            var nextY = -CGFloat.greatestFiniteMagnitude
            for index in sorted {
                var frame = frames[index]
                frame.origin.y = max(frame.origin.y, nextY)
                frames[index] = frame
                nextY = frame.maxY + gap
            }
            // 画面下端をはみ出したら、上の余白の範囲でグループ全体を上へシフト
            guard let last = sorted.last, let first = sorted.first else { continue }
            let overflow = frames[last].maxY - maxBottom
            if overflow > 0 {
                let headroom = frames[first].minY - minTop
                let shift = min(overflow, max(0, headroom))
                if shift > 0 {
                    for index in sorted {
                        frames[index].origin.y -= shift
                    }
                }
            }
        }

        return frames
    }
}
