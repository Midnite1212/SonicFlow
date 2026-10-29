import Foundation
import Testing

@testable import SonicFlowCore

private let common: Set = ["deploy", "he", "hi", "left", "works", "the", "cube", "to", "on", "friday", "will", "send", "it", "rich", "e", "met",
                           "with", "bob", "alice", "sonic", "flow", "uses", "and", "review", "please", "a",
                           "were", "its", "meeting", "walk", "us", "know", "let", "did", "work", "ready", "going",
                           "are", "i", "home", "code", "is", "mac", "studio", "engine", "runs", "on", "today", "try", "smith", "fast", "said", "send", "now", "ask", "about", "thanks",
                           "may", "be", "maybe", "go", "video", "up", "ping", "next", "week", "open", "config",
                           "deploy", "he", "hi", "left", "works",
                           "that", "was", "fine", "dog", "ran", "then", "slept"]

private func learn(_ pasted: String, _ edited: String) -> [LearnedWord] {
    Corrections.learn(pasted: pasted, edited: edited) { common.contains($0) }
}

@Test func learnsAMisheardTermWithWhatWasHeard() {
    #expect(learn("Deploy the cube ernetes cluster.", "Deploy the Kubernetes cluster.")
        == [LearnedWord(term: "Kubernetes", heard: "cube ernetes")])
    #expect(learn("I met with rich e on Friday.", "I met with Richie on Friday.")
        == [LearnedWord(term: "Richie", heard: "rich e")])
}

@Test func caseOnlyFixNeedsNoHeardSpelling() {
    #expect(learn("Push it to github please.", "Push it to GitHub please.")
        == [LearnedWord(term: "GitHub", heard: nil)])
}

@Test func punctuationAndTrailingTypingAreNotCorrections() {
    #expect(learn("Send it on Friday", "Send it on Friday.").isEmpty)
    #expect(learn("Send it on Friday.", "Send it on Friday. Thanks Alice!").isEmpty)
    #expect(learn("Send it on Friday.", "Send it.").isEmpty)
}

@Test func rewordingAndCommonWordsAreNotLearned() {
    #expect(learn("I met with Bob on Friday.", "I met with Alice on Friday.").isEmpty)
    #expect(learn("It will send on Friday.", "It Will send on Friday.").isEmpty)
}

@Test func grammarFixesAreNotLearned() {
    #expect(learn("We were ready.", "We're ready.").isEmpty)
    #expect(learn("Its going well.", "It's going well.").isEmpty)
    #expect(learn("The meeting are done.", "The meetings are done.").isEmpty)
    #expect(learn("I walk home.", "I walked home.").isEmpty)
}

@Test func commonWordsInCapitalsAreNotLearned() {
    #expect(learn("Did it work?", "Did IT work?").isEmpty)
    #expect(learn("Let us know.", "Let US know.").isEmpty)
}

@Test func numbersAreNotLearned() {
    #expect(learn("The code is 4521.", "The code is 4512.").isEmpty)
}

@Test func soundAlikeNamesAreLearnedWhole() {
    #expect(learn("It runs on the Max Videos engine.", "It runs on the Mac Studio's engine.")
        == [LearnedWord(term: "Mac Studio", heard: "Max Videos")])
    #expect(learn("It runs on the Mac Stoo videos engine.", "It runs on the Mac Studio engine.")
        == [LearnedWord(term: "Mac Studio", heard: "Mac Stoo videos")])
}

@Test func uncertainFixesAreLeftAlone() {
    // A sentence's first word may be capitalized only because it starts the sentence.
    #expect(learn("Mac Stoo videos is fast.", "Mac Studio is fast.").isEmpty)
    // Short sound keys collide too easily to trust.
    #expect(learn("Try quen three today.", "Try Qwen3 today.").isEmpty)
}

@Test func renamesThatMerelySoundAlikeAreNotLearned() {
    #expect(learn("send it to the team now", "send it to Tim now").isEmpty)
    #expect(learn("Ask Chris about it.", "Ask Gus about it.").isEmpty)
    #expect(learn("Thanks Ian.", "Thanks Anne.").isEmpty)
    #expect(learn("Ask Jonathan about it.", "Ask Johnson about it.").isEmpty)
}

