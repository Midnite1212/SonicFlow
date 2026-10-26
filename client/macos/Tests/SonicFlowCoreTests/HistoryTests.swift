import Foundation
import Testing

@testable import SonicFlowCore

@Test func recordsNewestFirstAndCaps() {
    var history = History(capacity: 2)
    history.record("one", latencyMs: 100)
    history.record("two", latencyMs: 100)
    history.record("three", latencyMs: 100)
    #expect(history.entries.map(\.text) == ["three", "two"])
}

@Test func ignoresEmptyTextAndClears() {
    var history = History()
    history.record("", latencyMs: 100)
    #expect(history.entries.isEmpty)
    history.record("hi", latencyMs: 100)
    history.clear()
    #expect(history.entries.isEmpty)
}

@Test func previewCollapsesWhitespaceAndTruncates() {
    #expect(History.preview("a\n  b") == "a b")
    #expect(History.preview(String(repeating: "x", count: 60), limit: 10) == "xxxxxxxxx…")
}

@Test func prunesByRetention() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    var history = History()
    history.record("old", at: now.addingTimeInterval(-8 * 86_400), latencyMs: 1)
    history.record("recent", at: now.addingTimeInterval(-2 * 86_400), latencyMs: 1)
    history.prune(keeping: .forever, now: now)
    #expect(history.entries.count == 2)
    history.prune(keeping: .week, now: now)
    #expect(history.entries.map(\.text) == ["recent"])
    history.prune(keeping: .day, now: now)
    #expect(history.entries.isEmpty)
}

@Test func removesAndSearches() {
    var history = History()
    history.record("Lunch at noon", latencyMs: 1, appName: "Slack")
    history.record("Ship the build", latencyMs: 1, appName: "Mail")
    #expect(history.matching("lunch").map(\.text) == ["Lunch at noon"])
    #expect(history.matching("mail").map(\.text) == ["Ship the build"])
    #expect(history.matching("  ").count == 2)
    history.remove(history.entries[0].id)
    #expect(history.entries.map(\.text) == ["Lunch at noon"])
}

@Test func historyRoundTripsThroughJSON() throws {
    var history = History(capacity: 5)
    history.record("hello world", latencyMs: 120, appName: "Notes")
    let decoded = try JSONDecoder().decode(History.self, from: JSONEncoder().encode(history))
    #expect(decoded.entries == history.entries)
    #expect(decoded.entries[0].wordCount == 2)
}

@Test func statsTotalsWindowsAndStreak() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
    let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
    func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }

    var stats = UsageStats()
    stats.record(words: 30, speakingSeconds: 12, latencyMs: 200, on: day(0), calendar: calendar)
    stats.record(words: 10, speakingSeconds: 3, latencyMs: 400, on: day(0), calendar: calendar)
    stats.record(words: 20, speakingSeconds: 6, latencyMs: 300, on: day(-1), calendar: calendar)
    stats.record(words: 50, speakingSeconds: 20, latencyMs: 300, on: day(-9), calendar: calendar)

    let todayTotals = stats.totals(lastDays: 1, endingOn: today, calendar: calendar)
    #expect(todayTotals.dictations == 2)
    #expect(todayTotals.words == 40)
    #expect(todayTotals.wordsPerMinute == 160)
    #expect(todayTotals.averageLatencyMs == 300)
    #expect(stats.totals(lastDays: 7, endingOn: today, calendar: calendar).words == 60)
    #expect(stats.totals(lastDays: nil, calendar: calendar).words == 110)
    #expect(stats.streak(endingOn: today, calendar: calendar) == 2)
    #expect(stats.streak(endingOn: day(1), calendar: calendar) == 2)
    #expect(stats.streak(endingOn: day(3), calendar: calendar) == 0)
}

@Test func timeSavedNeverNegative() {
    var totals = UsageStats.Totals()
    totals.words = 40
    totals.speakingSeconds = 15
    #expect(totals.timeSavedSeconds() == 45)
    totals.speakingSeconds = 120
    #expect(totals.timeSavedSeconds() == 0)
    #expect(UsageStats.Totals().wordsPerMinute == nil)
}

@Test func percentilesSkipEditsAndOldEntries() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    var history = History()
    for (offset, latency) in [(0, 100.0), (0, 200), (0, 300), (0, 400), (0, 500)] {
        history.record("x", at: now.addingTimeInterval(Double(-offset)), latencyMs: latency)
    }
    history.record("edit", at: now, latencyMs: 900, isEdit: true)
    history.record("old", at: now.addingTimeInterval(-10 * 86_400), latencyMs: 5)
    let week = now.addingTimeInterval(-7 * 86_400)
    #expect(history.latencyPercentile(0.5, since: week) == 300)
    #expect(history.latencyPercentile(0.95, since: week) == 500)
    #expect(history.latencyPercentile(0.5, since: now.addingTimeInterval(1)) == nil)
    #expect(history.entries.filter(\.isEdit).map(\.text) == ["edit"])
}

@Test func entriesSavedBeforeEditFlagStillDecode() throws {
    let json = #"{"capacity":5,"entries":[{"id":"7598E2B3-9D6A-4C95-A54C-08D7B5236270","text":"hi","date":0,"latencyMs":120}]}"#
    let history = try JSONDecoder().decode(History.self, from: Data(json.utf8))
    #expect(history.entries.first?.isEdit == false)
}
