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
        _ path: String, method: String = "GET", body: [String: String]? = nil
    ) async throws -> T {
        var request = URLRequest(url: base.appending(path: path), timeoutInterval: 120)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw Failure(errorDescription: detail ?? "The engine rejected the request.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
