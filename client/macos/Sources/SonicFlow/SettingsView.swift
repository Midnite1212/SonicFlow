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
    @Bindable var settings: AppSettings
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Hotkey", selection: $settings.hotkey) {
                    ForEach(Hotkey.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Mode", selection: $settings.talkMode) {
                    ForEach(TalkMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Text(modeHint).font(.caption).foregroundStyle(.secondary)
            }

            Section("Microphone") {
                Picker("Input", selection: $settings.inputDeviceUID) {
                    Text("System default").tag(String?.none)
                    ForEach(model.devices) { Text($0.name).tag(Optional($0.uid)) }
                }
                Toggle("Keep microphone ready", isOn: $settings.keepMicrophoneReady)
                Text(
                    "Starts instantly and keeps the moment before you press the hotkey. macOS shows "
                        + "the mic indicator while SonicFlow runs; audio outside a dictation is "
                        + "never sent."
                )
                .font(.caption).foregroundStyle(.secondary)
            }

            Section("Models") {
                if let backends = model.backends {
                    Picker("Speech recognition", selection: binding(\.asr, backends.asr.active)) {
                        ForEach(backends.asr.available, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Cleanup", selection: binding(\.cleanup, backends.cleanup.active)) {
                        ForEach(backends.cleanup.available, id: \.self) { Text($0).tag($0) }
                    }
                    .disabled(model.switching)
                } else {
                    Text("Engine not reachable").foregroundStyle(.secondary)
                }
                HStack {
                    if model.switching { ProgressView().controlSize(.small) }
                    if let engineMessage = model.engineMessage {
                        Text(engineMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restart Engine") { model.restartEngine() }
                }
            }

            Section("General") {
                Toggle(
                    "Launch SonicFlow at login",
                    isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })
                )
                if let loginMessage = model.loginMessage {
                    Text(loginMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await model.refresh() }
    }

    private var modeHint: String {
        switch settings.talkMode {
        case .hold:
            "Hold \(settings.hotkey.title) while speaking. A quick tap or using it with another key cancels."
        case .toggle:
            "Tap \(settings.hotkey.title) to start and again to stop. Esc cancels."
        }
    }

    private func binding(_ kind: KeyPath<Backends, Backends.Kind>, _ active: String) -> Binding<String> {
        Binding(
            get: { active },
            set: { choice in
                Task {
                    await model.switchBackend(asr: kind == \.asr ? choice : nil, cleanup: kind == \.cleanup ? choice : nil)
                }
            }
        )
    }
}
