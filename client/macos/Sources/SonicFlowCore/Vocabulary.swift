import Foundation

public struct DictionaryTerm: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var term: String
    /// Comma-separated mishearings, kept exactly as typed so editing never fights the cursor.
    public var heardAs: String

    public init(term: String = "", heardAs: String = "") {
        self.term = term
        self.heardAs = heardAs
    }

    public var heard: [String] {
        heardAs.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

public struct Snippet: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var trigger: String
    public var text: String

    public init(trigger: String = "", text: String = "") {
        self.trigger = trigger
        self.text = text
    }
}

/// The `start` message: the app being dictated into plus the user's dictionary and snippets.
public enum StartMessage {
    private struct Payload: Encodable {
        struct Term: Encodable {
            let term: String
            let heard: [String]
        }

        struct Shortcut: Encodable {
            let trigger: String
            let text: String
        }

        let type = "start"
        let app: String?
        let dictionary: [Term]
        let snippets: [Shortcut]
    }

    public static func json(app: String?, dictionary: [DictionaryTerm], snippets: [Snippet]) -> String {
        let payload = Payload(
            app: app,
            dictionary: dictionary
                .map { Payload.Term(term: $0.term.trimmingCharacters(in: .whitespaces), heard: $0.heard) }
                .filter { !$0.term.isEmpty },
            snippets: snippets
                .filter { !$0.trigger.trimmingCharacters(in: .whitespaces).isEmpty && !$0.text.isEmpty }
                .map { Payload.Shortcut(trigger: $0.trigger, text: $0.text) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try! encoder.encode(payload), as: UTF8.self)
    }
}
