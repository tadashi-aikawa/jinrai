import Carbon.HIToolbox
import Foundation

/// キー名 ⇔ キーコード変換(元 hs.keycodes 相当)。
/// 文字キーは現在のキーボードレイアウトから UCKeyTranslate で逆引きする。
public enum KeyCodes {
    /// レイアウト非依存の特殊キー名 → キーコード
    static let specialKeys: [String: UInt32] = [
        "return": UInt32(kVK_Return), "enter": UInt32(kVK_Return),
        "tab": UInt32(kVK_Tab),
        "space": UInt32(kVK_Space),
        "delete": UInt32(kVK_Delete), "backspace": UInt32(kVK_Delete),
        "forwarddelete": UInt32(kVK_ForwardDelete),
        "escape": UInt32(kVK_Escape),
        "left": UInt32(kVK_LeftArrow), "right": UInt32(kVK_RightArrow),
        "up": UInt32(kVK_UpArrow), "down": UInt32(kVK_DownArrow),
        "home": UInt32(kVK_Home), "end": UInt32(kVK_End),
        "pageup": UInt32(kVK_PageUp), "pagedown": UInt32(kVK_PageDown),
        "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3),
        "f4": UInt32(kVK_F4), "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6),
        "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8), "f9": UInt32(kVK_F9),
        "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
        "f13": UInt32(kVK_F13), "f14": UInt32(kVK_F14), "f15": UInt32(kVK_F15),
        "f16": UInt32(kVK_F16), "f17": UInt32(kVK_F17), "f18": UInt32(kVK_F18),
        "f19": UInt32(kVK_F19), "f20": UInt32(kVK_F20),
    ]

    /// キーコード → 現レイアウトでの文字(修飾なし)
    public static func character(for keyCode: UInt32) -> String? {
        guard
            let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutDataRef = TISGetInputSourceProperty(
                inputSource, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataRef).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> OSStatus in
            let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,  // 修飾キーなし
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    /// キー名("w", "escape", "f20" 等)→ キーコード
    public static func keyCode(for keyName: String) -> UInt32? {
        let name = keyName.lowercased()
        if let special = specialKeys[name] {
            return special
        }
        // 現レイアウトの文字キーから逆引き
        for code in UInt32(0)..<128 {
            if let char = character(for: code)?.lowercased(), char == name {
                return code
            }
        }
        return nil
    }

    /// 修飾キー名(cmd/alt/option/ctrl/shift)→ Carbon 修飾フラグ
    public static func carbonModifiers(for names: [String]) -> UInt32 {
        var flags: UInt32 = 0
        for name in names {
            switch name.lowercased() {
            case "cmd", "command": flags |= UInt32(cmdKey)
            case "alt", "option": flags |= UInt32(optionKey)
            case "ctrl", "control": flags |= UInt32(controlKey)
            case "shift": flags |= UInt32(shiftKey)
            default: break
            }
        }
        return flags
    }

    /// 修飾キー名 → CGEventFlags(キーストローク送出用)
    public static func cgEventFlags(for names: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for name in names {
            switch name.lowercased() {
            case "cmd", "command": flags.insert(.maskCommand)
            case "alt", "option": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            case "fn": flags.insert(.maskSecondaryFn)
            default: break
            }
        }
        return flags
    }
}
