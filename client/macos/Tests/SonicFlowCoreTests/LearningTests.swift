import Foundation
import Testing

@testable import SonicFlowCore

private let studio = LearnedWord(term: "Mac Studio", heard: "Mac Stoo videos")

@Test func repeatedFixesFoldIntoOneEntry() {
    var log = LearningLog()
    log.record([Correction(word: studio, hold: .sentenceStart)], at: Date(timeIntervalSince1970: 1))
    log.record([Correction(word: LearnedWord(term: "Qwen3", heard: "quen three"), hold: .unlike)])
    log.record([Correction(word: LearnedWord(term: "Mac Studio", heard: "mac stoo videos"), hold: .sentenceStart)])
    #expect(log.entries.map(\.term) == ["Mac Studio", "Qwen3"])
    #expect(log.entries[0].count == 2)
    #expect(log.suggestions.count == 2)
}

@Test func learningAFixOnItsOwnClearsItsSuggestion() {
    var log = LearningLog()
    log.record([Correction(word: studio, hold: .sentenceStart)])
    log.record([Correction(word: studio, hold: nil)])
    #expect(log.entries[0].status == .learned)
    #expect(log.entries[0].hold == nil)
}

@Test func aDismissedSuggestionStaysDismissed() {
    var log = LearningLog()
    log.record([Correction(word: studio, hold: .sentenceStart)])
    log.set(log.entries[0].id, to: .dismissed)
    log.record([Correction(word: studio, hold: .sentenceStart)])
    #expect(log.entries[0].status == .dismissed)
    #expect(log.suggestions.isEmpty)
}

@Test func theLogKeepsItsCapacityAndRetention() {
    var log = LearningLog(capacity: 2)
    let now = Date()
    log.record([Correction(word: LearnedWord(term: "Old", heard: "olde"), hold: nil)], at: now.addingTimeInterval(-3 * 86_400))
    log.record([Correction(word: LearnedWord(term: "Qwen3", heard: "quen three"), hold: .unlike)], at: now)
    log.record([Correction(word: studio, hold: nil)], at: now)
    #expect(log.entries.map(\.term) == ["Mac Studio", "Qwen3"])
    log.record([Correction(word: LearnedWord(term: "Old", heard: "olde"), hold: nil)], at: now.addingTimeInterval(-3 * 86_400))
    log.prune(keeping: .day, now: now)
    #expect(log.entries.map(\.term) == ["Mac Studio"])
}
