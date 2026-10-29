import Foundation

public struct DictionaryTerm: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var term: String
    /// Comma-separated mishearings, kept exactly as typed so editing never fights the cursor.
    public var heardAs: String
    /// Added from the user's corrections rather than typed in.
    public var learned: Bool

    public init(term: String = "", heardAs: String = "", learned: Bool = false) {
        self.term = term
        self.heardAs = heardAs
        self.learned = learned
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, heardAs, learned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        heardAs = try container.decode(String.self, forKey: .heardAs)
        learned = try container.decodeIfPresent(Bool.self, forKey: .learned) ?? false
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

/// The `start` message: the app being dictated into, its style, and the user's dictionary and
/// snippets.
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
        let style: WritingStyle
        let dictionary: [Term]
        let snippets: [Shortcut]
    }

    public static func json(
        app: String?, style: WritingStyle = .standard, dictionary: [DictionaryTerm], snippets: [Snippet]
    ) -> String {
        let payload = Payload(
            app: app,
            style: style,
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
