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
        Group {
            GlassSection("Dictation") {
                GlassRow("Hotkey") {
                    Picker("Hotkey", selection: $settings.hotkey) {
                        ForEach(Hotkey.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .rowPicker()
                }
                Seam()
                GlassRow("Mode", hint: modeHint) {
                    Picker("Mode", selection: $settings.talkMode) {
                        ForEach(TalkMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .rowPicker()
                }
            }
            GlassSection("Microphone") {
                GlassRow("Input") {
                    Picker("Input", selection: $settings.inputDeviceUID) {
                        Text("System default").tag(String?.none)
                        ForEach(model.devices) { Text($0.name).tag(Optional($0.uid)) }
                    }
                    .rowPicker()
                }
                Seam()
                GlassRow(
                    "Keep microphone ready",
                    hint: "Keeps the moment before you press the hotkey and skips the mic's start-up delay "
                        + "(up to 0.2 s on some USB mics). macOS shows the mic indicator the whole time; "
                        + "audio outside a dictation is never sent."
                ) {
                    Toggle("Keep microphone ready", isOn: $settings.keepMicrophoneReady).rowSwitch()
                }
            }
            GlassSection("History") {
                GlassRow(
                    "Save history on this Mac",
                    hint: settings.saveHistory
                        ? "Saved in Application Support, readable only by you."
                        : "Kept in memory until SonicFlow quits. Nothing is written to disk."
                ) {
                    Toggle("Save history on this Mac", isOn: $settings.saveHistory).rowSwitch()
                }
                Seam()
                GlassRow("Keep for") {
                    Picker("Keep for", selection: $settings.historyRetention) {
                        ForEach(HistoryRetention.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .rowPicker()
                    .disabled(!settings.saveHistory)
                }
                Seam()
                GlassRow("Dictation history") {
                    Button("Clear History…") { model.confirmingClear = true }
                        .disabled(controller.history.entries.isEmpty)
                }
            }
            GlassSection("Typing speed") {
                GlassRow(
                    settings.typingWordsPerMinute.map { "\(Int($0.rounded())) wpm" } ?? "Not measured",
                    hint: settings.typingWordsPerMinute == nil
                        ? "Time saved assumes an average typist at \(Int(TypingTest.averageWordsPerMinute)) wpm until you take the one-minute test."
                        : "Time saved compares dictating with typing at your own speed."
                ) {
                    Button(settings.typingWordsPerMinute == nil ? "Take Typing Test…" : "Retake Test…") {
                        model.typingTest = TypingTestModel()
                    }
                }
            }
            GlassSection("Engine") {
                GlassRow("Models", hint: "Choose, download and add speech and cleanup models.") {
                    Button("Open Models") { navigation.pane = .models }
                }
                Seam()
                GlassRow("Speech engine", hint: model.engineMessage) {
                    Button("Restart") { model.restartEngine() }
                }
            }
            GlassSection("General") {
                GlassRow("Launch SonicFlow at login", hint: model.loginMessage) {
                    Toggle(
                        "Launch SonicFlow at login",
                        isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })
                    )
                    .rowSwitch()
                }
            }
        }
        .glassColumn()
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
