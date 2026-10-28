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

    /// Off by default: dictated text stays in memory unless the user opts in.
    var saveHistory: Bool {
        didSet { save(saveHistory, "saveHistory") }
    }

    var historyRetention: HistoryRetention {
        didSet { save(historyRetention.rawValue, "historyRetention") }
    }

    /// Measured by the typing test; `nil` until the user takes it.
    var typingWordsPerMinute: Double? {
        didSet { save(typingWordsPerMinute, "typingWordsPerMinute") }
    }

    var onboarded: Bool {
        didSet { save(onboarded, "onboarded") }
    }

    init() {
        hotkey = defaults.string(forKey: "hotkey").flatMap(Hotkey.init(rawValue:)) ?? .option
        talkMode = defaults.string(forKey: "talkMode").flatMap(TalkMode.init(rawValue:)) ?? .hold
        inputDeviceUID = defaults.string(forKey: "inputDeviceUID")
        keepMicrophoneReady = defaults.bool(forKey: "keepMicrophoneReady")
        saveHistory = defaults.bool(forKey: "saveHistory")
        historyRetention =
            defaults.string(forKey: "historyRetention").flatMap(HistoryRetention.init(rawValue:)) ?? .week
        typingWordsPerMinute = defaults.object(forKey: "typingWordsPerMinute") as? Double
        onboarded = defaults.bool(forKey: "onboarded")
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}
