import AppKit
import ApplicationServices

/// The text selected in the focused app, for command mode.
@MainActor
enum Selection {
    private static let cKeyCode: CGKeyCode = 8

    static func read() async -> String? {
        if let text = accessibilitySelection(), !text.isEmpty { return text }
        return await copySelection()
    }

    private static func accessibilitySelection() -> String? {
        var focused: AnyObject?
        let system = AXUIElementCreateSystemWide()
        guard
            AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
                == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        var selected: AnyObject?
        guard
            AXUIElementCopyAttributeValue(
                focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected
            ) == .success
        else { return nil }
        return selected as? String
    }

    /// For apps without accessible text (many Electron and web views): Cmd+C, read, and put the
    /// clipboard back. A private event source keeps the held hotkey and Shift out of the shortcut.
    private static func copySelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        let before = pasteboard.changeCount
        HotkeyMonitor.post(cKeyCode, flags: .maskCommand, source: CGEventSource(stateID: .privateState))
        for _ in 0..<10 where pasteboard.changeCount == before {
            try? await Task.sleep(for: .milliseconds(30))
        }
        guard pasteboard.changeCount != before else { return nil }
        let copied = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        if let previous { pasteboard.setString(previous, forType: .string) }
        return copied
    }
}
