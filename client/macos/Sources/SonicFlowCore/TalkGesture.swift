import Foundation

public enum TalkEvent: Equatable {
    case start, stop, cancel
}

public enum TalkMode: String, CaseIterable, Codable, Sendable {
    case hold, toggle

    public var title: String {
        switch self {
        case .hold: "Hold to talk"
        case .toggle: "Tap to start, tap to stop"
        }
    }
}

/// Turns hotkey events into start/stop/cancel. Times are the key events' own timestamps, so a busy
/// main thread can't stretch a tap into a hold.
public protocol TalkGesture: AnyObject {
    func hotkeyDown(at time: TimeInterval) -> TalkEvent?
    func hotkeyUp(at time: TimeInterval) -> TalkEvent?
    /// Any other key, modifier, or click.
    func otherInput() -> TalkEvent?
    func escape() -> TalkEvent?
}

public func makeTalkGesture(_ mode: TalkMode) -> TalkGesture {
    switch mode {
    case .hold: HoldToTalk()
    case .toggle: TapToToggle()
    }
}

/// Talks while the hotkey is held. Other input cancels, so the hotkey still works as a modifier
/// (Option+arrow), and holds shorter than `minimumHold` cancel so a tap never pastes.
public final class HoldToTalk: TalkGesture {
    public let minimumHold: TimeInterval
    private var heldSince: TimeInterval?

    public init(minimumHold: TimeInterval = 0.3) {
        self.minimumHold = minimumHold
    }

    public func hotkeyDown(at time: TimeInterval) -> TalkEvent? {
        guard heldSince == nil else { return nil }
        heldSince = time
        return .start
    }

    public func hotkeyUp(at time: TimeInterval) -> TalkEvent? {
        guard let since = heldSince else { return nil }
        heldSince = nil
        return time - since < minimumHold ? .cancel : .stop
    }

    public func otherInput() -> TalkEvent? {
        guard heldSince != nil else { return nil }
        heldSince = nil
        return .cancel
    }

    public func escape() -> TalkEvent? { otherInput() }
}

/// A clean tap of the hotkey starts, the next clean tap stops, and Esc cancels. Taps that overlap
/// other input or last longer than `maximumTap` are the hotkey used as a modifier and are ignored.
public final class TapToToggle: TalkGesture {
    public let maximumTap: TimeInterval
    private var pressedAt: TimeInterval?
    private var pressIsClean = false
    private var talking = false

    public init(maximumTap: TimeInterval = 0.5) {
        self.maximumTap = maximumTap
    }

    public func hotkeyDown(at time: TimeInterval) -> TalkEvent? {
        if pressedAt == nil {
            pressedAt = time
            pressIsClean = true
        }
        return nil
    }

    public func hotkeyUp(at time: TimeInterval) -> TalkEvent? {
        guard let pressed = pressedAt else { return nil }
        pressedAt = nil
        guard pressIsClean, time - pressed <= maximumTap else { return nil }
        talking.toggle()
        return talking ? .start : .stop
    }

    public func otherInput() -> TalkEvent? {
        pressIsClean = false
        return nil
    }

    public func escape() -> TalkEvent? {
        pressIsClean = false
        guard talking else { return nil }
        talking = false
        return .cancel
    }
}
