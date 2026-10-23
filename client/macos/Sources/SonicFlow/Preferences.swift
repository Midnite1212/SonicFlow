import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    static var keepMicrophoneReady: Bool {
        get { defaults.object(forKey: "keepMicrophoneReady") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "keepMicrophoneReady") }
    }
}
