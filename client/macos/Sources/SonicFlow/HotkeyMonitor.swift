import AppKit
import Carbon
import CoreGraphics
import SonicFlowCore

/// Listens system-wide for the dictation hotkey via a listen-only event tap.
final class HotkeyMonitor {
    /// Times are seconds since boot, comparable with `ProcessInfo.systemUptime`.
    enum Input {
        case hotkeyDown(at: TimeInterval)
        case hotkeyUp(at: TimeInterval)
        case escape
        /// Shift held with the hotkey: edit the selection instead of dictating.
        case command
        /// What interrupted the hotkey, for the log: modifier key codes only, never typed keys.
        case other(String)
    }

    private static let escapeKeyCode: Int64 = 53
    /// Tags the keystrokes SonicFlow posts itself (copy, paste) so they never cancel a dictation.
    static let syntheticMarker: Int64 = 0x534F_4E49_43

    static func post(_ keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource?) {
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = flags
            event?.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            event?.post(tap: .cghidEventTap)
        }
    }

    var hotkey: Hotkey
    /// Every key press and click, for following fixes to a paste; the edit is worked out only if
    /// the receiver asks for it, and is never logged.
    var onEdit: ((() -> EditKey) -> Void)?
    private let handler: (Input) -> Void
    private var tap: CFMachPort?

    init(hotkey: Hotkey, handler: @escaping (Input) -> Void) {
        self.hotkey = hotkey
        self.handler = handler
    }

    func start() -> Bool {
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: hotkeyTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    fileprivate func process(_ type: CGEventType, _ event: CGEvent) {
        guard event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if let onEdit, [.keyDown, .leftMouseDown, .rightMouseDown].contains(type) {
            onEdit { type == .keyDown ? Self.edit(event) : .unsupported }
        }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            onEdit? { .unsupported }
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            let time = NSEvent(cgEvent: event)?.timestamp ?? ProcessInfo.processInfo.systemUptime
            switch hotkey.classify(keyCode: keyCode, flags: event.flags) {
            case .down: handler(.hotkeyDown(at: time))
            case .downCommand:
                handler(.hotkeyDown(at: time))
                handler(.command)
            case .command: handler(.command)
            case .ignored: break
            case .up: handler(.hotkeyUp(at: time))
            case .other: handler(.other("modifier \(keyCode) flags \(event.flags.rawValue)"))
            }
        case .keyDown where keyCode == Self.escapeKeyCode:
            handler(.escape)
        case .keyDown:
            handler(.other("key"))
        default:
            handler(.other("mouse"))
        }
    }
}

extension HotkeyMonitor {
    /// Input methods (Pinyin, Cangjie, Kana) compose text from keys the tap sees raw, so only a
    /// plain keyboard layout's keys can be followed.
    fileprivate static func edit(_ event: CGEvent) -> EditKey {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
            let type = TISGetInputSourceProperty(source, kTISPropertyInputSourceType),
            Unmanaged<CFString>.fromOpaque(type).takeUnretainedValue() == kTISTypeKeyboardLayout
        else { return .unsupported }
        var buffer = [UniChar](repeating: 0, count: 8)
        var length = 0
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer
        )
        let flags = event.flags
        return EditKey.from(
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            command: flags.contains(.maskCommand),
            option: flags.contains(.maskAlternate),
            control: flags.contains(.maskControl),
            shift: flags.contains(.maskShift),
            characters: String(utf16CodeUnits: buffer, count: length)
        )
    }
}

private func hotkeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().process(type, event)
    }
    return Unmanaged.passUnretained(event)
}
