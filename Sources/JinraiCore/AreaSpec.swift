import CoreGraphics
import Foundation

/// 固定エリアの幾何(元 window_mover.lua の areaSpecForName)。
/// エリア名 → スクリーン作業領域上の frame。freeArea は動的なため FreeArea を使う。
public enum AreaSpec {
    /// エリアの種類(エリア選択画面の色分け用)
    public enum Kind: String, Sendable {
        case full, freeArea, fixedSizeCenter
        case half, third, quarter, sixth, twoThirds, threeQuarters
    }

    public static func kind(of name: String) -> Kind? {
        if name == "full" { return .full }
        if name == "freeArea" { return .freeArea }
        if parseFixedSizeCenter(name) != nil { return .fixedSizeCenter }
        if name.hasPrefix("half") { return .half }
        if name.hasPrefix("third") { return .third }
        if name.hasPrefix("quarter") { return .quarter }
        if name.hasPrefix("sixth") { return .sixth }
        if name.hasPrefix("twoThirds") { return .twoThirds }
        if name.hasPrefix("threeQuarters") { return .threeQuarters }
        return nil
    }

    /// "1920x1080Center" → (width, height)
    public static func parseFixedSizeCenter(_ name: String) -> (
        width: CGFloat, height: CGFloat
    )? {
        guard name.hasSuffix("Center") else { return nil }
        let body = String(name.dropLast("Center".count))
        let parts = body.split(separator: "x")
        guard parts.count == 2,
            let width = Double(parts[0]), let height = Double(parts[1]),
            width > 0, height > 0
        else { return nil }
        return (CGFloat(width), CGFloat(height))
    }

    /// エリア名 → frame。未知の名前は nil(freeArea も nil: 呼び出し側で FreeArea を使う)
    public static func frame(for name: String, screenFrame f: CGRect) -> CGRect? {
        // 横ストリップ(高さ全体): 幅比率とX位置比率
        func hStrip(_ widthRatio: CGFloat, _ xRatio: CGFloat) -> CGRect {
            CGRect(
                x: f.minX + f.width * xRatio, y: f.minY,
                width: f.width * widthRatio, height: f.height)
        }
        // 縦ストリップ(幅全体)
        func vStrip(_ heightRatio: CGFloat, _ yRatio: CGFloat) -> CGRect {
            CGRect(
                x: f.minX, y: f.minY + f.height * yRatio,
                width: f.width, height: f.height * heightRatio)
        }
        // グリッドセル
        func cell(
            _ widthRatio: CGFloat, _ heightRatio: CGFloat, _ xRatio: CGFloat, _ yRatio: CGFloat
        ) -> CGRect {
            CGRect(
                x: f.minX + f.width * xRatio, y: f.minY + f.height * yRatio,
                width: f.width * widthRatio, height: f.height * heightRatio)
        }

        switch name {
        case "full":
            return f

        // 2分割
        case "halfLeft": return hStrip(1 / 2, 0)
        case "halfHorizontalCenter": return hStrip(1 / 2, 1 / 4)
        case "halfRight": return hStrip(1 / 2, 1 / 2)
        case "halfTop": return vStrip(1 / 2, 0)
        case "halfVerticalCenter": return vStrip(1 / 2, 1 / 4)
        case "halfBottom": return vStrip(1 / 2, 1 / 2)

        // 3分割
        case "thirdLeft": return hStrip(1 / 3, 0)
        case "thirdHorizontalCenter": return hStrip(1 / 3, 1 / 3)
        case "thirdRight": return hStrip(1 / 3, 2 / 3)
        case "thirdTop": return vStrip(1 / 3, 0)
        case "thirdVerticalCenter": return vStrip(1 / 3, 1 / 3)
        case "thirdBottom": return vStrip(1 / 3, 2 / 3)

        // 4分割(ストリップ)
        case "quarterLeft": return hStrip(1 / 4, 0)
        case "quarterHorizontalLeftCenter": return hStrip(1 / 4, 1 / 4)
        case "quarterHorizontalRightCenter": return hStrip(1 / 4, 1 / 2)
        case "quarterRight": return hStrip(1 / 4, 3 / 4)
        case "quarterTop": return vStrip(1 / 4, 0)
        case "quarterVerticalTopCenter": return vStrip(1 / 4, 1 / 4)
        case "quarterVerticalBottomCenter": return vStrip(1 / 4, 1 / 2)
        case "quarterBottom": return vStrip(1 / 4, 3 / 4)

        // 4分割(四隅)
        case "quarterTopLeft": return cell(1 / 2, 1 / 2, 0, 0)
        case "quarterTopRight": return cell(1 / 2, 1 / 2, 1 / 2, 0)
        case "quarterBottomLeft": return cell(1 / 2, 1 / 2, 0, 1 / 2)
        case "quarterBottomRight": return cell(1 / 2, 1 / 2, 1 / 2, 1 / 2)

        // 6分割(3列×2行)
        case "sixthTopLeft": return cell(1 / 3, 1 / 2, 0, 0)
        case "sixthTopCenter": return cell(1 / 3, 1 / 2, 1 / 3, 0)
        case "sixthTopRight": return cell(1 / 3, 1 / 2, 2 / 3, 0)
        case "sixthBottomLeft": return cell(1 / 3, 1 / 2, 0, 1 / 2)
        case "sixthBottomCenter": return cell(1 / 3, 1 / 2, 1 / 3, 1 / 2)
        case "sixthBottomRight": return cell(1 / 3, 1 / 2, 2 / 3, 1 / 2)

        // 3分の2
        case "twoThirdsLeft": return hStrip(2 / 3, 0)
        case "twoThirdsHorizontalCenter": return hStrip(2 / 3, 1 / 6)
        case "twoThirdsRight": return hStrip(2 / 3, 1 / 3)
        case "twoThirdsTop": return vStrip(2 / 3, 0)
        case "twoThirdsVerticalCenter": return vStrip(2 / 3, 1 / 6)
        case "twoThirdsBottom": return vStrip(2 / 3, 1 / 3)
        case "twoThirdsCenter": return cell(2 / 3, 2 / 3, 1 / 6, 1 / 6)

        // 4分の3
        case "threeQuartersLeft": return hStrip(3 / 4, 0)
        case "threeQuartersHorizontalCenter": return hStrip(3 / 4, 1 / 8)
        case "threeQuartersRight": return hStrip(3 / 4, 1 / 4)
        case "threeQuartersTop": return vStrip(3 / 4, 0)
        case "threeQuartersVerticalCenter": return vStrip(3 / 4, 1 / 8)
        case "threeQuartersBottom": return vStrip(3 / 4, 1 / 4)
        case "threeQuartersCenter": return cell(3 / 4, 3 / 4, 1 / 8, 1 / 8)

        default:
            // 固定サイズ中央("1920x1080Center")。ディスプレイ内に収まるよう調整
            if let size = parseFixedSizeCenter(name) {
                let width = min(size.width, f.width)
                let height = min(size.height, f.height)
                return CGRect(
                    x: f.minX + (f.width - width) / 2,
                    y: f.minY + (f.height - height) / 2,
                    width: width, height: height)
            }
            return nil
        }
    }
}
