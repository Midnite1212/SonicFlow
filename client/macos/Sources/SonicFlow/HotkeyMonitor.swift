import AppKit
import CoreGraphics
import SonicFlowCore

/// Listens system-wide for the dictation hotkey via a listen-only event tap.
final class HotkeyMonitor {
    /// Times are seconds since boot, comparable with `ProcessInfo.systemUptime`.
    enum Input {
        case hotkeyDown(at: TimeInterval)
        case hotkeyUp(at: TimeInterval)
        case escape
        /// What interrupted the hotkey, for the log: modifier key codes only, never typed keys.
        case other(String)
    }

    private static let escapeKeyCode: Int64 = 53

    var hotkey: Hotkey
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
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            let time = NSEvent(cgEvent: event)?.timestamp ?? ProcessInfo.processInfo.systemUptime
            switch hotkey.classify(keyCode: keyCode, flags: event.flags) {
            case .down: handler(.hotkeyDown(at: time))
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
