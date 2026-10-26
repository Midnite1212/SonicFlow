import CoreGraphics
import Foundation
import Testing

@testable import SonicFlowCore

@Test func optionAloneIsDownAndReleaseIsUp() {
    #expect(Hotkey.option.classify(keyCode: 58, flags: .maskAlternate) == .down)
    #expect(Hotkey.option.classify(keyCode: 61, flags: .maskAlternate) == .down)
    #expect(Hotkey.option.classify(keyCode: 58, flags: []) == .up)
}

@Test func hotkeyWithAnotherModifierIsOther() {
    #expect(Hotkey.option.classify(keyCode: 58, flags: [.maskAlternate, .maskCommand]) == .other)
    #expect(Hotkey.rightCommand.classify(keyCode: 54, flags: [.maskCommand, .maskShift]) == .other)
}

@Test func rightOptionIgnoresLeftOption() {
    #expect(Hotkey.rightOption.classify(keyCode: 58, flags: .maskAlternate) == .other)
    #expect(Hotkey.rightOption.classify(keyCode: 61, flags: .maskAlternate) == .down)
}

@Test func otherModifierKeysAreOther() {
    #expect(Hotkey.option.classify(keyCode: 56, flags: .maskShift) == .other)
    #expect(Hotkey.fn.classify(keyCode: 63, flags: .maskSecondaryFn) == .down)
}

@Test func decodesBackends() throws {
    let json = #"{"asr":{"active":"parakeet-v2","available":["parakeet-v2","whisper-turbo"]},"cleanup":{"active":"qwen3-4b","available":["none","qwen3-4b"]}}"#
    let backends = try JSONDecoder().decode(Backends.self, from: Data(json.utf8))
    #expect(backends.asr.active == "parakeet-v2")
    #expect(backends.cleanup.available == ["none", "qwen3-4b"])
}
