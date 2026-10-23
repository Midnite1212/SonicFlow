import AVFoundation
import AppKit
import ApplicationServices

enum Permissions {
    struct Status: Equatable {
        var microphone: Bool
        var accessibility: Bool
    }

    enum Pane: String {
        case microphone = "Privacy_Microphone"
        case inputMonitoring = "Privacy_ListenEvent"
        case accessibility = "Privacy_Accessibility"
    }

    static func current() -> Status {
        Status(
            microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            accessibility: AXIsProcessTrusted()
        )
    }

    static func requestMissing() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }
        if !AXIsProcessTrusted() {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    static func openSettings(_ pane: Pane) {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)"
        )!
        NSWorkspace.shared.open(url)
    }
}
