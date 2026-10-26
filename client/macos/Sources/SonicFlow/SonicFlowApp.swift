import AppKit
import SonicFlowCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    let settingsModel = SettingsModel()
    lazy var mainWindow = MainWindow(controller: controller, settingsModel: settingsModel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        if !controller.settings.onboarded {
            mainWindow.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return false
    }
}

@main
struct SonicFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: appDelegate.controller) { appDelegate.mainWindow.show($0) }
        } label: {
            Image(systemName: appDelegate.controller.state.symbolName)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { appDelegate.mainWindow.show(.settings) }
                    .keyboardShortcut(",")
            }
        }
    }
}

struct MenuContent: View {
    let controller: DictationController
    let open: (Pane?) -> Void

    var body: some View {
        Text(controller.statusLine)
        if let latency = controller.lastLatencyMs {
            Text("Last dictation: \(Int(latency.rounded())) ms")
        }
        if !controller.history.entries.isEmpty {
            Menu("Recent Dictations") {
                ForEach(controller.history.entries) { entry in
                    Button(History.preview(entry.text)) { controller.copyFromHistory(entry) }
                }
                Divider()
                Text("Click to copy · kept in memory only")
                Button("Clear") { controller.clearHistory() }
            }
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
        Button("Open SonicFlow") { open(.home) }
            .keyboardShortcut("o")
        Button("History…") { open(.history) }
        Button("Settings…") { open(.settings) }
            .keyboardShortcut(",")
        Button("Quit SonicFlow") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
