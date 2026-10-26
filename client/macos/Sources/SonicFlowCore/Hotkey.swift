import CoreGraphics

public enum Hotkey: String, CaseIterable, Codable, Sendable {
    case option, rightOption, rightCommand, control, fn

    public enum Input: Equatable {
        /// `downCommand` is the hotkey pressed while Shift is held; `command` is Shift pressed
        /// while the hotkey is held. Both ask for command mode. `ignored` is Shift released.
        case down, downCommand, command, ignored, up, other
    }

    public var title: String {
        switch self {
        case .option: "Option (either)"
        case .rightOption: "Right Option"
        case .rightCommand: "Right Command"
        case .control: "Control (either)"
        case .fn: "Fn / Globe"
        }
    }

    var keyCodes: Set<Int64> {
        switch self {
        case .option: [58, 61]
        case .rightOption: [61]
        case .rightCommand: [54]
        case .control: [59, 62]
        case .fn: [63]
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .option, .rightOption: .maskAlternate
        case .rightCommand: .maskCommand
        case .control: .maskControl
        case .fn: .maskSecondaryFn
        }
    }

    private static let modifiers: CGEventFlags = [
        .maskAlternate, .maskCommand, .maskControl, .maskShift, .maskSecondaryFn,
    ]

    private static let shiftKeyCodes: Set<Int64> = [56, 60]

    /// Classifies a `flagsChanged` event: the hotkey pressed or released, Shift joining or leaving
    /// it, or something else (any other modifier combination).
    public func classify(keyCode: Int64, flags: CGEventFlags) -> Input {
        let others = flags.intersection(Self.modifiers).subtracting(flag)
        if keyCodes.contains(keyCode) {
            guard flags.contains(flag) else { return .up }
            if others.isEmpty { return .down }
            return others == .maskShift ? .downCommand : .other
        }
        if Self.shiftKeyCodes.contains(keyCode), flags.contains(flag),
            others.subtracting(.maskShift).isEmpty
        {
            return flags.contains(.maskShift) ? .command : .ignored
        }
        return .other
    }
}
