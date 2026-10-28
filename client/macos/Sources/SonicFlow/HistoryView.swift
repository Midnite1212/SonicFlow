import AppKit
import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    var query = ""
    var selection = Set<History.Entry.ID>()
    var hovered: History.Entry.ID?
}

struct HistoryView: View {
    let controller: DictationController
    @Bindable var settings: AppSettings
    @Bindable var model: HistoryViewModel

    var body: some View {
        list
            .paneBackground()
            .navigationTitle("History")
            .searchable(text: $model.query, placement: .toolbar, prompt: "Search History")
    }

    @ViewBuilder private var list: some View {
        let entries = controller.history.matching(model.query)
        if entries.isEmpty {
            ContentUnavailableView {
                Label(model.query.isEmpty ? "No dictations yet" : "No matches",
                      systemImage: model.query.isEmpty ? "waveform" : "magnifyingglass")
            } description: {
                Text(model.query.isEmpty
                     ? "Hold \(settings.hotkey.title) in any text field and speak. Each dictation lands here with its time."
                     : "Nothing you dictated contains \u{201C}\(model.query)\u{201D}.")
            }
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $model.selection) {
                // Day headers are plain rows: sticky section headers draw a grey material bar.
                ForEach(Self.byDay(entries), id: \.day) { group in
                    Text(group.day.formatted(date: .complete, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 14)
                        .accessibilityAddTraits(.isHeader)
                        .selectionDisabled()
                        .listRowSeparator(.hidden)
                    ForEach(group.entries) { entry in
                        HistoryRow(entry: entry, controller: controller, model: model)
                            .tag(entry.id)
                            .listRowSeparatorTint(Theme.seam)
                    }
                }
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds(.disabled)
            .onCopyCommand { [NSItemProvider(object: selectedText(in: entries) as NSString)] }
            .onDeleteCommand {
                for entry in entries where model.selection.contains(entry.id) { controller.deleteFromHistory(entry) }
                model.selection.removeAll()
            }
        }
    }

    private func selectedText(in entries: [History.Entry]) -> String {
        entries.filter { model.selection.contains($0.id) }.map(\.text).joined(separator: "\n\n")
    }

    static func byDay(_ entries: [History.Entry]) -> [(day: Date, entries: [History.Entry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!) }
    }
}

struct HistoryRow: View {
    let entry: History.Entry
    let controller: DictationController
    let model: HistoryViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    Text(entry.date, style: .time).monospacedDigit()
                    if let app = entry.appName { Text(app) }
                    Text("^[\(entry.wordCount) word](inflect: true)")
                    if entry.isEdit { Text("Edit").fontWeight(.semibold).foregroundStyle(Theme.secondary) }
                    SpeedStripe(ms: entry.latencyMs, height: 4).frame(width: 160)
                    Text(Format.ms(entry.latencyMs))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Speed(ms: entry.latencyMs).text)
                }
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
            }
            Button("Copy", systemImage: "doc.on.doc") { controller.copyFromHistory(entry) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.secondary)
                .help("Copy")
                .opacity(model.hovered == entry.id ? 1 : 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                model.hovered = entry.id
            } else if model.hovered == entry.id {
                model.hovered = nil
            }
        }
        .contextMenu {
            Button("Copy") { controller.copyFromHistory(entry) }
            Button("Delete", role: .destructive) { controller.deleteFromHistory(entry) }
        }
    }
}
