import Foundation

/// Recent dictations, newest first. Lives in memory only: dictated text is never written to disk.
public struct History: Sendable {
    public struct Entry: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let text: String
        public let date: Date
        public let latencyMs: Double
    }

    public let capacity: Int
    public private(set) var entries: [Entry] = []

    public init(capacity: Int = 20) {
        self.capacity = capacity
    }

    public mutating func record(_ text: String, at date: Date = Date(), latencyMs: Double) {
        guard !text.isEmpty else { return }
        entries.insert(Entry(text: text, date: date, latencyMs: latencyMs), at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
    }

    public mutating func clear() {
        entries.removeAll()
    }

    /// One line for a menu item: whitespace collapsed and long text cut with an ellipsis.
    public static func preview(_ text: String, limit: Int = 48) -> String {
        let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return line.count <= limit ? line : String(line.prefix(limit - 1)) + "…"
    }
}
