import Foundation

/// Per-day dictation counts. Holds numbers only, never text, so it is kept on disk regardless of
/// the history setting.
public struct UsageStats: Codable, Equatable, Sendable {
    public struct Totals: Codable, Equatable, Sendable {
        public var dictations = 0
        public var words = 0
        public var speakingSeconds: Double = 0
        public var latencyMsSum: Double = 0

        public init() {}

        public var wordsPerMinute: Double? {
            speakingSeconds > 0 ? Double(words) / speakingSeconds * 60 : nil
        }

        public var averageLatencyMs: Double? {
            dictations > 0 ? latencyMsSum / Double(dictations) : nil
        }

        /// Typing the same words at `typingWordsPerMinute`, minus the time spent speaking.
        public func timeSavedSeconds(typingWordsPerMinute: Double = 40) -> Double {
            max(0, Double(words) / typingWordsPerMinute * 60 - speakingSeconds)
        }

        mutating func add(_ other: Totals) {
            dictations += other.dictations
            words += other.words
            speakingSeconds += other.speakingSeconds
            latencyMsSum += other.latencyMsSum
        }
    }

    /// Keyed by local day, `yyyy-MM-dd`, so keys sort chronologically.
    public private(set) var days: [String: Totals] = [:]

    public init() {}

    public mutating func record(
        words: Int, speakingSeconds: Double, latencyMs: Double, on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        let key = Self.key(date, calendar)
        var day = days[key] ?? Totals()
        day.dictations += 1
        day.words += words
        day.speakingSeconds += speakingSeconds
        day.latencyMsSum += latencyMs
        days[key] = day
    }

    /// Totals for the `days` calendar days ending on `date`, or for all time when `days` is nil.
    public func totals(lastDays days: Int?, endingOn date: Date = Date(), calendar: Calendar = .current)
        -> Totals
    {
        var result = Totals()
        let first = days.flatMap { calendar.date(byAdding: .day, value: 1 - $0, to: date) }
            .map { Self.key($0, calendar) }
        for (key, day) in self.days where first.map({ key >= $0 }) ?? true {
            result.add(day)
        }
        return result
    }

    /// Consecutive days with a dictation, counting back from today, or from yesterday when today
    /// has none yet.
    public func streak(endingOn date: Date = Date(), calendar: Calendar = .current) -> Int {
        var day = date
        if days[Self.key(day, calendar)] == nil {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while days[Self.key(day, calendar)] != nil {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    static func key(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
