import Foundation

/// A key pressed while editing a pasted line, for fields that can't be read back (terminals).
/// Only keys that edit the same way in every terminal are followed.
public enum EditKey: Equatable, Sendable {
    case insert(String)
    case backspace, forwardDelete
    case left, right, wordLeft, wordRight
    case deleteWordBack
    case submit
    /// A key whose effect can't be followed, such as a click, history, a new line, or a shortcut
    /// that terminals map differently (⌘ and ⌃ keys, Home, End, ⌥ as Meta).
    case unsupported

    private enum Code {
        static let returnKey: Int64 = 36
        static let enter: Int64 = 76
        static let delete: Int64 = 51
        static let forwardDelete: Int64 = 117
        static let left: Int64 = 123
        static let right: Int64 = 124
    }

    public static func from(
        keyCode: Int64, command: Bool, option: Bool, control: Bool, shift: Bool, characters: String
    ) -> EditKey {
        guard !command, !control else { return .unsupported }
        switch keyCode {
        case Code.returnKey, Code.enter: return option || shift ? .unsupported : .submit
        case Code.delete: return shift ? .unsupported : option ? .deleteWordBack : .backspace
        case Code.forwardDelete: return option || shift ? .unsupported : .forwardDelete
        case Code.left: return shift ? .unsupported : option ? .wordLeft : .left
        case Code.right: return shift ? .unsupported : option ? .wordRight : .right
        default: break
        }
        // Arrow, function and page keys type characters from the private-use range.
        guard !option, !characters.isEmpty,
            !characters.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0) || (0xF700...0xF8FF).contains($0.value)
            })
        else { return .unsupported }
        return .insert(characters)
    }
}

/// Replays edit keys on a pasted line, whose caret starts at its end, to learn how it reads after
/// the user's fixes.
public struct LineEditor: Sendable {
    public private(set) var characters: [Character]
    public private(set) var cursor: Int

    public init(_ text: String) {
        characters = Array(text)
        cursor = characters.count
    }

    public var text: String { String(characters) }

    /// Applies a key; `false` once its effect can't be known, such as moving before the paste,
    /// where the field may hold text this editor never saw.
    public mutating func apply(_ key: EditKey) -> Bool {
        switch key {
        case let .insert(string):
            characters.insert(contentsOf: string, at: cursor)
            cursor += string.count
        case .backspace:
            guard cursor > 0 else { return false }
            cursor -= 1
            characters.remove(at: cursor)
        case .forwardDelete:
            guard cursor < characters.count else { return false }
            characters.remove(at: cursor)
        case .left:
            guard cursor > 0 else { return false }
            cursor -= 1
        case .right:
            guard cursor < characters.count else { return false }
            cursor += 1
        case .wordLeft:
            guard cursor > 0 else { return false }
            cursor = wordStart(before: cursor)
        case .wordRight:
            guard cursor < characters.count else { return false }
            cursor = wordEnd(after: cursor)
        case .deleteWordBack:
            guard cursor > 0 else { return false }
            let start = wordStart(before: cursor)
            characters.removeSubrange(start..<cursor)
            cursor = start
        case .submit, .unsupported:
            return false
        }
        return true
    }

    /// Words are runs of letters and digits, as readline and macOS text fields move by them.
    private func wordStart(before index: Int) -> Int {
        var index = index
        while index > 0, !isWordCharacter(characters[index - 1]) { index -= 1 }
        while index > 0, isWordCharacter(characters[index - 1]) { index -= 1 }
        return index
    }

    private func wordEnd(after index: Int) -> Int {
        var index = index
        while index < characters.count, !isWordCharacter(characters[index]) { index += 1 }
        while index < characters.count, isWordCharacter(characters[index]) { index += 1 }
        return index
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
