import CoreGraphics

public enum Hotkey: String, CaseIterable, Codable, Sendable {
    case option, rightOption, rightCommand, control, fn

    public enum Input: Equatable {
        case down, up, other
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

    /// Classifies a `flagsChanged` event: the hotkey pressed alone, the hotkey released, or
    /// something else (another modifier, or the hotkey pressed together with one).
    public func classify(keyCode: Int64, flags: CGEventFlags) -> Input {
        guard keyCodes.contains(keyCode) else { return .other }
        guard flags.contains(flag) else { return .up }
        let others = flags.intersection(Self.modifiers).subtracting(flag)
        return others.isEmpty ? .down : .other
    }
}
