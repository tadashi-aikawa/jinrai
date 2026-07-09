import AppKit
import Carbon.HIToolbox

/// モーダル入力捕捉(元 hs.eventtap)。
/// ヒント表示中のみ start し、キー入力を捕捉・消費する。
///
/// 1つのインスタンスをモーダル系機能(Window Hints / Area Hints 等)で共有する前提。
/// stop() は tap を即時破棄せず次の run loop turn まで遅延し、その間のキーを握りつぶす。
/// tap を破棄してから次の tap を作るまでの間は WindowServer がキーを前面アプリへ直接
/// 配送するため、機能間の遷移(close → open が同期実行)中のキーリピートが
/// 背面アプリへすり抜けてしまう。遷移先の start() が破棄予約を取り消すことで
/// タップを途切れさせない。
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

    /// stop() 済みで破棄待ちの状態(この間の keyDown はすり抜け防止のため消費する)
    private var isPendingStop = false
    /// 遅延破棄の予約を識別する世代番号(start() が予約を無効化するために進める)
    private var stopGeneration = 0

    /// postKeyStroke が投稿するイベントの目印(eventSourceUserData)。
    /// tap を止める前に投稿を待つ必要をなくすため、自前イベントは捕捉せず素通しする
    private static let selfPostedMarker: Int64 = 0x4A4E_5241_49

    private final class ResultBox {
        var value: Unmanaged<CGEvent>?
    }

    public init() {}

    public var isRunning: Bool { tap != nil }

    /// tap の作成に失敗したら false(権限不足・セキュア入力中)。
    /// stop() 直後(破棄待ち)の呼び出しは予約を取り消して既存の tap を継続利用する
    @discardableResult
    public func start() -> Bool {
        if tap != nil {
            isPendingStop = false
            stopGeneration += 1
            return true
        }
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

    /// ハンドラを外してキー消費モードへ移行し、tap 本体の破棄は次の run loop turn へ遅延する。
    /// 機能間の遷移では遷移先の start() が同一 turn 内で予約を取り消すため tap が途切れない
    public func stop() {
        guard tap != nil else { return }
        onKeyDown = nil
        onLeftMouseDown = nil
        isPendingStop = true
        stopGeneration += 1
        let generation = stopGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isPendingStop, self.stopGeneration == generation else {
                return
            }
            self.teardown()
        }
    }

    private func teardown() {
        isPendingStop = false
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
            // 自前投稿(Space 移動の Ctrl+数字等)は捕捉対象外。tap が生きたまま
            // 投稿しても自分で消費しないようマーカーで素通しする
            if event.getIntegerValueField(.eventSourceUserData) == Self.selfPostedMarker {
                return Unmanaged.passUnretained(event)
            }
            // 破棄待ち(機能間の遷移中)のキーは背面アプリへのすり抜け防止のため消費
            if isPendingStop {
                return nil
            }
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
        down.setIntegerValueField(.eventSourceUserData, value: selfPostedMarker)
        up.setIntegerValueField(.eventSourceUserData, value: selfPostedMarker)
        return (down, up)
    }
}
