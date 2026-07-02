import AppKit
import Carbon.HIToolbox

/// モーダル入力捕捉(元 hs.eventtap)。
/// ヒント表示中のみ start し、キー入力を捕捉・消費する。
@MainActor
public final class EventTap {
    public struct KeyEvent: Sendable {
        public var keyCode: UInt32
        public var character: String?
        public var flags: CGEventFlags
    }

    /// true を返すとイベントを消費する
    public var onKeyDown: ((KeyEvent) -> Bool)?
    /// クリック位置(top-left 座標)。true を返すと消費
    public var onLeftMouseDown: ((CGPoint) -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private final class ResultBox {
        var value: Unmanaged<CGEvent>?
    }

    public init() {}

    public var isRunning: Bool { tap != nil }

    /// tap の作成に失敗したら false(権限不足・セキュア入力中)
    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    guard let refcon else { return Unmanaged.passUnretained(event) }
                    let this = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                    // tap は main run loop に登録しているためコールバックは MainActor 上。
                    // assumeIsolated は Sendable 戻り値を要求するため Box 経由で受け渡す
                    let box = ResultBox()
                    MainActor.assumeIsolated {
                        box.value = this.handle(type: type, event: event)
                    }
                    return box.value
                },
                userInfo: refcon
            )
        else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let keyEvent = KeyEvent(
                keyCode: keyCode,
                character: KeyCodes.character(for: keyCode),
                flags: event.flags
            )
            if onKeyDown?(keyEvent) == true {
                return nil  // 消費
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            if onLeftMouseDown?(event.location) == true {
                return nil
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// キーストロークをシステム全体へ送出する(元 hs.eventtap.keyStroke)。
    /// Mission Control のショートカット送出などに使う
    public static func postKeyStroke(modifiers: [String], key: String) {
        guard let (down, up) = makeKeyEvents(modifiers: modifiers, key: key) else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// キーストロークを特定アプリの pid へ直接送る(元 hs.eventtap.keyStroke(..., app))。
    /// 自身の session tap を経由しないため、モーダル中でも消費されずに対象へ届く
    public static func postKeyStroke(modifiers: [String], key: String, toPid pid: pid_t) {
        guard let (down, up) = makeKeyEvents(modifiers: modifiers, key: key) else { return }
        down.postToPid(pid)
        up.postToPid(pid)
    }

    private static func makeKeyEvents(
        modifiers: [String], key: String
    ) -> (down: CGEvent, up: CGEvent)? {
        guard let keyCode = KeyCodes.keyCode(for: key) else { return nil }
        let flags = KeyCodes.cgEventFlags(for: modifiers)
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
            let up = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        else { return nil }
        down.flags = flags
        up.flags = flags
        return (down, up)
    }
}
