import AVFoundation
import AppKit
import SonicFlowCore

/// Captures the default mic as 16 kHz mono PCM16 in 100 ms chunks.
///
/// The mic runs only while dictating: the engine stays armed (tap installed, resources prepared) so
/// the input starts as fast as the device allows. When `keepWarm` is on the input stays running and
/// the last 200 ms are kept in memory, so a dictation includes the moment before the key press;
/// nothing outside a dictation is ever sent.
final class AudioCapture {
    enum CaptureError: Error {
        case unsupportedFormat
    }

    static let prerollSamples = 3_200

    var onChunk: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?

    private(set) var keepWarm = false
    private var inputDeviceUID: String?
    private var engine = AVAudioEngine()
    private var configurationObserver: NSObjectProtocol?
    private let queue = DispatchQueue(label: "sonicflow.audio")
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: PCM.sampleRate, channels: 1, interleaved: false
    )!
    private var isArmed = false
    private var isRunning = false
    private var isDictating = false
    private var recording = false
    private var pending: [Float] = []
    private var preroll: [Float] = []
    private var sessionPeak: Float = 0

    init() {
        observeConfigurationChanges()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
    }

    func setKeepWarm(_ warm: Bool) {
        keepWarm = warm
        if warm, !isRunning {
            try? run()
        } else if !warm, isRunning, !isDictating {
            idle()
        } else if !isArmed {
            try? arm()
        }
    }

    /// `nil` follows the system default input as it changes; a missing device falls back to it.
    /// A fresh engine is built because once a device is pinned, the old one stops following.
    func setInputDevice(uid: String?) {
        guard uid != inputDeviceUID, !isDictating else { return }
        inputDeviceUID = uid
        rebuild()
    }

    /// Replaces the engine; a restarted one can keep running after sleep or a device change while
    /// delivering only silence.
    func rebuild() {
        rearm(freshEngine: true)
    }

    private func rearm(freshEngine: Bool) {
        let shouldRun = isRunning || keepWarm || isDictating
        if isArmed { disarm() }
        if freshEngine {
            engine = AVAudioEngine()
            observeConfigurationChanges()
        }
        if shouldRun { try? run() } else { try? arm() }
    }

    private func observeConfigurationChanges() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in self?.recover() }
    }

    func start() throws {
        if !isRunning { try run() }
        isDictating = true
        queue.sync {
            pending = preroll
            preroll.removeAll(keepingCapacity: true)
            sessionPeak = 0
            recording = true
        }
    }

    /// Ends the dictation, emits the final partial chunk, and returns the loudest sample sent.
    @discardableResult
    func stop() -> Float {
        let peak = queue.sync {
            recording = false
            if !pending.isEmpty { emit(pending) }
            pending.removeAll()
            return sessionPeak
        }
        isDictating = false
        if !keepWarm { idle() }
        return peak
    }

    /// Selects the device, installs the tap, and allocates the engine without starting the input,
    /// so the mic stays off until `run()` and then starts quickly.
    private func arm() throws {
        guard !isArmed else { return }
        let input = engine.inputNode
        if let unit = input.audioUnit,
            var device = inputDeviceUID.flatMap(AudioDevices.deviceID(forUID:))
        {
            // Setting the device posts a configuration change, so it is only set when it differs.
            var current = AudioDeviceID(0)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            AudioUnitGetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &current, &size
            )
            if current != device {
                AudioUnitSetProperty(
                    unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                    &device, size
                )
            }
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard
            inputFormat.sampleRate > 0,
            let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else { throw CaptureError.unsupportedFormat }
        converter.downmix = true
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let samples = self.convert(buffer, with: converter) else { return }
            self.queue.async { self.accept(samples) }
        }
        engine.prepare()
        isArmed = true
    }

    private func run() throws {
        try arm()
        do {
            try engine.start()
        } catch {
            disarm()
            throw error
        }
        isRunning = true
    }

    /// Stops the input but keeps the engine armed for the next `run()`.
    private func idle() {
        engine.pause()
        isRunning = false
        queue.sync { preroll.removeAll() }
    }

    private func disarm() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isArmed = false
        isRunning = false
        queue.sync { preroll.removeAll() }
    }

    /// Device changes stop the engine and can change the input format; the same engine is re-armed,
    /// since a fresh one would set the device again and post another change.
    private func recover() {
        rearm(freshEngine: false)
    }

    private func accept(_ samples: [Float]) {
        if recording {
            pending.append(contentsOf: samples)
            while pending.count >= PCM.chunkSamples {
                emit(Array(pending.prefix(PCM.chunkSamples)))
                pending.removeFirst(PCM.chunkSamples)
            }
        } else {
            preroll.append(contentsOf: samples)
            if preroll.count > Self.prerollSamples {
                preroll.removeFirst(preroll.count - Self.prerollSamples)
            }
        }
    }

    private func emit(_ chunk: [Float]) {
        sessionPeak = chunk.reduce(sessionPeak) { max($0, abs($1)) }
        chunk.withUnsafeBufferPointer { samples in
            onChunk?(PCM.int16Data(from: samples))
            onLevel?(PCM.level(of: samples))
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> [Float]? {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = output.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
