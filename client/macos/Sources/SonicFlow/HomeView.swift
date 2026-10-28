import AppKit
import SonicFlowCore
import SwiftUI

struct HomeView: View {
    let controller: DictationController
    let settingsModel: SettingsModel
    let navigation: Navigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    LatencyBoard(controller: controller, settingsModel: settingsModel, navigation: navigation)
                        .padding(.trailing, 32)
                    Rectangle().fill(Theme.seam).frame(width: 1)
                    EngineColumn(controller: controller, settingsModel: settingsModel)
                        .frame(width: 250)
                        .padding(.leading, 32)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 32)
                TodayStrip(
                    stats: controller.stats,
                    typingSpeed: controller.settings.typingWordsPerMinute ?? TypingTest.averageWordsPerMinute
                )
                RecentList(controller: controller, navigation: navigation)
                    .padding(.top, 32)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .paneBackground()
        .navigationTitle("Home")
        .task { await settingsModel.loadBackends() }
    }
}

/// The typical speed leads, so one slow dictation can't paint the headline; the latest sits below.
private struct LatencyBoard: View {
    let controller: DictationController
    let settingsModel: SettingsModel
    let navigation: Navigation

    var body: some View {
        let latest = controller.history.entries.first { !$0.isEdit }
        let week = Date().addingTimeInterval(-7 * 86_400)
        let median = controller.history.latencyPercentile(0.5, since: week)
        let p95 = controller.history.latencyPercentile(0.95, since: week)
        VStack(alignment: .leading, spacing: 0) {
            if let hero = median ?? latest?.latencyMs {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(Int(hero.rounded()))")
                        .font(.system(size: 64, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.Speed(ms: hero).text)
                    Text("ms").font(.title2.weight(.medium)).foregroundStyle(Theme.secondary)
                }
                Text(median == nil ? "Release to text, latest dictation" : "Release to text, median of the last 7 days")
                    .foregroundStyle(Theme.secondary)
                typingComparison(since: week)
                SpeedStripe(ms: hero, height: 12, showsInstant: true)
                    .padding(.top, 22)
                ScaleLabels()
                    .padding(.top, 2)
                VStack(spacing: 10) {
                    StripeRow(label: "Latest", ms: latest?.latencyMs)
                    StripeRow(label: "Slowest 5%", ms: p95)
                }
                .padding(.top, 20)
            } else {
                Text("No dictations yet")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text("Hold \(controller.settings.hotkey.title) in any text field, speak, and release.")
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 4)
                SpeedStripe(ms: nil, height: 12, showsInstant: true)
                    .padding(.top, 22)
                ScaleLabels()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the same words would cost at the keyboard, at the user's measured speed when they have one.
    @ViewBuilder private func typingComparison(since cutoff: Date) -> some View {
        let words = controller.history.entries.filter { !$0.isEdit && $0.date >= cutoff }.map(\.wordCount).sorted()
        if !words.isEmpty {
            let typical = words[words.count / 2]
            let measured = controller.settings.typingWordsPerMinute
            let speed = measured ?? TypingTest.averageWordsPerMinute
            let seconds = TypingTest.secondsToType(words: typical, wordsPerMinute: speed)
            HStack(spacing: 6) {
                Text("Typing a typical \(typical)-word dictation at \(Int(speed.rounded())) wpm takes about \(Self.duration(seconds)).")
                    .foregroundStyle(Theme.tertiary)
                if measured == nil {
                    Button("Measure Yours") {
                        navigation.pane = .settings
                        settingsModel.typingTest = TypingTestModel()
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(Theme.secondary)
                    .focusable(false)
                }
            }
            .font(.callout)
            .padding(.top, 2)
        }
    }

    static func duration(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        return whole < 60 ? "\(whole) s" : "\(whole / 60) min \(whole % 60) s"
    }
}

private struct ScaleLabels: View {
    var body: some View {
        GeometryReader { geometry in
            let tick = geometry.size.width * Theme.instantMs / Theme.scaleMs
            ZStack(alignment: .leading) {
                Text("0")
                Text("100 ms, feels instant").offset(x: tick + 6)
            }
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
            Text(label).foregroundStyle(Theme.secondary).frame(width: 84, alignment: .leading)
            SpeedStripe(ms: ms, height: 4)
            Text(ms.map(Format.ms) ?? "—")
                .monospacedDigit()
                .foregroundStyle(ms.map { Theme.Speed(ms: $0).text } ?? Theme.tertiary)
                .frame(width: 64, alignment: .trailing)
        }
        .font(.callout)
    }
}

private struct EngineColumn: View {
    let controller: DictationController
    let settingsModel: SettingsModel

    var body: some View {
        let online = controller.state != .offline
        let permissions = controller.permissions
        let missing = !permissions.microphone || !permissions.accessibility || !controller.hotkeyActive
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(online ? Theme.ready : Theme.alert).frame(width: 8, height: 8)
                Text(online ? "Engine ready" : "Engine offline")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            KeyValue("Hotkey", controller.settings.hotkey.title)
            KeyValue("Mode", controller.settings.talkMode == .hold ? "Hold to talk" : "Tap to toggle")
            KeyValue("Speech", settingsModel.backends?.asr.active ?? "—")
            KeyValue("Cleanup", settingsModel.backends?.cleanup.active ?? "—")
            if missing {
                Text("Needs permission").foregroundStyle(Theme.alert).padding(.top, 4)
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
        .controlSize(.small)
        .foregroundStyle(Theme.text)
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

/// Today's figures as a ruled band, like the lap counters under a timing board.
private struct TodayStrip: View {
    let stats: UsageStats
    let typingSpeed: Double

    var body: some View {
        let today = stats.totals(lastDays: 1)
        let week = stats.totals(lastDays: 7)
        let streak = stats.streak()
        HStack(spacing: 0) {
            Figure(value: today.words.formatted(), label: "words today", leading: 0)
            Rule()
            Figure(value: week.wordsPerMinute.map { "\(Int($0.rounded())) wpm" } ?? "—", label: "speaking pace, 7 days")
            Rule()
            Figure(
                value: Self.duration(stats.totals(lastDays: nil).timeSavedSeconds(typingWordsPerMinute: typingSpeed)),
                label: "saved vs typing"
            )
            Rule()
            Figure(value: streak == 1 ? "1 day" : "\(streak) days", label: "streak")
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Seam() }
        .overlay(alignment: .bottom) { Seam() }
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private struct Figure: View {
        let value: String
        let label: String
        var leading: CGFloat = 24

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.text)
                Text(label).font(.callout).foregroundStyle(Theme.tertiary)
            }
            .padding(.leading, leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private struct Rule: View {
        var body: some View { Rectangle().fill(Theme.seam).frame(width: 1, height: 40) }
    }
}

private struct RecentList: View {
    let controller: DictationController
    let navigation: Navigation

    var body: some View {
        let entries = Array(controller.history.entries.prefix(8))
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent").font(.headline).foregroundStyle(Theme.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Show All") { navigation.pane = .history }
                    .glassButton()
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(entries.isEmpty)
            }
            if entries.isEmpty {
                Text("What you dictate shows up here, with how long it took.")
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        RecentRow(entry: entry)
                        if entry.id != entries.last?.id { Seam() }
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
