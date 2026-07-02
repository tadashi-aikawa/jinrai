import Foundation

/// ヒントキーの逐次入力マッチ(元 window_hints.lua の handleChar)
public enum HintInputMatcher {
    public enum Result: Equatable, Sendable {
        /// 完全一致 → ウィンドウ選択
        case selected(String)
        /// 接頭辞一致 → 入力継続(候補のハイライト更新)
        case partial(String)
        /// 一致なし → 入力リセット
        case reset
    }

    /// 現在の入力に1文字追加した結果を判定する。
    /// 完全一致 → 接頭辞一致 → 最後の1文字での再試行 → リセット の順。
    public static func advance(
        currentInput: String, char: String, keys: some Collection<String>
    ) -> Result {
        let input = currentInput + char.uppercased()
        if let matched = exactMatch(input, keys) {
            return .selected(matched)
        }
        if hasPrefixMatch(input, keys) {
            return .partial(input)
        }
        // 入力が迷子になったら最後の1文字からやり直す
        let retry = char.uppercased()
        if retry != input {
            if let matched = exactMatch(retry, keys) {
                return .selected(matched)
            }
            if hasPrefixMatch(retry, keys) {
                return .partial(retry)
            }
        }
        return .reset
    }

    /// Backspace: 1文字戻した入力を返す
    public static func backspace(currentInput: String) -> String {
        String(currentInput.dropLast())
    }

    static func exactMatch(_ input: String, _ keys: some Collection<String>) -> String? {
        keys.first { $0 == input }
    }

    static func hasPrefixMatch(_ input: String, _ keys: some Collection<String>) -> Bool {
        keys.contains { $0.hasPrefix(input) && $0 != input }
    }
}
