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
            CommandGroup(after: .sidebar) {
                ForEach(Array(Pane.allCases.enumerated()), id: \.element) { index, pane in
                    Button(pane.title) { appDelegate.mainWindow.show(pane) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
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
        Button("Paste Last Dictation") { controller.pasteLast() }
            .keyboardShortcut("v", modifiers: [.control, .command])
            .disabled(controller.history.entries.isEmpty)
        if !controller.history.entries.isEmpty {
            Menu("Recent Dictations") {
                ForEach(controller.history.entries) { entry in
                    Button(History.preview(entry.text)) { controller.copyFromHistory(entry) }
                }
                Divider()
                Text("Click to copy")
                Button("Clear History…") { confirmClear() }
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

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "Clear all dictation history?"
        alert.informativeText = controller.settings.saveHistory
            ? "This also deletes the saved copy on this Mac." : "This can't be undone."
        alert.addButton(withTitle: "Clear History").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { controller.clearHistory() }
    }
}
