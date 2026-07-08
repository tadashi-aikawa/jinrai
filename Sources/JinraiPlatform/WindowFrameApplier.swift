import AppKit

/// ウィンドウへの frame 適用エンジン(元 WindowMoverFeature.apply)。
/// ネイティブフルスクリーン中の解除待ちを含むため、Window Mover と Window Layouts で共有する。
@MainActor
public enum WindowFrameApplier {
    /// frame を適用する。フルスクリーン中は解除完了を待ってから適用する。
    /// completion には適用できたかが渡る(フルスクリーン解除待ちを含むため非同期のことがある)
    public static func apply(
        frame: CGRect, to window: AXWindow, moveCursor: Bool,
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        // ネイティブフルスクリーン中は位置・サイズを変更できないため、
        // 解除して(アニメーション完了を待って)から適用する
        if window.isFullScreen {
            window.setFullScreen(false)
            waitForFullScreenExit(of: window, retries: 20) { exited in
                guard exited else {
                    NSLog("[jinrai] フルスクリーン解除を待ちきれませんでした")
                    completion?(false)
                    return
                }
                // AXFullScreen が false になった直後はまだ遷移中のことがあるため少し待つ
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    applyDirectly(frame: frame, to: window, moveCursor: moveCursor)
                    completion?(true)
                }
            }
            return
        }
        applyDirectly(frame: frame, to: window, moveCursor: moveCursor)
        completion?(true)
    }

    private static func applyDirectly(frame: CGRect, to window: AXWindow, moveCursor: Bool) {
        window.setFrame(frame)
        if moveCursor {
            Mouse.moveToCenter(of: window.frame ?? frame)
        }
    }

    /// フルスクリーン解除アニメーションの完了を 100ms 間隔でポーリングして待つ
    private static func waitForFullScreenExit(
        of window: AXWindow, retries: Int, completion: @escaping @MainActor (Bool) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !window.isFullScreen {
                completion(true)
            } else if retries > 0 {
                waitForFullScreenExit(of: window, retries: retries - 1, completion: completion)
            } else {
                completion(false)
            }
        }
    }
}
