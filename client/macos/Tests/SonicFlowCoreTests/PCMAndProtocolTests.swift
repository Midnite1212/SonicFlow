import Foundation
import Testing

@testable import SonicFlowCore

@Test func int16ConversionScalesAndClamps() {
    let samples: [Float] = [-2, -1, 0, 0.5, 1, 2]
    let data = samples.withUnsafeBufferPointer(PCM.int16Data(from:))
    let values = data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }.map(Int16.init(littleEndian:))
    #expect(values == [-32767, -32767, 0, 16383, 32767, 32767])
}

@Test func levelOfSilenceIsZeroAndFullScaleIsOne() {
    #expect([Float](repeating: 0, count: 160).withUnsafeBufferPointer(PCM.level(of:)) == 0)
    #expect([Float](repeating: 1, count: 160).withUnsafeBufferPointer(PCM.level(of:)) == 1)
}

@Test func decodesFinal() {
    let json = #"{"type":"final","raw":"um hi","text":"Hi.","timings":{"asr_finalize_ms":110.5,"cleanup_ms":0.1,"total_ms":110.6}}"#
    guard case let .final(raw, text, timings) = ServerMessage.decode(json) else {
        Issue.record("expected final")
        return
    }
    #expect(raw == "um hi")
    #expect(text == "Hi.")
    #expect(timings.totalMs == 110.6)
}

@Test func decodesErrorAndRejectsUnknown() {
    #expect(ServerMessage.decode(#"{"type":"error","message":"nope"}"#) == .error(message: "nope"))
    #expect(ServerMessage.decode(#"{"type":"mystery"}"#) == nil)
    #expect(ServerMessage.decode("not json") == nil)
}

@Test func startMessageCarriesAppDictionaryAndSnippets() {
    let json = StartMessage.json(
        app: "com.tinyspeck.slackmacgap",
        dictionary: [
            DictionaryTerm(term: " SonicFlow ", heardAs: "sonic flow, , sonic flo"),
            DictionaryTerm(term: "  ", heardAs: "ignored"),
        ],
        snippets: [Snippet(trigger: "my email", text: "r@example.com"), Snippet(trigger: "empty")]
    )
    #expect(
        json == #"{"app":"com.tinyspeck.slackmacgap","dictionary":[{"heard":["sonic flow","sonic flo"],"term":"SonicFlow"}],"snippets":[{"text":"r@example.com","trigger":"my email"}],"style":"standard","type":"start"}"#
    )
}

@Test func startMessageWithoutAppOmitsIt() {
    #expect(StartMessage.json(app: nil, dictionary: [], snippets: []) == #"{"dictionary":[],"snippets":[],"style":"standard","type":"start"}"#)
}

@Test func stopWithSelectionEscapesText() {
    #expect(ServerMessage.stop(selection: "say \"hi\"\n") == #"{"selection":"say \"hi\"\n","type":"stop"}"#)
}

@Test func startMessageAsksForPartialsOnlyWhenShown() {
    #expect(StartMessage.json(app: nil, dictionary: [], snippets: [], partials: true).contains(#""partials":true"#))
    #expect(!StartMessage.json(app: nil, dictionary: [], snippets: []).contains("partials"))
}
