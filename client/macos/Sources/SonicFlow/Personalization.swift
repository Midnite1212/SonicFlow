import Foundation
import Observation
import SonicFlowCore

/// The dictionary, snippets, and writing styles, saved on every edit and sent with each dictation.
@MainActor
@Observable
final class Personalization {
    static let dictionaryFile = "dictionary.json"
    static let snippetsFile = "snippets.json"
    static let stylesFile = "styles.json"

    var terms: [DictionaryTerm] {
        didSet { Storage.save(terms, to: Self.dictionaryFile) }
    }

    var snippets: [Snippet] {
        didSet { Storage.save(snippets, to: Self.snippetsFile) }
    }

    var styles: StylePreferences {
        didSet { Storage.save(styles, to: Self.stylesFile) }
    }

    init() {
        terms = Storage.load([DictionaryTerm].self, from: Self.dictionaryFile) ?? []
        snippets = Storage.load([Snippet].self, from: Self.snippetsFile) ?? []
        styles = Storage.load(StylePreferences.self, from: Self.stylesFile) ?? StylePreferences()
    }

    func startMessage(app: String?, partials: Bool) -> String {
        StartMessage.json(
            app: app, style: styles.style(for: app), dictionary: terms, snippets: snippets, partials: partials
        )
    }
}
