import Foundation
import OSLog

/// Status events to the unified log and ~/Library/Logs/SonicFlow/app.log (readable without admin
/// rights). Dictated text never goes to either.
enum Log {
    private static let logger = Logger(subsystem: "com.sonicflow.app", category: "dictation")
    private static let queue = DispatchQueue(label: "sonicflow.log")
    private static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/SonicFlow/app.log")

    static func event(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        let line = "\(Date().ISO8601Format()) \(message)\n"
        queue.async { append(line) }
    }

    private static func append(_ line: String) {
        let manager = FileManager.default
        if !manager.fileExists(atPath: fileURL.path) {
            try? manager.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            manager.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
