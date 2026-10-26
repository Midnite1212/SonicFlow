import Foundation

/// Dictations, newest first. Lives in memory unless the user turns on saving; the app then writes
/// it to disk and prunes it by `HistoryRetention`.
public struct History: Codable, Sendable {
    public struct Entry: Identifiable, Equatable, Codable, Sendable {
        public let id: UUID
        public let text: String
        public let date: Date
        public let latencyMs: Double
        public let appName: String?
        /// Optional so history saved before command mode still decodes.
        private let edit: Bool?

        public init(
            id: UUID = UUID(), text: String, date: Date, latencyMs: Double, appName: String? = nil,
            isEdit: Bool = false
        ) {
            self.id = id
            self.text = text
            self.date = date
            self.latencyMs = latencyMs
            self.appName = appName
            self.edit = isEdit
        }

        public var isEdit: Bool { edit ?? false }

        public var wordCount: Int { History.wordCount(text) }
    }

    public let capacity: Int
    public private(set) var entries: [Entry]

    public init(capacity: Int = 500, entries: [Entry] = []) {
        self.capacity = capacity
        self.entries = Array(entries.prefix(capacity))
    }

    public mutating func record(
        _ text: String, at date: Date = Date(), latencyMs: Double, appName: String? = nil,
        isEdit: Bool = false
    ) {
        guard !text.isEmpty else { return }
        let entry = Entry(text: text, date: date, latencyMs: latencyMs, appName: appName, isEdit: isEdit)
        entries.insert(entry, at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
    }

    public mutating func remove(_ id: Entry.ID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func prune(keeping retention: HistoryRetention, now: Date = Date()) {
        guard let cutoff = retention.cutoff(from: now) else { return }
        entries.removeAll { $0.date < cutoff }
    }

    public mutating func clear() {
        entries.removeAll()
    }

    public func matching(_ query: String) -> [Entry] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.text.localizedCaseInsensitiveContains(query)
                || ($0.appName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// The latency below which `fraction` of dictations since `cutoff` landed (0.5 is the
    /// median); edits are left out because they measure a different job. Nil with no samples.
    public func latencyPercentile(_ fraction: Double, since cutoff: Date) -> Double? {
        let samples = entries.filter { !$0.isEdit && $0.date >= cutoff }.map(\.latencyMs).sorted()
        guard !samples.isEmpty else { return nil }
        let rank = Int((fraction * Double(samples.count - 1)).rounded())
        return samples[min(max(rank, 0), samples.count - 1)]
    }

    /// One line for a menu item: whitespace collapsed and long text cut with an ellipsis.
    public static func preview(_ text: String, limit: Int = 48) -> String {
        let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return line.count <= limit ? line : String(line.prefix(limit - 1)) + "…"
    }

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

public enum HistoryRetention: String, CaseIterable, Codable, Sendable {
    case day, week, month, forever

    public var title: String {
        switch self {
        case .day: "1 day"
        case .week: "7 days"
        case .month: "30 days"
        case .forever: "Forever"
        }
    }

    public func cutoff(from now: Date) -> Date? {
        let days: Double? =
            switch self {
            case .day: 1
            case .week: 7
            case .month: 30
            case .forever: nil
            }
        return days.map { now.addingTimeInterval(-$0 * 86_400) }
    }
}
