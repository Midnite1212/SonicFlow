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
    let isEmpty: Bool
    let add: () -> Void
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(explanation)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(addTitle, systemImage: "plus", action: add)
            }
            .padding(16)
            Divider()
            if isEmpty {
                ContentUnavailableView(
                    "Nothing here yet", systemImage: "text.badge.plus",
                    description: Text("Click \(addTitle) to start.")
                )
            } else {
                List { rows }
            }
        }
    }
}

private struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button("Delete", systemImage: "minus.circle", action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
    }
}
