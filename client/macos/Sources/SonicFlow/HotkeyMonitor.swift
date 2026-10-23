import AppKit
import CoreGraphics

/// Listens system-wide for the Option key via a listen-only event tap (needs Input Monitoring).
final class HotkeyMonitor {
    /// Times are seconds since boot, comparable with `ProcessInfo.systemUptime`.
    enum Input {
        case hotkeyDown(at: TimeInterval)
        case hotkeyUp(at: TimeInterval)
        case other
    }

    private static let optionKeyCodes: Set<Int64> = [58, 61]
    private static let otherModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskShift]

    private let handler: (Input) -> Void
    private var tap: CFMachPort?

    init(handler: @escaping (Input) -> Void) {
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
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard Self.optionKeyCodes.contains(keyCode) else {
                handler(.other)
                return
            }
            let time = NSEvent(cgEvent: event)?.timestamp ?? ProcessInfo.processInfo.systemUptime
            if !event.flags.contains(.maskAlternate) {
                handler(.hotkeyUp(at: time))
            } else if event.flags.intersection(Self.otherModifiers).isEmpty {
                handler(.hotkeyDown(at: time))
            } else {
                handler(.other)
            }
        default:
            handler(.other)
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
