import AppKit
import Observation
import SonicFlowCore

enum DictationState {
    case offline, idle, listening, processing

    var symbolName: String {
        switch self {
        case .offline: "waveform.slash"
        case .idle: "waveform"
        case .listening: "mic.fill"
        case .processing: "ellipsis"
        }
    }
}

@MainActor
@Observable
final class DictationController {
    private(set) var state: DictationState = .offline
    private(set) var lastLatencyMs: Double?
    private(set) var permissions = Permissions.current()
    private(set) var hotkeyActive = false

    var statusLine: String {
        switch state {
        case .offline: "Engine offline"
        case .idle: "Ready — hold Option to dictate"
        case .listening: "Listening…"
        case .processing: "Processing…"
        }
    }

    @ObservationIgnored private let hold = HoldToTalk()
    @ObservationIgnored private let audio = AudioCapture()
    @ObservationIgnored private let engine = EngineClient(
        url: URL(string: "ws://127.0.0.1:8765/v1/dictate")!
    )
    @ObservationIgnored private let pill = PillController()
    @ObservationIgnored private var hotkey: HotkeyMonitor?
    @ObservationIgnored private var connected = false
    @ObservationIgnored private var releasedAt: TimeInterval = 0
    @ObservationIgnored private var permissionTimer: Timer?

    func start() {
        Permissions.requestMissing()

        engine.onConnectionChange = { [weak self] isConnected in
            Task { @MainActor in self?.connectionChanged(isConnected) }
        }
        audio.onChunk = { [engine] chunk in engine.sendAudio(chunk) }
        audio.onLevel = { [weak self] level in
            Task { @MainActor in self?.pill.model.push(level) }
        }
        engine.connect()
        applyMicrophonePreference()
        installHotkey()

        // Grants made in System Settings don't notify the app, so poll until everything is allowed.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    private func applyMicrophonePreference() {
        guard permissions.microphone else { return }
        let warm = Preferences.keepMicrophoneReady
        if audio.keepWarm != warm {
            audio.setKeepWarm(warm)
            Log.event("microphone \(warm ? "kept ready" : "started on press")")
        }
    }

    private func refreshPermissions() {
        permissions = Permissions.current()
        applyMicrophonePreference()
        installHotkey()
        if permissions.microphone, permissions.accessibility, hotkeyActive {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    /// Either Input Monitoring or Accessibility lets the tap start, so the tap is the real check.
    private func installHotkey() {
        guard hotkey == nil else { return }
        let monitor = HotkeyMonitor { [weak self] input in
            Task { @MainActor in self?.handle(input) }
        }
        guard monitor.start() else {
            Log.event("hotkey tap unavailable; waiting for permission")
            return
        }
        hotkey = monitor
        hotkeyActive = true
        Log.event("hotkey tap installed")
    }

    private func connectionChanged(_ isConnected: Bool) {
        Log.event("engine \(isConnected ? "connected" : "disconnected")")
        connected = isConnected
        if state == .idle || state == .offline {
            state = isConnected ? .idle : .offline
        }
    }

    private func handle(_ input: HotkeyMonitor.Input) {
        let event: HoldToTalk.Event? =
            switch input {
            case let .hotkeyDown(time): hold.hotkeyDown(at: time)
            case let .hotkeyUp(time): hold.hotkeyUp(at: time)
            case .other: hold.otherInput()
            }
        switch event {
        case .start: beginDictation()
        case .stop: endDictation(deliver: true, reason: nil)
        case .cancel:
            let reason = if case .other = input { "other input" } else { "short tap" }
            endDictation(deliver: false, reason: reason)
        case nil: break
        }
    }

    private func beginDictation() {
        guard state == .idle else {
            if state == .offline {
                Log.event("dictation ignored: engine offline")
                NSSound.beep()
            }
            return
        }
        engine.begin()
        let micStart = ProcessInfo.processInfo.systemUptime
        do {
            try audio.start()
        } catch {
            Log.event("mic failed to start: \(error.localizedDescription)")
            engine.finish { _ in }
            NSSound.beep()
            return
        }
        let micStartMs = Int((ProcessInfo.processInfo.systemUptime - micStart) * 1000)
        Log.event("dictation started; mic ready in \(micStartMs) ms")
        state = .listening
        NSSound(named: "Tink")?.play()
        pill.show()
    }

    private func endDictation(deliver: Bool, reason: String?) {
        guard state == .listening else { return }
        audio.stop()
        releasedAt = ProcessInfo.processInfo.systemUptime
        guard deliver else {
            Log.event("dictation cancelled: \(reason ?? "unknown")")
            engine.finish { _ in }
            pill.hide()
            state = connected ? .idle : .offline
            return
        }
        state = .processing
        pill.model.phase = .processing
        engine.finish { [weak self] message in
            Task { @MainActor in self?.deliver(message) }
        }
    }

    private func deliver(_ message: ServerMessage) {
        pill.hide()
        state = connected ? .idle : .offline
        switch message {
        case let .final(_, text, _):
            let latency = (ProcessInfo.processInfo.systemUptime - releasedAt) * 1000
            lastLatencyMs = latency
            Log.event("dictation delivered in \(Int(latency)) ms, \(text.count) chars")
            if !text.isEmpty { Paster.paste(text) }
        case let .error(message):
            Log.event("engine error: \(message)")
            NSSound.beep()
        case .partial:
            break
        }
    }
}
