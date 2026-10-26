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
            Divider().overlay(Theme.seam)
            list
        }
        .paneBackground()
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
            HStack(spacing: 16) {
                Toggle("Save history on this Mac", isOn: $settings.saveHistory)
                    .fixedSize()
                Picker("Keep for", selection: $settings.historyRetention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .fixedSize()
                .disabled(!settings.saveHistory)
                Spacer()
                Button("Clear All…") { model.confirmingClear = true }
                    .disabled(controller.history.entries.isEmpty)
                    .fixedSize()
            }
            HStack(spacing: 16) {
                Text(
                    settings.saveHistory
                        ? "Saved in Application Support, readable only by you, deleted after \(settings.historyRetention.title.lowercased())."
                        : "Kept in memory until SonicFlow quits. Nothing is written to disk."
                )
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.tertiary)
                    TextField("Search history", text: $model.query)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(minWidth: 140, maxWidth: 220, minHeight: 28, maxHeight: 28)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.seam))
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
            List {
                ForEach(Self.byDay(entries), id: \.day) { group in
                    Text(group.day.formatted(date: .complete, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 10)
                        .listRowBackground(Theme.ground)
                        .listRowSeparator(.hidden)
                    ForEach(group.entries) { entry in
                        HistoryRow(entry: entry, controller: controller)
                            .listRowBackground(Theme.ground)
                            .listRowSeparatorTint(Theme.seam)
                    }
                }
            }
            .scrollContentBackground(.hidden)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text)
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
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
                Spacer()
                Button("Copy") { controller.copyFromHistory(entry) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.secondary)
            }
            .font(.callout)
            .foregroundStyle(Theme.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contextMenu {
            Button("Copy") { controller.copyFromHistory(entry) }
            Button("Delete", role: .destructive) { controller.deleteFromHistory(entry) }
        }
    }
}
