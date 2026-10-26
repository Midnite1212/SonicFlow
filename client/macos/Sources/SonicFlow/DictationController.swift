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
    private(set) var history = History()
    private(set) var stats = Storage.load(UsageStats.self, from: Storage.statsFile) ?? UsageStats()
    let settings = AppSettings()

    var statusLine: String {
        switch state {
        case .offline: "Engine offline"
        case .idle:
            settings.talkMode == .hold
                ? "Ready — hold \(settings.hotkey.title) to dictate"
                : "Ready — tap \(settings.hotkey.title) to dictate"
        case .listening: "Listening…"
        case .processing: "Processing…"
        }
    }

    /// Below any real microphone's noise floor: the input delivered digital silence.
    private static let silenceThreshold: Float = 1e-4

    @ObservationIgnored private var gesture: TalkGesture = HoldToTalk()
    @ObservationIgnored private var gestureMode = TalkMode.hold
    @ObservationIgnored private let audio = AudioCapture()
    @ObservationIgnored private let engine = EngineClient(
        url: URL(string: "ws://127.0.0.1:8765/v1/dictate")!
    )
    @ObservationIgnored private let pill = PillController()
    @ObservationIgnored private var hotkey: HotkeyMonitor?
    @ObservationIgnored private var connected = false
    @ObservationIgnored private var startedAt: TimeInterval = 0
    @ObservationIgnored private var releasedAt: TimeInterval = 0
    @ObservationIgnored private var permissionTimer: Timer?

    init() {
        if settings.saveHistory, let saved = Storage.load(History.self, from: Storage.historyFile) {
            history = History(entries: saved.entries)
            history.prune(keeping: settings.historyRetention)
        }
    }

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
        settings.onChange = { [weak self] in self?.applySettings() }
        applySettings()
        installHotkey()

        // Grants made in System Settings don't notify the app, so poll until everything is allowed.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    private func applySettings() {
        if gestureMode != settings.talkMode {
            if state == .listening { endDictation(deliver: false, reason: "mode changed") }
            gesture = makeTalkGesture(settings.talkMode)
            gestureMode = settings.talkMode
        }
        hotkey?.hotkey = settings.hotkey
        audio.setInputDevice(uid: settings.inputDeviceUID)
        applyMicrophonePreference()
        persistHistory()
    }

    private func persistHistory() {
        guard settings.saveHistory else {
            Storage.remove(Storage.historyFile)
            return
        }
        history.prune(keeping: settings.historyRetention)
        Storage.save(history, to: Storage.historyFile)
    }

    private func applyMicrophonePreference() {
        guard permissions.microphone else { return }
        let warm = settings.keepMicrophoneReady
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
        let monitor = HotkeyMonitor(hotkey: settings.hotkey) { [weak self] input in
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
        let event: TalkEvent? =
            switch input {
            case let .hotkeyDown(time): gesture.hotkeyDown(at: time)
            case let .hotkeyUp(time): gesture.hotkeyUp(at: time)
            case .escape: gesture.escape()
            case .other: gesture.otherInput()
            }
        switch event {
        case .start: beginDictation()
        case .stop: endDictation(deliver: true, reason: nil)
        case .cancel:
            let reason =
                switch input {
                case .escape: "escape"
                case let .other(detail): "other input (\(detail))"
                default: "short tap"
                }
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
        startedAt = ProcessInfo.processInfo.systemUptime
        state = .listening
        NSSound(named: "Tink")?.play()
        pill.show()
    }

    private func endDictation(deliver: Bool, reason: String?) {
        guard state == .listening else { return }
        let peak = audio.stop()
        releasedAt = ProcessInfo.processInfo.systemUptime
        var deliver = deliver
        var reason = reason
        if deliver, peak < Self.silenceThreshold {
            // Speech models invent words from silence, so nothing is pasted.
            deliver = false
            reason = "input delivered only silence; rebuilding audio"
            audio.rebuild()
            NSSound.beep()
        }
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
            if !text.isEmpty {
                let app = NSWorkspace.shared.frontmostApplication?.localizedName
                history.record(text, latencyMs: latency, appName: app)
                stats.record(
                    words: History.wordCount(text), speakingSeconds: releasedAt - startedAt,
                    latencyMs: latency
                )
                Storage.save(stats, to: Storage.statsFile)
                if settings.saveHistory { persistHistory() }
            }
            Log.event("dictation delivered in \(Int(latency)) ms, \(text.count) chars")
            if !text.isEmpty { Paster.paste(text) }
        case let .error(message):
            Log.event("engine error: \(message)")
            NSSound.beep()
        case .partial:
            break
        }
    }

    func copyFromHistory(_ entry: History.Entry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    func deleteFromHistory(_ entry: History.Entry) {
        history.remove(entry.id)
        persistHistory()
    }

    func clearHistory() {
        history.clear()
        persistHistory()
    }
}
