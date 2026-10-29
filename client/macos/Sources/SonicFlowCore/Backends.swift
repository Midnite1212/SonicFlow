import Foundation

/// `GET /v1/backends`; see docs/PROTOCOL.md.
public struct Backends: Decodable, Equatable, Sendable {
    public struct Kind: Decodable, Equatable, Sendable {
        public let active: String
        public let available: [String]
    }

    public let asr: Kind
    public let cleanup: Kind
}

/// `GET /health` and the `POST /v1/config` response.
public struct EngineStatus: Decodable, Equatable, Sendable {
    public let status: String
    public let asr: String
    public let cleanup: String
}

/// `GET /v1/lan`: whether this Mac's engine serves other Macs, and the code they pair with.
public struct SharingStatus: Decodable, Equatable, Sendable {
    public let enabled: Bool
    public let host: String?
    public let port: Int?
    public let code: String?
}
