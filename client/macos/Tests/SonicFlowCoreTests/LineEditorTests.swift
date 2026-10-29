import Testing

@testable import SonicFlowCore

private func replay(_ pasted: String, _ keys: [EditKey]) -> String? {
    var editor = LineEditor(pasted)
    for key in keys where !editor.apply(key) { return nil }
    return editor.text
}

@Test func replaysAFixToAWordBeforeTheCaret() {
    let keys: [EditKey] = [.wordLeft, .deleteWordBack, .deleteWordBack, .insert("Mac Studio "), .wordRight]
    #expect(replay("It runs on the Max Videos engine.", keys) == "It runs on the Mac Studio engine.")
    #expect(replay("ship config.yaml", [.deleteWordBack, .insert("json")]) == "ship config.json")
}

@Test func replaysCharacterEdits() {
    let keys: [EditKey] = [.left, .backspace, .insert("ll"), .right, .insert("!")]
    #expect(replay("Hexo", keys) == "Hello!")
    #expect(replay("ab", [.left, .left, .forwardDelete, .insert("c")]) == "cb")
}

@Test func movingBeforeThePasteOrUnknownKeysStopTheReplay() {
    #expect(replay("ab", [.left, .left, .left]) == nil)
    #expect(replay("ab", [.backspace, .backspace, .backspace]) == nil)
    #expect(replay("ab", [.unsupported]) == nil)
}

@Test func keysMapToEdits() {
    func key(_ code: Int64, command: Bool = false, option: Bool = false, control: Bool = false,
             shift: Bool = false, _ characters: String = "") -> EditKey {
        EditKey.from(keyCode: code, command: command, option: option, control: control, shift: shift,
                     characters: characters)
    }
    #expect(key(0, "a") == .insert("a"))
    #expect(key(0, shift: true, "A") == .insert("A"))
    #expect(key(51) == .backspace)
    #expect(key(51, option: true) == .deleteWordBack)
    #expect(key(123, option: true) == .wordLeft)
    #expect(key(51, command: true) == .unsupported)
    #expect(key(124, command: true) == .unsupported)
    #expect(key(0, control: true, "\u{1}") == .unsupported)
    #expect(key(11, option: true, "\u{222B}") == .unsupported)
    #expect(key(115, "\u{F729}") == .unsupported)
    #expect(key(36, "\r") == .submit)
    #expect(key(36, shift: true, "\r") == .unsupported)
    #expect(key(126, "\u{F700}") == .unsupported)
    #expect(key(9, command: true, "v") == .unsupported)
    #expect(key(53, "\u{1B}") == .unsupported)
}
