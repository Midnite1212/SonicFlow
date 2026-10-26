import AppKit
import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    var query = ""
    var confirmingClear = false
}

struct HistoryView: View {
    let controller: DictationController
    @Bindable var settings: AppSettings
    @Bindable var model: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            list
        }
        .navigationTitle("History")
        .confirmationDialog(
            "Clear all dictation history?", isPresented: $model.confirmingClear
        ) {
            Button("Clear History", role: .destructive) { controller.clearHistory() }
        } message: {
            Text(settings.saveHistory ? "This also deletes the saved copy on this Mac." : "")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Save history on this Mac", isOn: $settings.saveHistory)
                Picker("Keep for", selection: $settings.historyRetention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .fixedSize()
                .disabled(!settings.saveHistory)
                Spacer()
                Button("Clear All…") { model.confirmingClear = true }
                    .disabled(controller.history.entries.isEmpty)
            }
            Text(
                settings.saveHistory
                    ? "Saved in Application Support, readable only by you, and deleted after the retention period."
                    : "Kept in memory until SonicFlow quits. Nothing is written to disk."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            TextField("Search", text: $model.query)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
    }

    @ViewBuilder private var list: some View {
        let entries = controller.history.matching(model.query)
        if entries.isEmpty {
            ContentUnavailableView(
                model.query.isEmpty ? "No dictations yet" : "No matches",
                systemImage: model.query.isEmpty ? "waveform" : "magnifyingglass"
            )
        } else {
            List {
                ForEach(Self.byDay(entries), id: \.day) { group in
                    Section(group.day.formatted(date: .complete, time: .omitted)) {
                        ForEach(group.entries) { entry in
                            HistoryRow(entry: entry, controller: controller)
                        }
                    }
                }
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Text(entry.date, style: .time)
                if let app = entry.appName { Text(app) }
                Text("^[\(entry.wordCount) word](inflect: true)")
                Text("\(Int(entry.latencyMs.rounded())) ms")
                Spacer()
                Button("Copy") { controller.copyFromHistory(entry) }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy") { controller.copyFromHistory(entry) }
            Button("Delete", role: .destructive) { controller.deleteFromHistory(entry) }
        }
    }
}
