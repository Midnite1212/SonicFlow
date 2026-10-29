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
    var sharing: SharingStatus?
    var sharingMessage: String?
    var pairing: PairingModel?

    func refresh() async {
        devices = AudioDevices.inputs()
        await loadBackends()
        sharing = try? await EngineAPI.sharing()
    }

    func setSharing(_ enabled: Bool) async {
        await updateSharing { try await EngineAPI.setSharing(enabled) }
    }

    func resetSharing() async {
        await updateSharing { try await EngineAPI.resetSharing() }
    }

    private func updateSharing(_ change: () async throws -> SharingStatus) async {
        do {
            sharing = try await change()
            sharingMessage = nil
        } catch {
            sharingMessage = error.localizedDescription
        }
    }

    func copyPairingCode() {
        guard let code = sharing?.code else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
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
                Seam()
                GlassRow(
                    "Learn words from your corrections",
                    hint: "When you fix a misheard name or term right after pasting, it's added to your "
                        + "Dictionary. The text you edit is read only to compare and is never saved."
                ) {
                    Toggle("Learn words from your corrections", isOn: $settings.learnFromCorrections).rowSwitch()
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
                GlassRow("Runs on \(controller.activeEngine.displayName)", hint: engineHint) {
                    if controller.pairedEngine == nil {
                        Button("Pair with Another Mac…") { model.pairing = PairingModel() }
                    } else {
                        Button("Unpair") { controller.unpair() }
                    }
                }
                Seam()
                GlassRow("Share this Mac's engine", hint: model.sharingMessage ?? sharingHint) {
                    Toggle(
                        "Share this Mac's engine",
                        isOn: Binding(
                            get: { model.sharing?.enabled ?? false },
                            set: { enabled in Task { await model.setSharing(enabled) } }
                        )
                    )
                    .rowSwitch()
                    .disabled(model.sharing == nil)
                }
                if model.sharing?.enabled == true {
                    Seam()
                    GlassRow(
                        "Pairing code",
                        hint: "Paste it into Settings on the other Mac. Reset unpairs every Mac using it."
                    ) {
                        HStack {
                            Button("Reset") { Task { await model.resetSharing() } }
                            Button("Copy") { model.copyPairingCode() }
                        }
                    }
                }
                Seam()
                GlassRow("Models", hint: "Choose, download and add speech and cleanup models.") {
                    Button("Open Models") { navigation.pane = .models }
                }
                Seam()
                GlassRow("Engine on this Mac", hint: model.engineMessage) {
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
        .task(id: controller.activeEngine) { await model.refresh() }
        .sheet(item: $model.pairing) { pairing in
            PairingView(model: pairing) { code in
                try await controller.pair(code: code)
                model.pairing = nil
            } cancel: {
                model.pairing = nil
            }
        }
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

    private var engineHint: String {
        guard let paired = controller.pairedEngine else {
            return "Pair with a faster Mac on your network to dictate with its models."
        }
        return controller.activeEngine == paired
            ? "When \(paired.displayName) can't be reached, dictation runs on this Mac."
            : "\(paired.displayName) can't be reached, so dictation runs on this Mac until it can."
    }

    private var sharingHint: String {
        guard let sharing = model.sharing, sharing.enabled, let host = sharing.host, let port = sharing.port else {
            return "Lets Macs you pair dictate with this Mac's models. Their audio arrives encrypted."
        }
        return "Shared as \(host), port \(port)."
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
