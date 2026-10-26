import Testing

@testable import SonicFlowCore

@Test func holdAndReleaseStops() {
    let hold = HoldToTalk(minimumHold: 0.3)
    #expect(hold.hotkeyDown(at: 10) == .start)
    #expect(hold.hotkeyUp(at: 11) == .stop)
}

@Test func holdShortTapCancelsEvenWhenHandledLate() {
    let hold = HoldToTalk(minimumHold: 0.3)
    _ = hold.hotkeyDown(at: 10)
    #expect(hold.hotkeyUp(at: 10.1) == .cancel)
}

@Test func holdUsedAsModifierCancelsOnce() {
    let hold = HoldToTalk(minimumHold: 0.3)
    _ = hold.hotkeyDown(at: 10)
    #expect(hold.otherInput() == .cancel)
    #expect(hold.hotkeyUp(at: 11) == nil)
}

@Test func holdRepeatedDownDoesNotRestart() {
    let hold = HoldToTalk(minimumHold: 0.3)
    #expect(hold.hotkeyDown(at: 10) == .start)
    #expect(hold.hotkeyDown(at: 10.5) == nil)
    #expect(hold.hotkeyUp(at: 11) == .stop)
}

@Test func holdIgnoresOtherInputWhileIdle() {
    let hold = HoldToTalk(minimumHold: 0.3)
    #expect(hold.otherInput() == nil)
    #expect(hold.hotkeyUp(at: 10) == nil)
}

@Test func toggleTapStartsAndNextTapStops() {
    let toggle = TapToToggle(maximumTap: 0.5)
    #expect(toggle.hotkeyDown(at: 10) == nil)
    #expect(toggle.hotkeyUp(at: 10.1) == .start)
    #expect(toggle.hotkeyDown(at: 14) == nil)
    #expect(toggle.hotkeyUp(at: 14.1) == .stop)
}

@Test func toggleIgnoresHotkeyUsedAsModifier() {
    let toggle = TapToToggle(maximumTap: 0.5)
    _ = toggle.hotkeyDown(at: 10)
    _ = toggle.otherInput()
    #expect(toggle.hotkeyUp(at: 10.1) == nil)
}

@Test func toggleIgnoresLongPress() {
    let toggle = TapToToggle(maximumTap: 0.5)
    _ = toggle.hotkeyDown(at: 10)
    #expect(toggle.hotkeyUp(at: 11) == nil)
}

@Test func toggleKeepsTalkingThroughTypingAndEscapeCancels() {
    let toggle = TapToToggle(maximumTap: 0.5)
    _ = toggle.hotkeyDown(at: 10)
    _ = toggle.hotkeyUp(at: 10.1)
    #expect(toggle.otherInput() == nil)
    #expect(toggle.escape() == .cancel)
    #expect(toggle.escape() == nil)
}
