import AppKit
import ApplicationServices
import SonicFlowCore

/// After a paste, rereads the focused text field until the user moves on, then passes on the
/// misheard words they fixed. The field's text stays in memory and is never logged.
@MainActor
final class CorrectionWatcher {
    private static let settle = Duration.milliseconds(300)
    private static let interval = Duration.seconds(1)
    private static let checks = 60
    private static let maxFieldLength = 100_000

    var onLearn: ([LearnedWord]) -> Void = { _ in }
    private var task: Task<Void, Never>?

    func watch(_ pasted: String) {
        stop()
        task = Task { [weak self] in await self?.run(pasted) }
    }

    /// Ends the watch, still learning from the fixes made so far.
    func stop() {
        task?.cancel()
        task = nil
    }

    private func run(_ pasted: String) async {
        try? await Task.sleep(for: Self.settle)
        guard !Task.isCancelled, let field = FocusedField.current(), let text = field.value,
            (text as NSString).length <= Self.maxFieldLength,
            let region = PastedRegion(pasted: pasted, in: text, caret: field.caret)
        else { return }
        var edited = pasted
        for _ in 0..<Self.checks {
            try? await Task.sleep(for: Self.interval)
            guard !Task.isCancelled, field.isFocused, let text = field.value, !text.isEmpty else { break }
            if let current = region.text(in: text) { edited = current }
        }
        guard edited != pasted else { return }
        let words = Corrections.learn(pasted: pasted, edited: edited, isCommonWord: CommonWords.contains)
        if !words.isEmpty { onLearn(words) }
    }
}

private struct FocusedField {
    /// A timeout on the system-wide element applies to every Accessibility call, so a hung app
    /// can't stall the main thread for the default six seconds.
    private static let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, 0.5)
        return element
    }()

    let element: AXUIElement

    static func current() -> FocusedField? {
        var focused: AnyObject?
        guard
            AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
                == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement
        guard attribute(element, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole else { return nil }
        return FocusedField(element: element)
    }

    var isFocused: Bool { Self.current().map { CFEqual($0.element, element) } ?? false }

    var value: String? { Self.attribute(element, kAXValueAttribute) as? String }

    /// The end of the selection, in UTF-16 units; right after a paste it is the paste's end.
    var caret: Int? {
        guard let range = Self.attribute(element, kAXSelectedTextRangeAttribute),
            CFGetTypeID(range) == AXValueGetTypeID()
        else { return nil }
        var cfRange = CFRange()
        guard AXValueGetValue(range as! AXValue, .cfRange, &cfRange) else { return nil }
        return cfRange.location + cfRange.length
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
