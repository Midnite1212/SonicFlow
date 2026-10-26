import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    let settingsModel = SettingsModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }
}

@main
struct SonicFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: appDelegate.controller)
        } label: {
            Image(systemName: appDelegate.controller.state.symbolName)
        }
        Settings {
            SettingsView(settings: appDelegate.controller.settings, model: appDelegate.settingsModel)
        }
    }
}

struct MenuContent: View {
    let controller: DictationController

    var body: some View {
        Text(controller.statusLine)
        if let latency = controller.lastLatencyMs {
            Text("Last dictation: \(Int(latency.rounded())) ms")
        }
        let permissions = controller.permissions
        if !permissions.microphone || !permissions.accessibility || !controller.hotkeyActive {
            Divider()
            if !permissions.microphone {
                Button("Allow Microphone…") { Permissions.openSettings(.microphone) }
            }
            if !controller.hotkeyActive {
                Button("Allow Input Monitoring…") { Permissions.openSettings(.inputMonitoring) }
            }
            if !permissions.accessibility {
                Button("Allow Accessibility…") { Permissions.openSettings(.accessibility) }
            }
        }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit SonicFlow") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
