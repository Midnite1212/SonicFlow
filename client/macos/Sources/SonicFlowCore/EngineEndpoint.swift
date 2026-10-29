import Foundation

/// Where an engine listens: this Mac over loopback, or a paired Mac over TLS whose certificate is
/// pinned by its SHA-256 and whose requests carry a bearer token (ADR 0007).
public struct EngineEndpoint: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let token: String?
    public let certificateSHA256: String?

    public static let local = EngineEndpoint(host: "127.0.0.1", port: 8765, token: nil, certificateSHA256: nil)
    public static let pairingPrefix = "sonicflow1."

    public init(host: String, port: Int, token: String?, certificateSHA256: String?) {
        self.host = host
        self.port = port
        self.token = token
        self.certificateSHA256 = certificateSHA256
    }

    /// Reads the code a sharing Mac shows in Settings; `nil` if it isn't one.
    public init?(pairingCode: String) {
        let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.hasPrefix(Self.pairingPrefix) else { return nil }
        var encoded = String(code.dropFirst(Self.pairingPrefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        struct Payload: Decodable {
            let host: String
            let port: Int
            let token: String
            let sha256: String
        }
        guard let data = Data(base64Encoded: encoded),
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            !payload.host.isEmpty, (1...65535).contains(payload.port), !payload.token.isEmpty,
            payload.sha256.count == 64, payload.sha256.allSatisfy(\.isHexDigit)
        else { return nil }
        self.init(
            host: payload.host, port: payload.port, token: payload.token,
            certificateSHA256: payload.sha256.lowercased()
        )
    }

    public var isLocal: Bool { certificateSHA256 == nil }

    /// "Richies-Mac-Studio.local" reads as "Richies Mac Studio".
    public var displayName: String {
        isLocal
            ? "This Mac"
            : String(host.split(separator: ".").first ?? Substring(host))
                .replacingOccurrences(of: "-", with: " ")
    }

    public var baseURL: URL { url(scheme: isLocal ? "http" : "https", path: "") }
    public var dictateURL: URL { url(scheme: isLocal ? "ws" : "wss", path: "/v1/dictate") }

    private func url(scheme: String, path: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        components.path = path
        return components.url!
    }
}
