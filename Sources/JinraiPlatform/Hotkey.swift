import AppKit
import Carbon.HIToolbox

/// グローバルホットキー(元 hs.hotkey.bind 相当)。Carbon RegisterEventHotKey を使用。
@MainActor
public final class Hotkey {
    private static var nextID: UInt32 = 1
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var eventHandlerInstalled = false

    private let hotKeyID: UInt32
    private var hotKeyRef: EventHotKeyRef?

    /// key はキー名("w", "f20" 等)。解決できなければ nil を返す
    public convenience init?(modifiers: [String], key: String, handler: @escaping () -> Void) {
        guard let keyCode = KeyCodes.keyCode(for: key) else { return nil }
        self.init(
            keyCode: keyCode,
            carbonModifiers: KeyCodes.carbonModifiers(for: modifiers),
            handler: handler)
    }

    public init?(keyCode: UInt32, carbonModifiers: UInt32, handler: @escaping () -> Void) {
        Self.installEventHandlerIfNeeded()
        hotKeyID = Self.nextID
        Self.nextID += 1

        var ref: EventHotKeyRef?
        let eventHotKeyID = EventHotKeyID(
            signature: OSType(0x4A4E_5249),  // "JNRI"
            id: hotKeyID)
        let status = RegisterEventHotKey(
            keyCode, carbonModifiers, eventHotKeyID,
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        hotKeyRef = ref
        Self.handlers[hotKeyID] = handler
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        Self.handlers[hotKeyID] = nil
    }

    /// モーダル(ヒント表示)中はホットキーを一時停止し eventtap に一本化する
    public var isEnabled: Bool {
        get { hotKeyRef != nil }
        set {
            // Carbon には enable/disable がないため登録解除で代替(再登録は不要な設計とする)
            if !newValue { unregister() }
        }
    }

    private static func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                let id = hotKeyID.id
                Task { @MainActor in
                    Hotkey.handlers[id]?()
                }
                return noErr
            },
            1, &eventType, nil, nil)
    }
}
