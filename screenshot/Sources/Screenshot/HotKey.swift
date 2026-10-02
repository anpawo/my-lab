import AppKit
import Carbon.HIToolbox

// A plain global: the Carbon callback is a C function pointer and cannot capture anything.
private nonisolated(unsafe) var hotKeyActions: [UInt32: @Sendable () -> Void] = [:]
private nonisolated(unsafe) var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]

/// Carbon `RegisterEventHotKey`: no Accessibility prompt, and the chord is swallowed before the
/// frontmost app sees it. The system's own ⌘⇧5 must be off in Keyboard settings or both fire.
@MainActor
enum HotKey {
    private static var handler: EventHandlerRef?

    @discardableResult
    static func register(key: Int, modifiers: Int, id: UInt32, action: @escaping @Sendable () -> Void) -> Bool {
        guard installHandler() else { return false }
        hotKeyActions[id] = action
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(key), UInt32(modifiers),
                                         EventHotKeyID(signature: OSType(0x5348_4F54), id: id),
                                         GetEventDispatcherTarget(), 0, &ref)
        if status != noErr { NSLog("screenshot: hotkey refused (\(status)) — taken by another app?") }
        if let ref { hotKeyRefs[id] = ref }
        return status == noErr
    }

    static func unregister(id: UInt32) {
        if let ref = hotKeyRefs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        hotKeyActions[id] = nil
    }

    private static func installHandler() -> Bool {
        guard handler == nil else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        return InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let fired = id.id
            DispatchQueue.main.async { hotKeyActions[fired]?() }
            return noErr
        }, 1, &spec, nil, &handler) == noErr
    }
}
