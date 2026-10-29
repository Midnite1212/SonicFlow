import SonicFlowCore
import SwiftUI

struct LearningView: View {
    let controller: DictationController
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            if controller.learning.entries.isEmpty {
                ContentUnavailableView {
                    Label("Nothing learned yet", systemImage: "lightbulb")
                } description: {
                    Text(
                        settings.learnFromCorrections
                            ? "Fix a misheard name right after dictating. SonicFlow adds it to your Dictionary, "
                                + "or lists it here when it needs your check."
                            : "Turn on Learn words from your corrections in Settings."
                    )
                }
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
            Text(footer)
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 10)
                .padding(.bottom, 20)
        }
        .paneBackground()
        .navigationTitle("Learning")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear Log", systemImage: "trash") { controller.clearLearning() }
                    .disabled(controller.learning.entries.isEmpty)
                    .help("Clear Log")
            }
        }
    }

    private var list: some View {
        let entries = controller.learning.entries
        let review = entries.filter { $0.status == .suggested }
        let recent = entries.filter { $0.status != .suggested }
        return List {
            if !review.isEmpty {
                header("To review")
                ForEach(review) { LearningRow(entry: $0, controller: controller) }
            }
            if !recent.isEmpty {
                header("Recent")
                ForEach(recent) { LearningRow(entry: $0, controller: controller) }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .padding(.vertical, 6)
        .glassPanel(cornerRadius: 20)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    /// Plain rows rather than sticky section headers, which draw a grey material bar.
    private func header(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondary)
            .padding(.top, 14)
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
    }

    private var footer: String {
        "Only the misheard and fixed words are kept, never what you were writing. "
            + (settings.saveHistory
                ? "Saved with your history and kept as long."
                : "Kept in memory until SonicFlow quits, like your history.")
    }
}

private struct LearningRow: View {
    let entry: LearningLog.Entry
    let controller: DictationController

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let heard = entry.heard {
                        Text(heard).foregroundStyle(Theme.secondary).strikethrough(color: Theme.tertiary)
                        Image(systemName: "arrow.right").foregroundStyle(Theme.tertiary).accessibilityLabel("became")
                    }
                    Text(entry.term).fontWeight(.semibold).foregroundStyle(Theme.text)
                }
                HStack(spacing: 12) {
                    Text(entry.date.formatted(.relative(presentation: .named)))
                    if entry.count > 1 { Text("Fixed \(entry.count) times") }
                    Text(detail)
                }
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(.vertical, 6)
        .listRowSeparatorTint(Theme.seam)
    }

    @ViewBuilder private var actions: some View {
        switch entry.status {
        case .suggested:
            Button("Dismiss") { controller.dismiss(entry) }
            Button("Add to Dictionary") { controller.addToDictionary(entry) }.buttonStyle(.borderedProminent)
        case .learned:
            Button("Remove") { controller.removeFromDictionary(entry) }
                .help("Take this back out of your Dictionary")
        case .dismissed:
            Button("Add to Dictionary") { controller.addToDictionary(entry) }
        }
    }

    private var detail: String {
        switch entry.status {
        case .learned: return entry.heard == nil ? "Capitals learned" : "In your Dictionary"
        case .dismissed: return "Dismissed"
        case .suggested:
            switch entry.hold {
            case .commonWord:
                return "\u{201C}\(entry.heard ?? "")\u{201D} is a common word; adding this changes it everywhere"
            case .sentenceStart: return "It started a sentence, so it may not be a name"
            case .unlike, nil: return "It sounds only partly like what was heard"
            }
        }
    }
}
