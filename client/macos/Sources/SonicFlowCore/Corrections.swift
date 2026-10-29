import Foundation

/// A dictionary word learned from a correction, and what the speech model wrote instead.
public struct LearnedWord: Equatable, Sendable {
    public let term: String
    /// `nil` when the term already matches what was heard, ignoring case.
    public let heard: String?

    public init(term: String, heard: String?) {
        self.term = term
        self.heard = heard
    }
}

/// Where a paste landed in a text field, so its text can be found again after the user edits it.
public struct PastedRegion: Equatable, Sendable {
    public let prefix: String
    public let suffix: String

    /// The paste ends at the caret when it can; otherwise it is the last occurrence of `pasted`.
    public init?(pasted: String, in text: String, caret: Int?) {
        let field = text as NSString
        let length = (pasted as NSString).length
        guard length > 0 else { return nil }
        var range = NSRange(location: NSNotFound, length: 0)
        if let caret, caret >= length, caret <= field.length,
            field.substring(with: NSRange(location: caret - length, length: length)) == pasted
        {
            range = NSRange(location: caret - length, length: length)
        } else {
            range = field.range(of: pasted, options: .backwards)
        }
        guard range.location != NSNotFound else { return nil }
        prefix = field.substring(to: range.location)
        suffix = field.substring(from: NSMaxRange(range))
    }

    /// The pasted text as it reads now, or `nil` once the text around it has changed.
    public func text(in field: String) -> String? {
        let field = field as NSString
        let prefixLength = (prefix as NSString).length
        let suffixLength = (suffix as NSString).length
        guard field.length >= prefixLength + suffixLength, field.hasPrefix(prefix), field.hasSuffix(suffix)
        else { return nil }
        return field.substring(
            with: NSRange(location: prefixLength, length: field.length - prefixLength - suffixLength)
        )
    }
}

/// Finds the names and jargon a user fixed in pasted text.
public enum Corrections {
    static let maxWords = 3
    static let maxLength = 40
    /// How alike the heard and fixed spellings must be, so rewording isn't mistaken for a mishearing.
    static let minSimilarity = 0.5

    /// `isCommonWord` gets a lowercased word; a fix made only of common words, like "will" to
    /// "Will", is left alone because learning it would rewrite the common word everywhere.
    public static func learn(
        pasted: String, edited: String, isCommonWord: (String) -> Bool
    ) -> [LearnedWord] {
        let old = words(pasted)
        let hunks = changes(from: old, to: words(edited))
        let changed = hunks.reduce(0) { $0 + $1.old.count }
        guard changed <= max(maxWords, old.count / 2) else { return [] }
        return hunks.compactMap { learned(from: $0, isCommonWord: isCommonWord) }
    }

    private static func learned(from hunk: Hunk, isCommonWord: (String) -> Bool) -> LearnedWord? {
        guard (1...maxWords).contains(hunk.old.count), (1...maxWords).contains(hunk.new.count) else {
            return nil
        }
        let term = hunk.new.joined(separator: " ")
        let heard = hunk.old.joined(separator: " ")
        // A single common word heard ("it", "were", "meeting") would be rewritten everywhere, and
        // apostrophes mark grammar fixes rather than names.
        guard (2...maxLength).contains(term.count),
            !(hunk.old.count == 1 && isCommonWord(heard.lowercased())),
            !term.contains(where: { $0 == "'" || $0 == "\u{2019}" }),
            hunk.new.contains(where: { looksLikeVocabulary($0, isCommonWord: isCommonWord) }),
            similarity(letters(heard), letters(term)) >= minSimilarity
        else { return nil }
        return LearnedWord(term: term, heard: heard.lowercased() == term.lowercased() ? nil : heard)
    }

    /// Numbers alone are content, not vocabulary, so a digit counts only beside a letter ("Qwen3").
    private static func looksLikeVocabulary(_ word: String, isCommonWord: (String) -> Bool) -> Bool {
        guard word.contains(where: \.isLetter) else { return false }
        return word.contains(where: \.isNumber) || word.dropFirst().contains(where: \.isUppercase)
            || !isCommonWord(word.lowercased())
    }

    private static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
            .filter { !$0.isEmpty }
    }

    private static func letters(_ text: String) -> [Character] {
        text.lowercased().filter { $0.isLetter || $0.isNumber }.map { $0 }
    }

    private static func similarity(_ a: [Character], _ b: [Character]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var current = [i + 1]
            for (j, y) in b.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (x == y ? 0 : 1)))
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }

    struct Hunk: Equatable {
        var old: [String] = []
        var new: [String] = []
    }

    /// The runs of words that differ, from a longest-common-subsequence alignment.
    static func changes(from old: [String], to new: [String]) -> [Hunk] {
        var lengths = Array(repeating: Array(repeating: 0, count: new.count + 1), count: old.count + 1)
        for i in stride(from: old.count - 1, through: 0, by: -1) {
            for j in stride(from: new.count - 1, through: 0, by: -1) {
                lengths[i][j] =
                    old[i] == new[j] ? lengths[i + 1][j + 1] + 1 : max(lengths[i + 1][j], lengths[i][j + 1])
            }
        }
        var hunks: [Hunk] = []
        var hunk = Hunk()
        var i = 0
        var j = 0
        while i < old.count || j < new.count {
            if i < old.count, j < new.count, old[i] == new[j] {
                if hunk != Hunk() { hunks.append(hunk) }
                hunk = Hunk()
                i += 1
                j += 1
            } else if j < new.count, i == old.count || lengths[i][j + 1] >= lengths[i + 1][j] {
                hunk.new.append(new[j])
                j += 1
            } else {
                hunk.old.append(old[i])
                i += 1
            }
        }
        if hunk != Hunk() { hunks.append(hunk) }
        return hunks
    }
}

extension DictionaryTerm {
    /// `terms` with `words` added: a new term marked as learned, or a new Heard As spelling for a
    /// term already there.
    public static func adding(_ words: [LearnedWord], to terms: [DictionaryTerm]) -> [DictionaryTerm] {
        var terms = terms
        for word in words {
            guard
                let index = terms.firstIndex(where: {
                    $0.term.trimmingCharacters(in: .whitespaces) == word.term
                })
            else {
                terms.append(DictionaryTerm(term: word.term, heardAs: word.heard ?? "", learned: true))
                continue
            }
            guard let heard = word.heard,
                !terms[index].heard.contains(where: { $0.caseInsensitiveCompare(heard) == .orderedSame })
            else { continue }
            terms[index].heardAs = (terms[index].heard + [heard]).joined(separator: ", ")
        }
        return terms
    }
}

/// Lowercase English words from the macOS word list, the same list the engine uses.
public enum CommonWords {
    private static let all: Set<String> = {
        guard let text = try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8) else { return [] }
        return Set(text.split(separator: "\n").map(String.init).filter { $0 == $0.lowercased() })
    }()

    public static func contains(_ word: String) -> Bool { all.contains(word) }
}
