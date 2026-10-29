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
    /// How alike the heard and fixed words must look or sound, so rewording isn't mistaken for a
    /// mishearing.
    static let minSimilarity = 0.5
    static let minSpellingForSound = 0.3
    static let minSoundLength = 4

    typealias Phrase = (heard: [String], term: [String])

    /// `isCommonWord` gets a lowercased word; a fix made only of common words, like "will" to
    /// "Will", is left alone because learning it would rewrite the common word everywhere.
    public static func learn(
        pasted: String, edited: String, isCommonWord: (String) -> Bool
    ) -> [LearnedWord] {
        let old = words(pasted)
        let new = words(edited)
        let hunks = changes(from: old.map(\.text), to: new.map(\.text))
        let changed = hunks.reduce(0) { $0 + $1.old.count }
        guard changed <= max(maxWords, old.count / 2) else { return [] }
        return hunks.compactMap { learned(from: $0, old: old, new: new, isCommonWord: isCommonWord) }
    }

    private static func learned(
        from hunk: Hunk, old: [Word], new: [Word], isCommonWord: (String) -> Bool
    ) -> LearnedWord? {
        // A single common word heard ("it", "were", "meeting") would be rewritten everywhere.
        guard (1...maxWords).contains(hunk.old.count), (1...maxWords).contains(hunk.new.count),
            !(hunk.old.count == 1 && isCommonWord(old[hunk.old.lowerBound].text.lowercased()))
        else { return nil }
        let fix = (heard: old[hunk.old].map(\.text), term: new[hunk.new].map(\.text))
        if isName(fix, isCommonWord: isCommonWord) { return candidate(fix) }
        guard let name = widenedToName(hunk, old: old, new: new, isCommonWord: isCommonWord),
            isName(name, isCommonWord: isCommonWord)
        else { return nil }
        return candidate(name)
    }

    private static func isName(_ words: Phrase, isCommonWord: (String) -> Bool) -> Bool {
        let caseOnly = words.heard.joined(separator: " ").lowercased() == words.term.joined(separator: " ").lowercased()
        return looksLikeVocabulary(words.term, capitalsCount: !caseOnly, isCommonWord: isCommonWord)
    }

    private static func candidate(_ words: Phrase) -> LearnedWord? {
        let term = words.term.joined(separator: " ")
        let heard = words.heard.joined(separator: " ")
        let caseOnly = heard.lowercased() == term.lowercased()
        // Sound keys collide, between short words ("the team" and "Tim") and between names
        // ("Jonathan" and "Johnson"), so sound counts only for phrases misheard as other words
        // ("Max Videos"), with long enough keys and spellings somewhat alike.
        let spelling = similarity(letters(heard), letters(term))
        let (heardSound, termSound) = (sound(heard), sound(term))
        let sounding =
            max(words.heard.count, words.term.count) > 1 && spelling >= minSpellingForSound
                && min(heardSound.count, termSound.count) >= minSoundLength
            ? similarity(heardSound, termSound) : 0
        // An apostrophe left after dropping possessives marks a grammar fix ("we're"), not a name;
        // text typed straight after a word ("config" → "config.yaml") is not a fix of it.
        guard (2...maxLength).contains(term.count),
            !term.contains(where: { $0 == "'" || $0 == "\u{2019}" }),
            !(term.count > heard.count && term.lowercased().hasPrefix(heard.lowercased())),
            max(spelling, sounding) >= minSimilarity
        else { return nil }
        return LearnedWord(term: term, heard: caseOnly ? nil : heard)
    }

    /// Widens a fix that isn't a name on its own to the unchanged capitalized words beside it, so
    /// "Stoo videos" → "Studio" after "Mac" is learned as "Mac Studio". Capitals that only start a
    /// sentence, and "I", don't make a name.
    private static func widenedToName(
        _ hunk: Hunk, old: [Word], new: [Word], isCommonWord: (String) -> Bool
    ) -> Phrase? {
        func partOfName(_ word: Word) -> Bool {
            word.capitalized && word.text != "I" && !(word.sentenceStart && isCommonWord(word.text.lowercased()))
        }
        guard new[hunk.new].contains(where: { $0.capitalized && !$0.sentenceStart }) else { return nil }
        var oldRange = hunk.old
        var newRange = hunk.new
        func fits() -> Bool { max(oldRange.count, newRange.count) < maxWords }
        while fits(), newRange.lowerBound > 0, partOfName(new[newRange.lowerBound - 1]) {
            oldRange = oldRange.lowerBound - 1..<oldRange.upperBound
            newRange = newRange.lowerBound - 1..<newRange.upperBound
        }
        while fits(), newRange.upperBound < new.count, partOfName(new[newRange.upperBound]) {
            oldRange = oldRange.lowerBound..<oldRange.upperBound + 1
            newRange = newRange.lowerBound..<newRange.upperBound + 1
        }
        guard newRange != hunk.new else { return nil }
        return (old[oldRange].map(\.text), new[newRange].map(\.text))
    }

    /// Names and jargon: a capital inside a word ("GitHub"), a digit beside a letter ("Qwen3"), a
    /// word missing from the word list, or, when the spelling changed too, a phrase capitalized
    /// throughout ("Mac Studio"). Capitalizing common words alone ("That Was") is not a name.
    private static func looksLikeVocabulary(
        _ words: [String], capitalsCount: Bool, isCommonWord: (String) -> Bool
    ) -> Bool {
        if capitalsCount, words.count > 1, words.allSatisfy({ $0.first?.isUppercase == true }) { return true }
        return words.contains { word in
            word.contains(where: \.isLetter)
                && (word.contains(where: \.isNumber) || word.dropFirst().contains(where: \.isUppercase)
                    || !isCommonWord(word.lowercased()))
        }
    }

    private struct Word {
        let text: String
        let sentenceStart: Bool

        var capitalized: Bool { text.first?.isUppercase == true }
    }

    private static let closers = CharacterSet(charactersIn: "\"')]}\u{201D}\u{2019}")

    /// Words without edge punctuation or a possessive "'s", so "Studio's," matches "Studio".
    private static func words(_ text: String) -> [Word] {
        var words: [Word] = []
        var sentenceStart = true
        for token in text.split(whereSeparator: \.isWhitespace) {
            var word = token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            for mark in ["'s", "\u{2019}s"] where word.hasSuffix(mark) { word.removeLast(2) }
            if !word.isEmpty { words.append(Word(text: word, sentenceStart: sentenceStart)) }
            sentenceStart = token.trimmingCharacters(in: Self.closers).last.map { ".!?\u{2026}".contains($0) } ?? false
        }
        return words
    }

    private static func letters(_ text: String) -> [Character] {
        text.lowercased().filter { $0.isLetter || $0.isNumber }.map { $0 }
    }

    /// A rough sound-alike key: consonants grouped by how they sound, vowels dropped after the
    /// first letter. "Max Videos" and "Mac Studio" come out close though spelled apart.
    private static func sound(_ text: String) -> [Character] {
        let spelled = String(letters(text))
            .replacingOccurrences(of: "ph", with: "f")
            .replacingOccurrences(of: "ck", with: "k")
        var key: [Character] = []
        for (index, letter) in spelled.enumerated() {
            let codes: String
            switch letter {
            case "b", "p": codes = "p"
            case "c", "g", "k", "q": codes = "k"
            case "x": codes = "ks"
            case "d", "t": codes = "t"
            case "f", "v": codes = "f"
            case "s", "z": codes = "s"
            case "m", "n": codes = "m"
            case "a", "e", "i", "o", "u": codes = index == 0 ? "a" : ""
            case "h", "w", "y": codes = ""
            default: codes = String(letter)
            }
            for code in codes where code != key.last { key.append(code) }
        }
        return key
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
        var old: Range<Int>
        var new: Range<Int>
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
        var i = 0
        var j = 0
        var start = (old: 0, new: 0)
        func close() {
            if start.old < i || start.new < j { hunks.append(Hunk(old: start.old..<i, new: start.new..<j)) }
        }
        while i < old.count || j < new.count {
            if i < old.count, j < new.count, old[i] == new[j] {
                close()
                i += 1
                j += 1
                start = (i, j)
            } else if j < new.count, i == old.count || lengths[i][j + 1] >= lengths[i + 1][j] {
                j += 1
            } else {
                i += 1
            }
        }
        close()
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
