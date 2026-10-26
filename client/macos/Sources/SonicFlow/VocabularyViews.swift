import SonicFlowCore
import SwiftUI

struct DictionaryView: View {
    @Bindable var store: Personalization

    var body: some View {
        VocabularyPane(
            explanation: "Words SonicFlow should always spell your way: names, products, jargon. "
                + "Joined-up words also match when spoken apart, so SonicFlow catches \"sonic flow\". "
                + "Add what the speech model writes instead under \"Heard as\".",
            addTitle: "Add Word",
            emptyTitle: "No words yet",
            emptyHint: "Add names and jargon the speech model gets wrong, like a colleague's name or your product.",
            isEmpty: store.terms.isEmpty,
            add: { store.terms.append(DictionaryTerm()) }
        ) {
            ForEach($store.terms) { $entry in
                HStack(spacing: 12) {
                    TextField("Word", text: $entry.term)
                        .frame(width: 200)
                    TextField("Heard as, comma separated", text: $entry.heardAs)
                    DeleteButton { [id = entry.id] in store.terms.removeAll { $0.id == id } }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Dictionary")
    }
}

struct SnippetsView: View {
    @Bindable var store: Personalization

    var body: some View {
        VocabularyPane(
            explanation: "Say a trigger phrase and SonicFlow types the text instead. A dictation that "
                + "is only the trigger pastes the text exactly, with no cleanup.",
            addTitle: "Add Snippet",
            emptyTitle: "No snippets yet",
            emptyHint: "Add text you type often, like your email address or a calendar link, and a phrase to say instead.",
            isEmpty: store.snippets.isEmpty,
            add: { store.snippets.append(Snippet()) }
        ) {
            ForEach($store.snippets) { $snippet in
                HStack(alignment: .top, spacing: 12) {
                    TextField("Trigger, e.g. my calendar link", text: $snippet.trigger)
                        .frame(width: 200)
                    TextField("Text to type", text: $snippet.text, axis: .vertical)
                        .lineLimit(1...6)
                    DeleteButton { [id = snippet.id] in store.snippets.removeAll { $0.id == id } }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Snippets")
    }
}

private struct VocabularyPane<Rows: View>: View {
    let explanation: String
    let addTitle: String
    let emptyTitle: String
    let emptyHint: String
    let isEmpty: Bool
    let add: () -> Void
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(explanation)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(addTitle, systemImage: "plus", action: add)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            Divider().overlay(Theme.seam)
            if isEmpty {
                ContentUnavailableView(
                    emptyTitle, systemImage: "text.badge.plus", description: Text(emptyHint)
                )
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List { rows.listRowBackground(Theme.ground).listRowSeparatorTint(Theme.seam) }
                    .scrollContentBackground(.hidden)
            }
        }
        .paneBackground()
    }
}

private struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button("Delete", systemImage: "minus.circle", action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.tertiary)
    }
}
