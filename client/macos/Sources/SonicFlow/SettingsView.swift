import Observation
import ServiceManagement
import SonicFlowCore
import SwiftUI

/// Window state lives here rather than in `@State`, which needs a macro plugin the Command Line
/// Tools don't ship.
@MainActor
@Observable
final class SettingsModel {
    var devices: [AudioInputDevice] = []
    var backends: Backends?
    var engineMessage: String?
    var switching = false
    var launchAtLogin = SMAppService.mainApp.status == .enabled
    var loginMessage: String?
    var confirmingClear = false
    var typingTest: TypingTestModel?

    func refresh() async {
        devices = AudioDevices.inputs()
        await loadBackends()
    }

    func loadBackends() async {
        backends = try? await EngineAPI.backends()
    }

    func switchBackend(asr: String?, cleanup: String?) async {
        switching = true
        engineMessage = "Loading \(asr ?? cleanup ?? "")…"
        do {
            _ = try await EngineAPI.configure(asr: asr, cleanup: cleanup)
            engineMessage = nil
        } catch {
            engineMessage = error.localizedDescription
        }
        await loadBackends()
        switching = false
    }

    func restartEngine() {
        do {
            try EngineAPI.restart()
            engineMessage = "Restarting…"
            Task {
                try? await Task.sleep(for: .seconds(8))
                await loadBackends()
                engineMessage = backends == nil ? "Engine still starting" : nil
            }
        } catch {
            engineMessage = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginMessage =
                SMAppService.mainApp.status == .requiresApproval
                ? "Approve SonicFlow in System Settings → General → Login Items." : nil
        } catch {
            loginMessage = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct SettingsView: View {
    let controller: DictationController
    @Bindable var settings: AppSettings
    @Bindable var model: SettingsModel
    let navigation: Navigation

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Hotkey", selection: $settings.hotkey) {
                    ForEach(Hotkey.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker(selection: $settings.talkMode) {
                    ForEach(TalkMode.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Mode")
                    Text(modeHint)
                }
            }
            Section("Microphone") {
                Picker("Input", selection: $settings.inputDeviceUID) {
                    Text("System default").tag(String?.none)
                    ForEach(model.devices) { Text($0.name).tag(Optional($0.uid)) }
                }
                Toggle(isOn: $settings.keepMicrophoneReady) {
                    Text("Keep microphone ready")
                    Text(
                        "Keeps the moment before you press the hotkey and skips the mic's start-up delay "
                            + "(up to 0.2 s on some USB mics). macOS shows the mic indicator the whole time; "
                            + "audio outside a dictation is never sent."
                    )
                }
            }
            Section("History") {
                Toggle(isOn: $settings.saveHistory) {
                    Text("Save history on this Mac")
                    Text(
                        settings.saveHistory
                            ? "Saved in Application Support, readable only by you."
                            : "Kept in memory until SonicFlow quits. Nothing is written to disk."
                    )
                }
                Picker("Keep for", selection: $settings.historyRetention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!settings.saveHistory)
                LabeledContent("Dictation history") {
                    Button("Clear History…") { model.confirmingClear = true }
                        .disabled(controller.history.entries.isEmpty)
                }
            }
            Section("Typing speed") {
                LabeledContent {
                    Button(settings.typingWordsPerMinute == nil ? "Take Typing Test…" : "Retake Test…") {
                        model.typingTest = TypingTestModel()
                    }
                } label: {
                    if let speed = settings.typingWordsPerMinute {
                        Text("\(Int(speed.rounded())) wpm")
                        Text("Time saved compares dictating with typing at your own speed.")
                    } else {
                        Text("Not measured")
                        Text("Time saved assumes an average typist at \(Int(TypingTest.averageWordsPerMinute)) wpm until you take the one-minute test.")
                    }
                }
            }
            Section("Engine") {
                LabeledContent {
                    Button("Open Models") { navigation.pane = .models }
                } label: {
                    Text("Models")
                    Text("Choose, download and add speech and cleanup models.")
                }
                LabeledContent {
                    Button("Restart") { model.restartEngine() }
                } label: {
                    Text("Speech engine")
                    if let engineMessage = model.engineMessage { Text(engineMessage) }
                }
            }
            Section("General") {
                Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                    Text("Launch SonicFlow at login")
                    if let message = model.loginMessage { Text(message) }
                }
            }
        }
        .settingsForm()
        .navigationTitle("Settings")
        .task { await model.refresh() }
        .sheet(item: $model.typingTest) { test in
            TypingTestView(model: test) { speed in
                settings.typingWordsPerMinute = speed
                model.typingTest = nil
            } cancel: {
                model.typingTest = nil
            }
        }
        .confirmationDialog("Clear all dictation history?", isPresented: $model.confirmingClear) {
            Button("Clear History", role: .destructive) { controller.clearHistory() }
        } message: {
            Text(settings.saveHistory ? "This also deletes the saved copy on this Mac." : "This can't be undone.")
        }
    }

    private var modeHint: String {
        switch settings.talkMode {
        case .hold:
            "Hold \(settings.hotkey.title) while speaking. A quick tap or using it with another key cancels. Add Shift to edit selected text by voice."
        case .toggle:
            "Tap \(settings.hotkey.title) to start and again to stop. Esc cancels. Press Shift while talking to edit selected text by voice."
        }
    }
}
