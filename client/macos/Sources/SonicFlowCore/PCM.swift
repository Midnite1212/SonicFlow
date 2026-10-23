import Foundation

public enum PCM {
    public static let sampleRate: Double = 16_000
    public static let chunkSamples = 1_600

    /// Converts float samples in [-1, 1] to little-endian PCM16, clamping out-of-range input.
    public static func int16Data(from samples: UnsafeBufferPointer<Float>) -> Data {
        var data = Data(count: samples.count * 2)
        data.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: Int16.self)
            for (index, sample) in samples.enumerated() {
                let clamped = max(-1, min(1, sample))
                out[index] = Int16(clamped * Float(Int16.max)).littleEndian
            }
        }
        return data
    }

    /// Root-mean-square level in [0, 1], for the waveform.
    public static func level(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return min(1, (sumOfSquares / Float(samples.count)).squareRoot())
    }
}
