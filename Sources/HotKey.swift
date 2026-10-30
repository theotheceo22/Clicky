import Carbon

/// A system-wide keyboard shortcut (works even when Clicky isn't focused).
/// Carbon delivers hot key events on the main thread.
final class HotKey {
    private static var nextID: UInt32 = 1

    private let id: UInt32
    private let action: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        self.id = HotKey.nextID
        HotKey.nextID += 1
        self.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(event,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hkID)
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            guard err == OSStatus(noErr), hkID.id == me.id else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { me.action() }
            return OSStatus(noErr)
        }, 1, &spec, selfPtr, &handlerRef)

        let hkID = EventHotKeyID(signature: OSType(0x434C4B59), id: id) // 'CLKY'
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
