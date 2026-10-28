import Testing

@testable import SonicFlowCore

@Test func typingSpeedCountsCorrectWordsFiveCharactersToAWord() {
    let passage = "the quick brown fox"
    #expect(TypingTest.wordsPerMinute(typed: passage, passage: passage, seconds: 12) == 19.0 / 5 / 0.2)
    #expect(TypingTest.wordsPerMinute(typed: "the quikc brown fox", passage: passage, seconds: 12) == 13.0 / 5 / 0.2)
    #expect(TypingTest.wordsPerMinute(typed: "the qu", passage: passage, seconds: 12) == 6.0 / 5 / 0.2)
    #expect(TypingTest.wordsPerMinute(typed: "", passage: passage, seconds: 0) == 0)
}

@Test func typingTimeScalesWithSpeed() {
    #expect(TypingTest.secondsToType(words: 20, wordsPerMinute: 40) == 30)
    #expect(UsageStats.Totals().timeSavedSeconds() == 0)
}

@Test func typingMarksEachWordAgainstItsOwnTarget() {
    let marks = TypingTest.marks(typed: "teh quick", passage: "the quick fox")
    #expect(marks[0].map(\.mark) == [.correct, .wrong, .wrong])
    #expect(marks[1].map(\.mark) == Array(repeating: .correct, count: 5))
    #expect(marks[2].map(\.mark) == [.pending, .pending, .pending])

    let skipped = TypingTest.marks(typed: "th quickk ", passage: "the quick fox")
    #expect(skipped[0].map(\.mark) == [.correct, .correct, .missed])
    #expect(skipped[1].map(\.mark).suffix(2) == [.correct, .extra])
}

@Test func typingFinishesOnTheLastWordOrTheSpaceAfterIt() {
    #expect(!TypingTest.isFinished(typed: "the quick fo", passage: "the quick fox"))
    #expect(TypingTest.isFinished(typed: "the quick fox", passage: "the quick fox"))
    #expect(!TypingTest.isFinished(typed: "the quick fxo", passage: "the quick fox"))
    #expect(TypingTest.isFinished(typed: "the quick fxo ", passage: "the quick fox"))
    #expect(TypingTest.normalized(" the  quick") == "the quick")
}
