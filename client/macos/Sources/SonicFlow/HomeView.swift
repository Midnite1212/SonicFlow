import AppKit
import SonicFlowCore
import SwiftUI

struct HomeView: View {
    let controller: DictationController
    let settingsModel: SettingsModel
    let navigation: Navigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    LatencyPanel(controller: controller)
                        .frame(maxHeight: .infinity, alignment: .top)
                    EnginePanel(controller: controller, settingsModel: settingsModel)
                        .frame(width: 290)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .fixedSize(horizontal: false, vertical: true)
                TodayStrip(stats: controller.stats)
                RecentPanel(controller: controller, navigation: navigation)
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .paneBackground()
        .navigationTitle("Home")
        .task { await settingsModel.loadBackends() }
    }
}

private struct LatencyPanel: View {
    let controller: DictationController

    var body: some View {
        let latest = controller.history.entries.first { !$0.isEdit }
        let week = Date().addingTimeInterval(-7 * 86_400)
        let median = controller.history.latencyPercentile(0.5, since: week)
        let p95 = controller.history.latencyPercentile(0.95, since: week)
        Panel("Release to text") {
            if let latest {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(latest.latencyMs.rounded()))")
                        .font(.system(size: 64, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.Speed(ms: latest.latencyMs).text)
                    Text("ms").font(.title2.weight(.medium)).foregroundStyle(Theme.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(latest.date, style: .time)
                        if let app = latest.appName { Text(app) }
                    }
                    .font(.callout)
                    .foregroundStyle(Theme.tertiary)
                }
                SpeedStripe(ms: latest.latencyMs, height: 12, showsBudget: true)
                ScaleLabels()
                VStack(spacing: 8) {
                    StripeRow(label: "7-day median", ms: median)
                    StripeRow(label: "7-day p95", ms: p95)
                }
                .padding(.top, 4)
            } else {
                Text("No dictations yet")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text("Hold \(controller.settings.hotkey.title) in any text field, speak, and release.")
                    .foregroundStyle(Theme.secondary)
                SpeedStripe(ms: nil, height: 12, showsBudget: true)
                ScaleLabels()
            }
        }
    }
}

private struct ScaleLabels: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 0) {
                Text("0")
                Spacer()
                Text("500 ms budget")
            }
            .frame(width: width * Theme.budgetMs / Theme.scaleMs)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(Theme.tertiary)
        .frame(height: 14)
    }
}

private struct StripeRow: View {
    let label: String
    let ms: Double?

    var body: some View {
        HStack(spacing: 12) {
            Text(label).foregroundStyle(Theme.secondary).frame(width: 96, alignment: .leading)
            SpeedStripe(ms: ms, height: 4)
            Text(ms.map(Format.ms) ?? "—")
                .font(.callout.monospacedDigit())
                .foregroundStyle(ms.map { Theme.Speed(ms: $0).text } ?? Theme.tertiary)
                .frame(width: 64, alignment: .trailing)
        }
        .font(.callout)
    }
}

private struct EnginePanel: View {
    let controller: DictationController
    let settingsModel: SettingsModel

    var body: some View {
        let online = controller.state != .offline
        let permissions = controller.permissions
        let missing = !permissions.microphone || !permissions.accessibility || !controller.hotkeyActive
        Panel("Engine") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(online ? Theme.ready : Theme.alert).frame(width: 8, height: 8)
                    Text(online ? "Ready" : "Offline").fontWeight(.semibold)
                }
                KeyValue("Hotkey", "\(controller.settings.hotkey.title), \(controller.settings.talkMode == .hold ? "hold" : "tap")")
                KeyValue("Speech", settingsModel.backends?.asr.active ?? "—")
                KeyValue("Cleanup", settingsModel.backends?.cleanup.active ?? "—")
                Divider().overlay(Theme.seam)
                if missing {
                    Text("Needs permission").foregroundStyle(Theme.alert)
                    if !permissions.microphone {
                        Button("Allow Microphone…") { Permissions.openSettings(.microphone) }
                    }
                    if !controller.hotkeyActive {
                        Button("Allow Input Monitoring…") { Permissions.openSettings(.inputMonitoring) }
                    }
                    if !permissions.accessibility {
                        Button("Allow Accessibility…") { Permissions.openSettings(.accessibility) }
                    }
                } else {
                    KeyValue("Permissions", "All granted")
                }
            }
            .foregroundStyle(Theme.text)
        }
    }
}

private struct KeyValue: View {
    let key: String
    let value: String

    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }

    var body: some View {
        HStack {
            Text(key).foregroundStyle(Theme.tertiary)
            Spacer()
            Text(value).lineLimit(1)
        }
        .font(.callout)
    }
}

private struct TodayStrip: View {
    let stats: UsageStats

    var body: some View {
        let today = stats.totals(lastDays: 1)
        let week = stats.totals(lastDays: 7)
        let streak = stats.streak()
        HStack(spacing: 0) {
            Figure(value: today.words.formatted(), label: "words today")
            Seam()
            Figure(value: week.wordsPerMinute.map { "\(Int($0.rounded())) wpm" } ?? "—", label: "speaking, 7 days")
            Seam()
            Figure(value: Self.duration(stats.totals(lastDays: nil).timeSavedSeconds()), label: "saved vs typing")
            Seam()
            Figure(value: streak == 1 ? "1 day" : "\(streak) days", label: "streak")
        }
        .padding(.vertical, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.seam, lineWidth: 1))
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private struct Figure: View {
        let value: String
        let label: String

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.text)
                Text(label).font(.callout).foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct Seam: View {
        var body: some View { Rectangle().fill(Theme.seam).frame(width: 1, height: 40) }
    }
}

private struct RecentPanel: View {
    let controller: DictationController
    let navigation: Navigation

    var body: some View {
        let entries = Array(controller.history.entries.prefix(6))
        Panel(
            "Recent",
            trailing: AnyView(
                Button("Show All") { navigation.pane = .history }
                    .buttonStyle(.link)
                    .foregroundStyle(Theme.secondary)
                    .disabled(entries.isEmpty)
            )
        ) {
            if entries.isEmpty {
                Text("What you dictate shows up here, with how long it took.")
                    .foregroundStyle(Theme.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        RecentRow(entry: entry)
                        if entry.id != entries.last?.id { Divider().overlay(Theme.seam) }
                    }
                }
            }
        }
    }
}

struct RecentRow: View {
    let entry: History.Entry

    var body: some View {
        HStack(spacing: 14) {
            Text(entry.date, style: .time)
                .font(.callout.monospacedDigit())
                .foregroundStyle(Theme.tertiary)
                .frame(width: 66, alignment: .leading)
            Text(entry.appName ?? "—")
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            Text(History.preview(entry.text, limit: 120))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if entry.isEdit {
                Text("Edit").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
            }
            SpeedStripe(ms: entry.latencyMs, height: 4).frame(width: 96)
            Text(Format.ms(entry.latencyMs))
                .font(.callout.monospacedDigit())
                .foregroundStyle(Theme.Speed(ms: entry.latencyMs).text)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 9)
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
