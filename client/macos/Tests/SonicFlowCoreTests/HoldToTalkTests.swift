import Testing

@testable import SonicFlowCore

@Test func holdAndReleaseStops() {
    let hold = HoldToTalk(minimumHold: 0.3)
    #expect(hold.hotkeyDown(at: 10) == .start)
    #expect(hold.hotkeyUp(at: 11) == .stop)
}

@Test func shortTapCancelsEvenWhenHandledLate() {
    let hold = HoldToTalk(minimumHold: 0.3)
    _ = hold.hotkeyDown(at: 10)
    #expect(hold.hotkeyUp(at: 10.1) == .cancel)
}

@Test func usingHotkeyAsModifierCancelsOnce() {
    let hold = HoldToTalk(minimumHold: 0.3)
    _ = hold.hotkeyDown(at: 10)
    #expect(hold.otherInput() == .cancel)
    #expect(hold.hotkeyUp(at: 11) == nil)
}

@Test func repeatedDownDoesNotRestart() {
    let hold = HoldToTalk(minimumHold: 0.3)
    #expect(hold.hotkeyDown(at: 10) == .start)
    #expect(hold.hotkeyDown(at: 10.5) == nil)
    #expect(hold.hotkeyUp(at: 11) == .stop)
}

@Test func otherInputWhileIdleIsIgnored() {
    let hold = HoldToTalk(minimumHold: 0.3)
    #expect(hold.otherInput() == nil)
    #expect(hold.hotkeyUp(at: 10) == nil)
}
