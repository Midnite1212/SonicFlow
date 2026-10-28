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