@Test func sentenceStartsAndIDoNotMakeANameOfAGrammarFix() {
    #expect(learn("May be I will go.", "Maybe I will go.").isEmpty)
    #expect(learn("The stoo video is up.", "The Studio video is up.").isEmpty)
    #expect(learn("Ping Bartholomew next week.", "Ping Bartholomew Monday.").isEmpty)
    #expect(learn(#"He said "Hi." Then stoo videos left."#, #"He said "Hi." Then Studio left."#).isEmpty)
    #expect(learn("It works… Then stoo videos left.", "It works… Then Studio left.").isEmpty)
}

@Test func textTypedStraightAfterAWordIsNotAFix() {
    #expect(learn("open the config", "open the config.yaml").isEmpty)
    #expect(learn("open a PR", "open a PRs").isEmpty)
    #expect(learn("deploy Kubernetes", "deploy Kubernetes:pw1").isEmpty)
}

@Test func capitalizingCommonWordsIsNotAName() {
    #expect(learn("I said that was fine.", "I said That Was fine.").isEmpty)
    #expect(learn("The dog ran. Then it slept.", "The dog ran. Then It slept.").isEmpty)
}

@Test func renamingSomeoneIsNotAMishearing() {
    #expect(learn("I met Bob Smith today.", "I met Alice Jones today.").isEmpty)
}

@Test func aRewrittenDictationTeachesNothing() {
    #expect(learn("Deploy the cube ernetes cluster on Friday.", "Kubernetes rollout postponed again, sorry.").isEmpty)
}

@Test func learnsSeveralFixesInOneDictation() {
    let learned = learn(
        "Sonic flow uses parakeet and quen three for review.",
        "SonicFlow uses Parakeet and quen three for review."
    )
    #expect(learned == [
        LearnedWord(term: "SonicFlow", heard: "Sonic flow"),
        LearnedWord(term: "Parakeet", heard: nil),
    ])
}

@Test func findsThePasteAtTheCaretAndReadsItBackAfterEdits() throws {
    let field = "Notes: Deploy the cube ernetes cluster. Deploy the cube ernetes cluster. Bye"
    let pasted = "Deploy the cube ernetes cluster."
    let caret = (field as NSString).range(of: pasted).upperBound
    let region = try #require(PastedRegion(pasted: pasted, in: field, caret: caret))
    #expect(region.prefix == "Notes: ")

    let edited = "Notes: Deploy the Kubernetes cluster. Deploy the cube ernetes cluster. Bye"
    #expect(region.text(in: edited) == "Deploy the Kubernetes cluster.")
    #expect(region.text(in: "Changed: Deploy the Kubernetes cluster.") == nil)
}

@Test func withoutTheCaretThePasteIsItsLastOccurrence() throws {
    let region = try #require(PastedRegion(pasted: "hi", in: "hi there, hi", caret: nil))
    #expect(region.prefix == "hi there, ")
    #expect(region.suffix == "")
    #expect(PastedRegion(pasted: "gone", in: "hi there", caret: 3) == nil)
}

@Test func learnedWordsAreAddedOnceAndExtendExistingTerms() {
    let existing = DictionaryTerm(term: "Kubernetes", heardAs: "cooper netties")
    var terms = DictionaryTerm.adding(
        [LearnedWord(term: "Kubernetes", heard: "cube ernetes"), LearnedWord(term: "Richie", heard: "rich e")],
        to: [existing]
    )
    #expect(terms.map(\.term) == ["Kubernetes", "Richie"])
    #expect(terms[0].heardAs == "cooper netties, cube ernetes")
    #expect(!terms[0].learned)
    #expect(terms[1].learned && terms[1].heardAs == "rich e")

    terms = DictionaryTerm.adding([LearnedWord(term: "Kubernetes", heard: "Cube Ernetes")], to: terms)
    #expect(terms[0].heardAs == "cooper netties, cube ernetes")
}

@Test func dictionarySavedBeforeLearningStillLoads() throws {
    let saved = #"[{"id":"7E57AB1E-0000-4000-8000-000000000001","term":"SonicFlow","heardAs":""}]"#
    let terms = try JSONDecoder().decode([DictionaryTerm].self, from: Data(saved.utf8))
    #expect(terms.first?.term == "SonicFlow")
    #expect(terms.first?.learned == false)
}
