import Foundation
import Observation
import SonicFlowCore

/// User choices persisted in UserDefaults. `onChange` lets the controller apply them live.
@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults = UserDefaults.standard

    var hotkey: Hotkey {
        didSet { save(hotkey.rawValue, "hotkey") }
    }

    var talkMode: TalkMode {
        didSet { save(talkMode.rawValue, "talkMode") }
    }

    /// `nil` follows the system default input.
    var inputDeviceUID: String? {
        didSet { save(inputDeviceUID, "inputDeviceUID") }
    }

    var keepMicrophoneReady: Bool {
        didSet { save(keepMicrophoneReady, "keepMicrophoneReady") }
    }

    init() {
        hotkey = defaults.string(forKey: "hotkey").flatMap(Hotkey.init(rawValue:)) ?? .option
        talkMode = defaults.string(forKey: "talkMode").flatMap(TalkMode.init(rawValue:)) ?? .hold
        inputDeviceUID = defaults.string(forKey: "inputDeviceUID")
        keepMicrophoneReady = defaults.object(forKey: "keepMicrophoneReady") as? Bool ?? true
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}
