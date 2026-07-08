import CoreGraphics
import Testing

@testable import JinraiCore

@Suite("WindowRelocation")
struct WindowRelocationTests {
    /// ターゲットディスプレイ(プライマリ想定): 1920x1080、メニューバー分 y=25
    let target = CGRect(x: 0, y: 25, width: 1920, height: 1055)
    /// 出現元ディスプレイ(右隣想定)
    let source = CGRect(x: 1920, y: 25, width: 1920, height: 1055)

    @Test("完全にターゲット内なら移動しない")
    func fullyInsideTarget() {
        let window = CGRect(x: 100, y: 100, width: 800, height: 600)
        #expect(
            WindowRelocation.relocatedFrame(
                window: window, targetVisibleFrame: target, sourceVisibleFrame: target) == nil)
    }

    @Test("ちょうど50%重なっていれば移動しない")
    func exactlyHalfOverlap() {
        // 幅800のうち400がターゲット内(x: 1520〜1920)
        let window = CGRect(x: 1520, y: 100, width: 800, height: 600)
        #expect(
            WindowRelocation.relocatedFrame(
                window: window, targetVisibleFrame: target, sourceVisibleFrame: source) == nil)
    }

    @Test("重なりが50%未満なら移動する")
    func lessThanHalfOverlap() {
        // 幅800のうち399がターゲット内
        let window = CGRect(x: 1521, y: 100, width: 800, height: 600)
        #expect(
            WindowRelocation.relocatedFrame(
                window: window, targetVisibleFrame: target, sourceVisibleFrame: source) != nil)
    }

    @Test("別ディスプレイの中央に出現したらターゲット中央へ(相対位置維持)")
    func centerToCenter() {
        // source の余白中央: x = 1920 + (1920-800)/2 = 2480, y = 25 + (1055-600)/2 = 252.5
        let window = CGRect(x: 2480, y: 252.5, width: 800, height: 600)
        let result = WindowRelocation.relocatedFrame(
            window: window, targetVisibleFrame: target, sourceVisibleFrame: source)
        #expect(result == CGRect(x: 560, y: 252.5, width: 800, height: 600))
    }

    @Test("source の左上端に張り付いていたら target の左上端へ")
    func topLeftToTopLeft() {
        let window = CGRect(x: 1920, y: 25, width: 800, height: 600)
        let result = WindowRelocation.relocatedFrame(
            window: window, targetVisibleFrame: target, sourceVisibleFrame: source)
        #expect(result == CGRect(x: 0, y: 25, width: 800, height: 600))
    }

    @Test("source の右下端に張り付いていたら target の右下端へ")
    func bottomRightToBottomRight() {
        let window = CGRect(x: 3040, y: 480, width: 800, height: 600)
        let result = WindowRelocation.relocatedFrame(
            window: window, targetVisibleFrame: target, sourceVisibleFrame: source)
        #expect(result == CGRect(x: 1120, y: 480, width: 800, height: 600))
    }

    @Test("sourceVisibleFrame が nil ならクランプのみ")
    func clampOnlyWithoutSource() {
        let window = CGRect(x: 2480, y: 300, width: 800, height: 600)
        let result = WindowRelocation.relocatedFrame(
            window: window, targetVisibleFrame: target, sourceVisibleFrame: nil)
        // x はターゲット右端へクランプ、y はそのまま
        #expect(result == CGRect(x: 1120, y: 300, width: 800, height: 600))
    }

    @Test("ウィンドウが source より大きい軸は比率0(左/上端)扱い")
    func widerThanSource() {
        let window = CGRect(x: 1800, y: 252.5, width: 2000, height: 600)
        let result = WindowRelocation.relocatedFrame(
            window: window, targetVisibleFrame: target, sourceVisibleFrame: source)
        // x: 比率0 → target.minX(target 幅 1920 内には収まらないので左端揃え)
        // y: source の余白中央 → target の余白中央
        #expect(result == CGRect(x: 0, y: 252.5, width: 2000, height: 600))
    }

    @Test("ウィンドウが target より大きければ top-left 揃え・サイズ不変")
    func largerThanTarget() {
        let window = CGRect(x: 2000, y: 100, width: 2500, height: 1500)
        let result = WindowRelocation.relocatedFrame(
            window: window, targetVisibleFrame: target, sourceVisibleFrame: source)
        #expect(result == CGRect(x: 0, y: 25, width: 2500, height: 1500))
    }

    @Test("重なり50%未満でも移動後の frame が元と同じなら nil")
    func noopRelocation() {
        // ターゲットより縦に大きく下へはみ出すウィンドウ(重なり 1055/3000 ≈ 35%)。
        // クランプすると top-left 揃えで元位置と一致するため移動不要
        let window = CGRect(x: 100, y: 25, width: 800, height: 3000)
        #expect(
            WindowRelocation.relocatedFrame(
                window: window, targetVisibleFrame: target, sourceVisibleFrame: nil) == nil)
    }

    @Test("不正な frame(幅・高さが0以下)なら nil")
    func invalidFrame() {
        let window = CGRect(x: 100, y: 100, width: 0, height: 600)
        #expect(
            WindowRelocation.relocatedFrame(
                window: window, targetVisibleFrame: target, sourceVisibleFrame: source) == nil)
    }
}
