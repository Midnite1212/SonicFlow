import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class VocabularyModel {
    var terms = Set<DictionaryTerm.ID>()
    var snippets = Set<Snippet.ID>()
}

struct DictionaryView: View {
    @Bindable var store: Personalization
    @Bindable var model: VocabularyModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VocabularyPane(
            footer: "Words SonicFlow should always spell your way. Joined-up words also match when spoken "
                + "apart, so SonicFlow catches \"sonic flow\". Add what the speech model writes instead under Heard As.",
            emptyTitle: "No words yet",
            emptyHint: "Add names and jargon the speech model gets wrong, like a colleague's name or your product.",
            addTitle: "Add Word",
            isEmpty: store.terms.isEmpty,
            add: add
        ) {
            Table(store.terms, selection: $model.terms) {
                TableColumn("Word") { term in
                    TextField("Word", text: field(term.id, \.term)).textFieldStyle(.plain)
                }
                .width(min: 140, ideal: 200, max: 320)
                TableColumn("Heard As") { term in
                    TextField("Comma separated", text: field(term.id, \.heardAs)).textFieldStyle(.plain)
                }
            }
            .onDeleteCommand { delete(model.terms) }
            .contextMenu(forSelectionType: DictionaryTerm.ID.self) { ids in
                Button("Delete", role: .destructive) { delete(ids) }
            }
        }
        .navigationTitle("Dictionary")
    }

    private func add() {
        let term = DictionaryTerm()
        store.terms.append(term)
        model.terms = [term.id]
    }

    private func delete(_ ids: Set<DictionaryTerm.ID>) {
        let before = store.terms
        store.terms.removeAll { ids.contains($0.id) }
        model.terms.subtract(ids)
        undoManager?.registerUndo(withTarget: store) { $0.terms = before }
        undoManager?.setActionName(ids.count == 1 ? "Delete Word" : "Delete Words")
    }

    private func field(_ id: DictionaryTerm.ID, _ path: WritableKeyPath<DictionaryTerm, String>) -> Binding<String> {
        Binding(
            get: { store.terms.first { $0.id == id }?[keyPath: path] ?? "" },
            set: { value in
                if let index = store.terms.firstIndex(where: { $0.id == id }) { store.terms[index][keyPath: path] = value }
            }
        )
    }
}

struct SnippetsView: View {
    @Bindable var store: Personalization
    @Bindable var model: VocabularyModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VocabularyPane(
            footer: "Say a trigger phrase and SonicFlow types the text instead. A dictation that is only the "
                + "trigger pastes the text exactly, with no cleanup.",
            emptyTitle: "No snippets yet",
            emptyHint: "Add text you type often, like your email address or a calendar link, and a phrase to say instead.",
            addTitle: "Add Snippet",
            isEmpty: store.snippets.isEmpty,
            add: add
        ) {
            Table(store.snippets, selection: $model.snippets) {
                TableColumn("Trigger") { snippet in
                    TextField("e.g. my calendar link", text: field(snippet.id, \.trigger)).textFieldStyle(.plain)
                }
                .width(min: 140, ideal: 200, max: 320)
                TableColumn("Text to Type") { snippet in
                    TextField("Text", text: field(snippet.id, \.text), axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                }
            }
            .onDeleteCommand { delete(model.snippets) }
            .contextMenu(forSelectionType: Snippet.ID.self) { ids in
                Button("Delete", role: .destructive) { delete(ids) }
            }
        }
        .navigationTitle("Snippets")
    }

    private func add() {
        let snippet = Snippet()
        store.snippets.append(snippet)
        model.snippets = [snippet.id]
    }

    private func delete(_ ids: Set<Snippet.ID>) {
        let before = store.snippets
        store.snippets.removeAll { ids.contains($0.id) }
        model.snippets.subtract(ids)
        undoManager?.registerUndo(withTarget: store) { $0.snippets = before }
        undoManager?.setActionName(ids.count == 1 ? "Delete Snippet" : "Delete Snippets")
    }

    private func field(_ id: Snippet.ID, _ path: WritableKeyPath<Snippet, String>) -> Binding<String> {
        Binding(
            get: { store.snippets.first { $0.id == id }?[keyPath: path] ?? "" },
            set: { value in
                if let index = store.snippets.firstIndex(where: { $0.id == id }) {
                    store.snippets[index][keyPath: path] = value
                }
            }
        )
    }
}

/// An editable table with its add button in the toolbar and a short explanation underneath.
private struct VocabularyPane<Rows: View>: View {
    let footer: String
    let emptyTitle: String
    let emptyHint: String
    let addTitle: String
    let isEmpty: Bool
    let add: () -> Void
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            if isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "text.badge.plus")
                } description: {
                    Text(emptyHint)
                } actions: {
                    Button(addTitle, action: add)
                }
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                rows
                    .alternatingRowBackgrounds(.disabled)
                    .scrollContentBackground(.hidden)
            }
            Text(footer)
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Seam() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(addTitle, systemImage: "plus", action: add)
                    .keyboardShortcut("n")
                    .help("\(addTitle) (⌘N)")
            }
        }
    }
}
