import Foundation

/// What cleanup did to a dictation: the words heard, each marked kept or removed.
public enum TranscriptDiff {
    public struct Word: Equatable, Sendable {
        public let text: String
        public let removed: Bool

        public init(_ text: String, removed: Bool) {
            self.text = text
            self.removed = removed
        }
    }

    /// Words match ignoring case and punctuation, so "Thursday," in the transcript is kept when
    /// cleanup wrote "Thursday.".
    public static func heard(raw: String, cleaned: String) -> [Word] {
        let rawWords = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        let cleanedWords = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
        let removed = Corrections.changes(from: rawWords.map(key), to: cleanedWords.map(key))
            .reduce(into: Set<Int>()) { $0.formUnion($1.old) }
        return rawWords.enumerated().map { Word($1, removed: removed.contains($0)) }
    }

    private static func key(_ word: String) -> String {
        word.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
