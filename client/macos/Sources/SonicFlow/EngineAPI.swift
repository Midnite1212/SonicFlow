import Foundation
import SonicFlowCore

/// HTTP calls to the engine's control endpoints, plus restarting its LaunchAgent.
enum EngineAPI {
    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    private static let base = URL(string: "http://127.0.0.1:8765")!
    private static let label = "com.sonicflow.engine"

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
        _ path: String, method: String = "GET", body: [String: String]? = nil,
        query: [URLQueryItem] = []
    ) async throws -> T {
        var url = base.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw Failure(errorDescription: detail ?? "The engine rejected the request.")
        }
        return try JSONDecoder.engine.decode(T.self, from: data)
    }
}
