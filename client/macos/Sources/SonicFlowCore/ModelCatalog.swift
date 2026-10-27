import Foundation

/// `GET /v1/models`; see docs/PROTOCOL.md.
public struct ModelList: Decodable, Equatable, Sendable {
    public struct Active: Decodable, Equatable, Sendable {
        public let asr: String
        public let cleanup: String
    }

    public let active: Active
    public let models: [ModelInfo]

    public func models(in group: ModelInfo.Group, kind: ModelInfo.Kind) -> [ModelInfo] {
        models.filter { $0.group == group && $0.kind == kind }
    }

    public func isActive(_ model: ModelInfo) -> Bool {
        model.id == (model.kind == .asr ? active.asr : active.cleanup)
    }

    public func model(_ id: String) -> ModelInfo? {
        models.first { $0.id == id }
    }

    /// Downloads and benchmarks report progress only when polled.
    public var isWorking: Bool {
        models.contains { ($0.download?.isRunning ?? false) || ($0.benchmark?.isRunning ?? false) }
    }
}

public struct ModelInfo: Decodable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Decodable, Sendable { case asr, cleanup }
    public enum Group: String, Decodable, Sendable { case recommended, catalog, custom }

    public struct Bench: Decodable, Equatable, Sendable {
        public let p50Ms: Double
        public let wer: Double
        private let local: Bool?

        /// Measured on this Mac rather than shipped with SonicFlow.
        public var isLocal: Bool { local ?? false }
    }

    public struct Benchmark: Decodable, Equatable, Sendable {
        public let state: String
        public let error: String?

        public var isRunning: Bool { state == "queued" || state == "running" }
    }

    public struct Download: Decodable, Equatable, Sendable {
        public let state: String
        public let bytes: Int64
        public let totalBytes: Int64?
        public let error: String?

        public var isRunning: Bool { state == "queued" || state == "downloading" }

        public var fraction: Double? {
            guard let totalBytes, totalBytes > 0 else { return nil }
            return min(1, Double(bytes) / Double(totalBytes))
        }
    }

    public let id: String
    public let kind: Kind
    public let family: String
    public let source: String
    public let title: String
    public let group: Group
    public let sizeBytes: Int64?
    public let note: String
    public let bench: Bench?
    public let installed: Bool
    public let download: Download?
    public let benchmark: Benchmark?

    public var isLocalFolder: Bool { source.hasPrefix("/") }
    public var hasFiles: Bool { family != "builtin" }

    /// What the row offers, given whether this model is the one in use.
    public enum Action: Equatable, Sendable {
        case inUse, use, download, downloading(fraction: Double?), failed(String), unavailable
    }

    public func action(isActive: Bool) -> Action {
        if isActive { return .inUse }
        if let download, download.isRunning { return .downloading(fraction: download.fraction) }
        if installed { return .use }
        if family == "ollama" || isLocalFolder { return .unavailable }
        if let download, download.state == "error" { return .failed(download.error ?? "Download failed") }
        return .download
    }

    public var familyTitle: String {
        switch family {
        case "parakeet": "Parakeet"
        case "whisper": "Whisper"
        case "mlx-lm": "MLX"
        case "ollama": "Ollama"
        default: "Built in"
        }
    }

    public static func size(_ bytes: Int64?) -> String? {
        guard let bytes, bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// `GET /v1/models/search`.
public struct HubSearch: Decodable, Equatable, Sendable {
    public struct Result: Decodable, Equatable, Identifiable, Sendable {
        public var id: String { source }
        public let source: String
        public let family: String
        public let downloads: Int?
        public let added: Bool
    }

    public let results: [Result]
}

/// `GET /v1/models/ollama`.
public struct OllamaStatus: Decodable, Equatable, Sendable {
    public struct Pulled: Decodable, Equatable, Identifiable, Sendable {
        public var id: String { name }
        public let name: String
        public let size: Int64?
        public let added: Bool
    }

    public let running: Bool
    public let models: [Pulled]
}

public extension JSONDecoder {
    /// The engine speaks snake_case JSON.
    static var engine: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
