import Foundation
import Observation
import SonicFlowCore

/// The dictionary and snippets, saved on every edit and sent with each dictation.
@MainActor
@Observable
final class VocabularyStore {
    static let dictionaryFile = "dictionary.json"
    static let snippetsFile = "snippets.json"

    var terms: [DictionaryTerm] {
        didSet { Storage.save(terms, to: Self.dictionaryFile) }
    }

    var snippets: [Snippet] {
        didSet { Storage.save(snippets, to: Self.snippetsFile) }
    }

    init() {
        terms = Storage.load([DictionaryTerm].self, from: Self.dictionaryFile) ?? []
        snippets = Storage.load([Snippet].self, from: Self.snippetsFile) ?? []
    }

    func startMessage(app: String?) -> String {
        StartMessage.json(app: app, dictionary: terms, snippets: snippets)
    }
}
