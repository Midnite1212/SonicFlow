import Foundation

/// Turns raw key events into start/stop/cancel for a hold-to-talk hotkey.
///
/// Any other key or modifier while the hotkey is held cancels, so the hotkey keeps working as a
/// modifier (Option+arrow). Holds shorter than `minimumHold` also cancel, so a tap never pastes.
/// Times are the key events' own timestamps, so a busy main thread can't stretch a tap into a hold.
public final class HoldToTalk {
    public enum Event: Equatable {
        case start, stop, cancel
    }

    public let minimumHold: TimeInterval
    private var heldSince: TimeInterval?

    public init(minimumHold: TimeInterval = 0.3) {
        self.minimumHold = minimumHold
    }

    public var isActive: Bool { heldSince != nil }

    public func hotkeyDown(at time: TimeInterval) -> Event? {
        guard heldSince == nil else { return nil }
        heldSince = time
        return .start
    }

    public func hotkeyUp(at time: TimeInterval) -> Event? {
        guard let since = heldSince else { return nil }
        heldSince = nil
        return time - since < minimumHold ? .cancel : .stop
    }

    public func otherInput() -> Event? {
        guard heldSince != nil else { return nil }
        heldSince = nil
        return .cancel
    }
}
