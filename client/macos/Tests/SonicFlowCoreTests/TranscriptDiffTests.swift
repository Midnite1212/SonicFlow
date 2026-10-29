import Foundation
import Testing

@testable import SonicFlowCore

@Test func marksTheWordsCleanupRemoved() {
    let heard = TranscriptDiff.heard(
        raw: "Set a meeting on Wednesday, no wait, Thursday.", cleaned: "Set a meeting on Thursday."
    )
    #expect(heard.filter(\.removed).map(\.text) == ["Wednesday,", "no", "wait,"])
    #expect(heard.map(\.text).joined(separator: " ") == "Set a meeting on Wednesday, no wait, Thursday.")
}

@Test func punctuationAndCaseChangesKeepAWord() {
    #expect(TranscriptDiff.heard(raw: "ship it friday", cleaned: "Ship it Friday.").allSatisfy { !$0.removed })
}

@Test func historyKeepsTheRawTranscriptOnlyWhenCleanupChangedIt() throws {
    var history = History()
    history.record("Ship it Thursday.", latencyMs: 200, raw: "Ship it Friday, no wait, Thursday.")
    history.record("Hello.", latencyMs: 150, raw: "Hello.")
    #expect(history.entries.map(\.raw) == [nil, "Ship it Friday, no wait, Thursday."])

    let saved = #"{"capacity":500,"entries":[{"id":"7E57AB1E-0000-4000-8000-000000000001","text":"Hi","date":0,"latencyMs":1}]}"#
    let old = try JSONDecoder().decode(History.self, from: Data(saved.utf8))
    #expect(old.entries.first?.raw == nil)
}
