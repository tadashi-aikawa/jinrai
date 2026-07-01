import Foundation

/// JSONC(コメント・末尾カンマ付き JSON)を素の JSON に変換する前処理
public enum JSONC {
    /// 文字列リテラル内を保護しつつ、// と /* */ のコメントと末尾カンマを除去する
    public static func strip(_ text: String) -> String {
        var result = [Character]()
        result.reserveCapacity(text.count)
        let chars = Array(text)
        var i = 0
        var inString = false

        while i < chars.count {
            let c = chars[i]
            if inString {
                result.append(c)
                if c == "\\", i + 1 < chars.count {
                    result.append(chars[i + 1])
                    i += 2
                    continue
                }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" {
                inString = true
                result.append(c)
                i += 1
                continue
            }
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                while i < chars.count, chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                i += 2
                while i + 1 < chars.count, !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                i = min(i + 2, chars.count)
                continue
            }
            if c == "," {
                // 末尾カンマ: 次の非空白文字が } か ] ならカンマを捨てる
                var j = i + 1
                while j < chars.count, chars[j].isWhitespace { j += 1 }
                if j < chars.count, chars[j] == "}" || chars[j] == "]" {
                    i += 1
                    continue
                }
            }
            result.append(c)
            i += 1
        }
        return String(result)
    }

    /// JSONC テキストを [String: Any] にパースする
    public static func parseObject(_ text: String) throws -> [String: Any] {
        let stripped = strip(text)
        let data = Data(stripped.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw ConfigError("設定のトップレベルは JSON オブジェクトである必要があります")
        }
        return dict
    }
}
