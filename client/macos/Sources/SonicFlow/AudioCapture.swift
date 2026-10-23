import AVFoundation
import AppKit
import SonicFlowCore

/// Captures the default mic as 16 kHz mono PCM16 in 100 ms chunks.
///
/// When `keepWarm` is on the input stays running and the last 200 ms are kept in memory, so a
/// dictation starts instantly and includes the moment before the key press; nothing outside a
/// dictation is ever sent. When off, the mic runs only while dictating.
final class AudioCapture {
    enum CaptureError: Error {
        case unsupportedFormat
    }

    static let prerollSamples = 3_200

    var onChunk: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?

    private(set) var keepWarm = false
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "sonicflow.audio")
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: PCM.sampleRate, channels: 1, interleaved: false
    )!
    private var isRunning = false
    private var isDictating = false
    private var recording = false
    private var pending: [Float] = []
    private var preroll: [Float] = []

    init() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in self?.recover() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.recover() }
    }

    func setKeepWarm(_ warm: Bool) {
        keepWarm = warm
        if warm, !isRunning {
            try? run()
        } else if !warm, isRunning, !isDictating {
            halt()
        }
    }

    func start() throws {
        if !isRunning { try run() }
        isDictating = true
        queue.sync {
            pending = preroll
            preroll.removeAll(keepingCapacity: true)
            recording = true
        }
    }

    /// Ends the dictation and emits the final partial chunk before returning.
    func stop() {
        queue.sync {
            recording = false
            if !pending.isEmpty { emit(pending) }
            pending.removeAll()
        }
        isDictating = false
        if !keepWarm { halt() }
    }

    private func run() throws {
        let input = engine.inputNode
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
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        isRunning = true
    }

    private func halt() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        queue.sync { preroll.removeAll() }
    }

    /// Device changes and sleep stop the engine and can change the input format.
    private func recover() {
        guard keepWarm || isDictating else { return }
        engine.stop()
        isRunning = false
        try? run()
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
