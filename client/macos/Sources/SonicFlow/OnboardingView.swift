import AppKit
import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome, permissions, engine, hotkey, done
    }

    var step = Step.welcome
    var practiceText = ""

    func advance() {
        step = Step(rawValue: step.rawValue + 1) ?? .done
    }

    func back() {
        step = Step(rawValue: step.rawValue - 1) ?? .welcome
    }
}

struct OnboardingView: View {
    let controller: DictationController
    @Bindable var settings: AppSettings
    let settingsModel: SettingsModel
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            Seam()
            footer.padding(16)
        }
        .foregroundStyle(Theme.text)
        .background(AmbientLight())
        .navigationTitle("SonicFlow")
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome: welcome
        case .permissions: permissions
        case .engine: engine
        case .hotkey: hotkey
        case .done: done
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(OnboardingModel.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(step == model.step ? Theme.text : Theme.seam)
                        .frame(width: 7, height: 7)
                }
            }
            Spacer()
            if model.step != .welcome {
                Button("Back") { model.back() }
            }
            if model.step == .done {
                Button("Open SonicFlow") { settings.onboarded = true }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(model.step == .welcome ? "Get Started" : "Continue") { model.advance() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            AppIcon(size: 128)
            Text("Welcome to SonicFlow").font(.largeTitle.weight(.semibold))
            Text(
                "Hold a key, speak, and clean text appears wherever you're typing. Speech recognition and "
                    + "cleanup run on this Mac; audio never leaves it."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.secondary)
        }
    }

    private var permissions: some View {
        let status = controller.permissions
        return VStack(alignment: .leading, spacing: 20) {
            StepTitle("Allow access", "macOS asks once for each. SonicFlow notices as soon as you allow them.")
            PermissionRow(
                title: "Microphone", detail: "Hear you while the hotkey is held.",
                granted: status.microphone
            ) {
                Permissions.requestMissing()
                Permissions.openSettings(.microphone)
            }
            PermissionRow(
                title: "Input Monitoring", detail: "Notice the dictation hotkey in any app.",
                granted: controller.hotkeyActive
            ) { Permissions.openSettings(.inputMonitoring) }
            PermissionRow(
                title: "Accessibility", detail: "Paste the text into the app you're using.",
                granted: status.accessibility
            ) { Permissions.openSettings(.accessibility) }
        }
    }

    private var engine: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepTitle("Speech engine", "The engine runs in the background on this Mac and starts at login.")
            if controller.state == .offline {
                Label("Engine not running", systemImage: "xmark.circle.fill").foregroundStyle(Theme.alert)
                Text("Run scripts/install.sh from the SonicFlow folder once, or restart it here.")
                    .foregroundStyle(Theme.secondary)
                Button("Restart Engine") { settingsModel.restartEngine() }
                if let message = settingsModel.engineMessage {
                    Text(message).font(.caption).foregroundStyle(Theme.tertiary)
                }
            } else {
                Label("Engine running", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.ready)
                if let backends = settingsModel.backends {
                    LabeledContent("Speech recognition", value: backends.asr.active)
                    LabeledContent("Cleanup", value: backends.cleanup.active)
                }
                Text("You can switch models later in Settings.").foregroundStyle(Theme.secondary)
            }
        }
        .task { await settingsModel.loadBackends() }
    }

    private var hotkey: some View {
        let latest = model.practiceText.isEmpty ? nil : controller.history.entries.first
        return VStack(alignment: .leading, spacing: 20) {
            StepTitle("Pick your hotkey", "Then click in the box below, hold it, and say something.")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Hotkey").foregroundStyle(Theme.secondary)
                    Picker("Hotkey", selection: $settings.hotkey) {
                        ForEach(Hotkey.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }
                GridRow {
                    Text("Mode").foregroundStyle(Theme.secondary)
                    Picker("Mode", selection: $settings.talkMode) {
                        ForEach(TalkMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.practiceText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                if model.practiceText.isEmpty {
                    Text("Hold \(settings.hotkey.title) and say something…")
                        .foregroundStyle(Theme.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 100)
            .padding(8)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.seam))
            HStack(spacing: 12) {
                Text("Release to text").foregroundStyle(Theme.secondary)
                SpeedStripe(ms: latest?.latencyMs, height: 6, showsInstant: true)
                Text(latest.map { Format.ms($0.latencyMs) } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(latest.map { Theme.Speed(ms: $0.latencyMs).text } ?? Theme.tertiary)
                    .frame(width: 64, alignment: .trailing)
            }
            .font(.callout)
        }
    }

    private var done: some View {
        VStack(spacing: 16) {
            AppIcon(size: 96)
            Text("You're set").font(.largeTitle.weight(.semibold))
            Text(
                "SonicFlow lives in the menu bar (\(Image(systemName: "waveform"))). Open this window from "
                    + "there to see your stats, history, and settings."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.secondary)
        }
    }
}

private struct StepTitle: View {
    let title: String
    let detail: String

    init(_ title: String, _ detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title.weight(.semibold))
            Text(detail).foregroundStyle(Theme.secondary)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let allow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(granted ? Theme.ready : Theme.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(Theme.secondary)
            }
            Spacer()
            if !granted {
                Button("Allow…", action: allow)
            }
        }
    }
}
