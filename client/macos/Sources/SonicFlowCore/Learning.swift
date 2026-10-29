import Foundation

/// Corrections noticed after pasting, newest first: those learned and those held back for the
/// user to add or dismiss. Holds only the misheard and fixed words, never the text around them,
/// and is kept like `History`.
public struct LearningLog: Codable, Sendable {
    public struct Entry: Identifiable, Equatable, Codable, Sendable {
        public enum Status: String, Codable, Sendable {
            case learned, suggested, dismissed
        }

        public let id: UUID
        public let term: String
        public let heard: String?
        public var hold: Correction.Hold?
        public var status: Status
        public var date: Date
        /// How many times the user made this fix.
        public var count: Int

        public init(
            id: UUID = UUID(), term: String, heard: String?, hold: Correction.Hold?, status: Status, date: Date,
            count: Int = 1
        ) {
            self.id = id
            self.term = term
            self.heard = heard
            self.hold = hold
            self.status = status
            self.date = date
            self.count = count
        }

        public var word: LearnedWord { LearnedWord(term: term, heard: heard) }

        func matches(_ word: LearnedWord) -> Bool {
            term == word.term && heard?.lowercased() == word.heard?.lowercased()
        }
    }

    public let capacity: Int
    public private(set) var entries: [Entry]

    public init(capacity: Int = 200, entries: [Entry] = []) {
        self.capacity = capacity
        self.entries = Array(entries.prefix(capacity))
    }

    public var suggestions: [Entry] { entries.filter { $0.status == .suggested } }

    /// Adds corrections, folding a repeated fix into its entry. A fix learned on its own marks the
    /// entry learned; one held back again leaves a dismissed or learned entry as it was.
    public mutating func record(_ corrections: [Correction], at date: Date = Date()) {
        for correction in corrections {
            guard let index = entries.firstIndex(where: { $0.matches(correction.word) }) else {
                entries.insert(
                    Entry(
                        term: correction.word.term, heard: correction.word.heard, hold: correction.hold,
                        status: correction.hold == nil ? .learned : .suggested, date: date
                    ),
                    at: 0
                )
                continue
            }
            var entry = entries.remove(at: index)
            entry.count += 1
            entry.date = date
            if correction.hold == nil {
                entry.status = .learned
                entry.hold = nil
            }
            entries.insert(entry, at: 0)
        }
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
    }

    public mutating func set(_ id: Entry.ID, to status: Entry.Status) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].status = status
    }

    public mutating func prune(keeping retention: HistoryRetention, now: Date = Date()) {
        guard let cutoff = retention.cutoff(from: now) else { return }
        entries.removeAll { $0.date < cutoff }
    }

    public mutating func clear() {
        entries.removeAll()
    }
}
