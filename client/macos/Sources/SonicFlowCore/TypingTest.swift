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

    public static func secondsToType(words: Int, wordsPerMinute: Double) -> Double {
        Double(words) / wordsPerMinute * 60
    }
}
