import AppKit
import SonicFlowCore
import SwiftUI

struct HomeView: View {
    let controller: DictationController
    let navigation: Navigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                PermissionsNotice(controller: controller)
                stats
                recent
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        HStack(spacing: 16) {
            AppIcon(size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("SonicFlow").font(.largeTitle.weight(.semibold))
                Label(controller.statusLine, systemImage: controller.state.symbolName)
                    .foregroundStyle(controller.state == .offline ? .red : .secondary)
            }
        }
    }

    private var stats: some View {
        let today = controller.stats.totals(lastDays: 1)
        let week = controller.stats.totals(lastDays: 7)
        let allTime = controller.stats.totals(lastDays: nil)
        let streak = controller.stats.streak()
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            StatCard(value: today.words.formatted(), title: "Words today")
            StatCard(value: week.words.formatted(), title: "Words this week")
            StatCard(
                value: week.wordsPerMinute.map { "\(Int($0.rounded())) wpm" } ?? "—",
                title: "Speaking speed, 7 days"
            )
            StatCard(
                value: week.averageLatencyMs.map { "\(Int($0.rounded())) ms" } ?? "—",
                title: "Release to text, 7 days"
            )
            StatCard(value: Self.duration(allTime.timeSavedSeconds()), title: "Saved vs typing at 40 wpm")
            StatCard(value: streak == 1 ? "1 day" : "\(streak) days", title: "Streak")
        }
    }

    @ViewBuilder private var recent: some View {
        let entries = controller.history.entries.prefix(5)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").font(.title3.weight(.semibold))
                Spacer()
                Button("Show All") { navigation.pane = .history }
                    .buttonStyle(.link)
                    .disabled(entries.isEmpty)
            }
            if entries.isEmpty {
                Text("Hold \(controller.settings.hotkey.title) in any text field and speak.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.date, style: .time)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(History.preview(entry.text, limit: 90))
                        Spacer()
                    }
                }
            }
        }
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}

struct StatCard: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded))
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: size, height: size)
    }
}

struct PermissionsNotice: View {
    let controller: DictationController

    var body: some View {
        let permissions = controller.permissions
        if !permissions.microphone || !permissions.accessibility || !controller.hotkeyActive {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("SonicFlow needs a permission to work", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    HStack {
                        if !permissions.microphone {
                            Button("Allow Microphone…") { Permissions.openSettings(.microphone) }
                        }
                        if !controller.hotkeyActive {
                            Button("Allow Input Monitoring…") { Permissions.openSettings(.inputMonitoring) }
                        }
                        if !permissions.accessibility {
                            Button("Allow Accessibility…") { Permissions.openSettings(.accessibility) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
        }
    }
}
