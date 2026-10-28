import Foundation

/// Measures the user's own typing speed, so time saved compares dictation with how they really type.
public enum TypingTest {
    /// An average typist, assumed until the user measures their own speed.
    public static let averageWordsPerMinute: Double = 40

    public static let passages = [
        "The best way to get something done is to begin. Small steps taken every day add up to more than "
            + "big plans made once a year, and the work feels lighter when you can see it moving.",
        "Good tools disappear while you use them. You stop thinking about the keyboard or the screen and "
            + "think only about what you want to say, which is exactly where your attention belongs.",
        "A quiet morning is a gift. Before the messages arrive and the meetings start, there is time to read, "
            + "to plan the day, and to write down the one thing that matters most.",
    ]

    /// Net words per minute: characters of correctly typed words (and the spaces after them), five to a
    /// word. A mistyped word earns nothing, and a word still being typed counts while it matches so far.
    public static func wordsPerMinute(typed: String, passage: String, seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let typedWords = typed.split(separator: " ", omittingEmptySubsequences: false)
        let passageWords = passage.split(separator: " ")
        var correct = 0
        for (index, word) in typedWords.enumerated() where index < passageWords.count {
            let target = passageWords[index]
            let isLast = index == typedWords.count - 1
            if word == target {
                correct += word.count + (isLast ? 0 : 1)
            } else if isLast, target.hasPrefix(word) {
                correct += word.count
            }
        }
        return Double(correct) / 5 / (seconds / 60)
    }

    public enum Mark: Equatable, Sendable {
        case pending, correct, wrong, missed, extra
    }

    public struct Glyph: Equatable, Sendable {
        public let character: Character
        public let mark: Mark
    }

    /// Marks the passage word by word, as Monkeytype does: space moves to the next word, each typed word
    /// is compared only with its own target, letters left untyped when space was pressed are missed, and
    /// letters typed past the end of a word are shown after it as extra.
    public static func marks(typed: String, passage: String) -> [[Glyph]] {
        let typedWords = typed.split(separator: " ", omittingEmptySubsequences: false).map(Array.init)
        return passage.split(separator: " ").enumerated().map { index, target in
            guard index < typedWords.count else { return target.map { Glyph(character: $0, mark: .pending) } }
            let word = typedWords[index]
            let isCurrent = index == typedWords.count - 1
            var glyphs = target.enumerated().map { offset, character in
                let mark: Mark =
                    offset < word.count
                    ? (word[offset] == character ? .correct : .wrong) : isCurrent ? .pending : .missed
                return Glyph(character: character, mark: mark)
            }
            glyphs += word.dropFirst(target.count).map { Glyph(character: $0, mark: .extra) }
            return glyphs
        }
    }

    /// Done once the last word is typed correctly, or space is pressed after it.
    public static func isFinished(typed: String, passage: String) -> Bool {
        let typedWords = typed.split(separator: " ", omittingEmptySubsequences: false)
        let passageWords = passage.split(separator: " ")
        return typedWords.count > passageWords.count
            || (typedWords.count == passageWords.count && typedWords.last == passageWords.last)
    }

    /// Space can't start a word, so stray spaces never skip one.
    public static func normalized(_ typed: String) -> String {
        var result = ""
        for character in typed where !(character == " " && (result.isEmpty || result.last == " ")) {
            result.append(character)
        }
        return result
    }

    public static func secondsToType(words: Int, wordsPerMinute: Double) -> Double {
        Double(words) / wordsPerMinute * 60
    }
}
