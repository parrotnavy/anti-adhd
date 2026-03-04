import Carbon
import Foundation

final class HotKeyManager {
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private let signature: OSType = 0x41444844 // 'ADHD'
    private var handlerInstalled = false

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handle(event: event)
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        handlerInstalled = (status == noErr)
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(actionID: UInt32, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        guard handlerInstalled else {
            return false
        }

        unregister(actionID: actionID)

        let hotKeyID = EventHotKeyID(signature: signature, id: actionID)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return false
        }

        hotKeyRefs[actionID] = hotKeyRef
        handlers[actionID] = handler
        return true
    }

    func unregister(actionID: UInt32) {
        if let ref = hotKeyRefs[actionID] {
            UnregisterEventHotKey(ref)
        }

        hotKeyRefs.removeValue(forKey: actionID)
        handlers.removeValue(forKey: actionID)
    }

    func unregisterAll() {
        for (actionID, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
            handlers.removeValue(forKey: actionID)
        }
        hotKeyRefs.removeAll()
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard hotKeyID.signature == signature else {
            return OSStatus(eventNotHandledErr)
        }

        handlers[hotKeyID.id]?()
        return noErr
    }
}
