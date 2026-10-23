import AppKit

enum Paster {
    private static let vKeyCode: CGKeyCode = 9

    /// Pastes into the focused app via the pasteboard and Cmd+V (needs Accessibility), then puts
    /// the user's previous text back unless they copied something else in the meantime.
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ours = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        guard let previous else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard pasteboard.changeCount == ours else { return }
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }
}
