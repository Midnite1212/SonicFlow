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
