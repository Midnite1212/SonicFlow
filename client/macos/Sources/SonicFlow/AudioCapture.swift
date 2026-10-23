import AVFoundation
import SonicFlowCore

/// Captures the default mic only while dictating, as 16 kHz mono PCM16 in 100 ms chunks.
final class AudioCapture {
    enum CaptureError: Error {
        case unsupportedFormat
    }

    var onChunk: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "sonicflow.audio")
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: PCM.sampleRate, channels: 1, interleaved: false
    )!
    private var sessionCount = 0
    private var activeSession: Int?
    private var pending: [Float] = []

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw CaptureError.unsupportedFormat
        }
        converter.downmix = true
        let session = queue.sync {
            sessionCount += 1
            activeSession = sessionCount
            pending.removeAll(keepingCapacity: true)
            return sessionCount
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let samples = self.convert(buffer, with: converter) else { return }
            self.queue.async { self.accept(samples, from: session) }
        }
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            queue.sync { activeSession = nil }
            throw error
        }
    }

    /// Stops capture and emits the final partial chunk before returning.
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        queue.sync {
            if !pending.isEmpty { emit(pending) }
            pending.removeAll()
            // Late tap callbacks for this session are dropped rather than sent after `stop`.
            activeSession = nil
        }
    }

    private func accept(_ samples: [Float], from session: Int) {
        guard activeSession == session else { return }
        pending.append(contentsOf: samples)
        while pending.count >= PCM.chunkSamples {
            emit(Array(pending.prefix(PCM.chunkSamples)))
            pending.removeFirst(PCM.chunkSamples)
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
