import AppKit
import ApplicationServices
import Carbon
import SonicFlowCore

/// After a paste, follows the user's fixes until they move on, then passes on the misheard words
/// they fixed. Fields that Accessibility can read are reread; elsewhere, such as terminals, the
/// edit keys are replayed on the pasted line. Field text and keys stay in memory and are never
/// logged.
@MainActor
final class CorrectionWatcher {
    private static let settle = Duration.milliseconds(300)
    private static let interval = Duration.seconds(1)
    private static let checks = 60
    private static let maxFieldLength = 100_000

    var onLearn: ([LearnedWord]) -> Void = { _ in }
    private var task: Task<Void, Never>?
    private var replay: KeyReplay?

    func watch(_ pasted: String) {
        stop()
        let replay = KeyReplay(pasted, app: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        self.replay = replay
        task = Task { [weak self] in await self?.run(pasted, replay) }
    }

    /// Ends the watch, still learning from the fixes made so far.
    func stop() {
        task?.cancel()
        task = nil
        replay = nil
    }

    /// A key pressed or a click anywhere, while a watch may need it. Keys that reach another app,
    /// or arrive while a password prompt hides keys from SonicFlow, end the replay.
    func observe(_ key: () -> EditKey) {
        guard let replay else { return }
        let sameApp = NSWorkspace.shared.frontmostApplication?.processIdentifier == replay.app
        replay.apply(sameApp && !IsSecureEventInputEnabled() ? key() : .unsupported)
    }

    private func run(_ pasted: String, _ replay: KeyReplay) async {
        try? await Task.sleep(for: Self.settle)
        guard !Task.isCancelled else { return }
        let edited: String?
        switch FocusedField.current() {
        case .secure:
            if self.replay === replay { self.replay = nil }
            return
        case let .readable(field):
            if let text = field.value, (text as NSString).length <= Self.maxFieldLength,
                let region = PastedRegion(pasted: pasted, in: text, caret: field.caret)
            {
                if self.replay === replay { self.replay = nil }
                edited = await reread(field, region, pasted)
            } else {
                edited = await replayed(replay)
            }
        case nil:
            edited = await replayed(replay)
        }
        guard let edited, edited != pasted else { return }
        let words = Corrections.learn(pasted: pasted, edited: edited, isCommonWord: CommonWords.contains)
        if !words.isEmpty { onLearn(words) }
    }

    private func reread(_ field: FocusedField, _ region: PastedRegion, _ pasted: String) async -> String {
        var edited = pasted
        for _ in 0..<Self.checks {
            try? await Task.sleep(for: Self.interval)
            guard !Task.isCancelled, field.isFocused, let text = field.value, !text.isEmpty else { break }
            if let current = region.text(in: text) { edited = current }
        }
        return edited
    }

    /// The line as the replayed keys left it when the user pressed Return, moved on, or dictated
    /// again; `nil` once a key's effect couldn't be followed.
    private func replayed(_ replay: KeyReplay) async -> String? {
        for _ in 0..<Self.checks where !Task.isCancelled && !replay.submitted && replay.editor != nil {
            try? await Task.sleep(for: Self.interval)
        }
        if self.replay === replay { self.replay = nil }
        return replay.editor?.text
    }
}

@MainActor
private final class KeyReplay {
    let app: pid_t?
    private(set) var editor: LineEditor?
    private(set) var submitted = false

    init(_ pasted: String, app: pid_t?) {
        self.app = app
        editor = LineEditor(pasted)
    }

    func apply(_ key: EditKey) {
        guard !submitted, var current = editor else { return }
        if key == .submit {
            submitted = true
        } else if current.apply(key) {
            editor = current
        } else {
            editor = nil
        }
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

    enum Focus {
        case readable(FocusedField)
        case secure
    }

    /// `nil` when the focused element can't be found, as in apps that hide their text.
    static func current() -> Focus? {
        var focused: AnyObject?
        guard
            AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
                == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement
        guard attribute(element, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole else { return .secure }
        return .readable(FocusedField(element: element))
    }

    var isFocused: Bool {
        guard case let .readable(focused) = Self.current() else { return false }
        return CFEqual(focused.element, element)
    }

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
