import Foundation

/// Server messages from `/v1/dictate`; see docs/PROTOCOL.md.
public enum ServerMessage: Equatable {
    public struct Timings: Decodable, Equatable {
        public let asrFinalizeMs: Double
        public let cleanupMs: Double
        public let totalMs: Double

        enum CodingKeys: String, CodingKey {
            case asrFinalizeMs = "asr_finalize_ms"
            case cleanupMs = "cleanup_ms"
            case totalMs = "total_ms"
        }
    }

    case partial(text: String)
    case final(raw: String, text: String, timings: Timings)
    case error(message: String)

    private struct Envelope: Decodable {
        let type: String
        let text: String?
        let raw: String?
        let message: String?
        let timings: Timings?
    }

    public static func decode(_ json: String) -> ServerMessage? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(json.utf8)) else {
            return nil
        }
        switch envelope.type {
        case "partial":
            return .partial(text: envelope.text ?? "")
        case "final":
            guard let timings = envelope.timings else { return nil }
            return .final(raw: envelope.raw ?? "", text: envelope.text ?? "", timings: timings)
        case "error":
            return .error(message: envelope.message ?? "")
        default:
            return nil
        }
    }

    public static let start = #"{"type":"start"}"#
    public static let stop = #"{"type":"stop"}"#
}
