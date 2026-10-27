import Carbon.HIToolbox

/// A system-wide shortcut, ⌃⌘V, registered with the Carbon hot-key API so the press is consumed
/// instead of reaching the focused app; needs no permission.
final class PasteShortcut {
    private var hotKey: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                Unmanaged<PasteShortcut>.fromOpaque(userData).takeUnretainedValue().action()
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        let id = EventHotKeyID(signature: OSType(0x534E_4657), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V), UInt32(controlKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKey
        )
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
