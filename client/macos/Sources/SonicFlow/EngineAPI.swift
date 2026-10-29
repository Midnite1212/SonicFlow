import Foundation
import SonicFlowCore
import os

/// HTTP calls to the engine's control endpoints, plus restarting its LaunchAgent.
enum EngineAPI {
    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    private static let label = "com.sonicflow.engine"
    private static let current = OSAllocatedUnfairLock(initialState: EngineEndpoint.local)

    /// The engine dictation uses right now, which models and backend choices apply to.
    static var endpoint: EngineEndpoint {
        get { current.withLock { $0 } }
        set { current.withLock { $0 = newValue } }
    }

    static func backends() async throws -> Backends {
        try await request("v1/backends")
    }

    static func configure(asr: String? = nil, cleanup: String? = nil) async throws -> EngineStatus {
        var body: [String: String] = [:]
        body["asr"] = asr
        body["cleanup"] = cleanup
        return try await request("v1/config", method: "POST", body: body)
    }

    static func models() async throws -> ModelList {
        try await request("v1/models")
    }

    static func download(_ id: String) async throws {
        let _: Ignored = try await request("v1/models/download", method: "POST", body: ["id": id])
    }

    static func benchmark(_ id: String) async throws {
        let _: Ignored = try await request("v1/models/bench", method: "POST", body: ["id": id])
    }

    static func addModel(source: String, family: String? = nil) async throws -> ModelInfo {
        var body = ["source": source]
        body["family"] = family
        return try await request("v1/models/custom", method: "POST", body: body)
    }

    static func remove(_ id: String) async throws {
        let _: Ignored = try await request("v1/models/remove", method: "POST", body: ["id": id])
    }

    static func search(_ query: String, kind: ModelInfo.Kind) async throws -> HubSearch {
        try await request("v1/models/search", query: [
            URLQueryItem(name: "q", value: query), URLQueryItem(name: "kind", value: kind.rawValue),
        ])
    }

    static func ollama() async throws -> OllamaStatus {
        try await request("v1/models/ollama")
    }

    /// Sharing this Mac's engine with the network; always asks the engine on this Mac.
    static func sharing() async throws -> SharingStatus {
        try await request("v1/lan", on: .local)
    }

    static func setSharing(_ enabled: Bool) async throws -> SharingStatus {
        try await request("v1/lan", method: "POST", body: ["enabled": enabled], on: .local)
    }

    static func resetSharing() async throws -> SharingStatus {
        try await request("v1/lan/reset", method: "POST", on: .local)
    }

    /// Reaches a paired engine with its token and pinned certificate before the pairing is saved.
    static func check(_ endpoint: EngineEndpoint) async throws {
        let _: Ignored = try await request("health", on: endpoint, timeout: 5)
    }

    private struct Ignored: Decodable {}

    static func restart() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "-k", "gui/\(getuid())/\(label)"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure(errorDescription: "The background engine isn't installed.")
        }
    }

    private static func request<T: Decodable>(
        _ path: String, method: String = "GET", body: (any Encodable)? = nil,
        query: [URLQueryItem] = [], on endpoint: EngineEndpoint? = nil, timeout: TimeInterval = 120
    ) async throws -> T {
        let endpoint = endpoint ?? self.endpoint
        var url = endpoint.baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        if let token = endpoint.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let trust = endpoint.certificateSHA256.map(PinnedTrust.init(sha256:))
        let (data, response) = try await URLSession.shared.data(for: request, delegate: trust)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw Failure(errorDescription: detail ?? "The engine rejected the request.")
        }
        return try JSONDecoder.engine.decode(T.self, from: data)
    }
}
