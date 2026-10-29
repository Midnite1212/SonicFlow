import Foundation

/// JSON files in ~/Library/Application Support/SonicFlow, readable only by the user.
enum Storage {
    static let historyFile = "history.json"
    static let statsFile = "stats.json"
    static let learningFile = "learning.json"

    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/SonicFlow")

    static func load<Value: Decodable>(_ type: Value.Type, from name: String) -> Value? {
        guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save(_ value: some Encodable, to name: String) {
        let url = directory.appending(path: name)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            Log.event("could not save \(name): \(error.localizedDescription)")
        }
    }

    static func remove(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appending(path: name))
    }
}
