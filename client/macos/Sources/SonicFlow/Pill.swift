import AppKit
import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class PillModel {
    enum Phase: Equatable {
        case idle, listening, processing
        /// The dictation landed; what was heard stays up a moment beside the cleaned text.
        case result(raw: String, cleaned: String)
    }

    static let barCount = 28

    var phase: Phase = .idle
    var command = false
    /// What the engine heard so far, as of the last pause.
    var transcript = ""
    var levels = [Float](repeating: 0, count: barCount)
    var startedAt = Date()
    var releasedAt = Date()

    func process() {
        phase = .processing
        releasedAt = Date()
    }

    func reset() {
        phase = .listening
        command = false
        transcript = ""
        levels = [Float](repeating: 0, count: Self.barCount)
        startedAt = Date()
    }

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}

/// A floating capsule near the bottom of the screen that never takes focus from the target app.
@MainActor
final class PillController {
    let model = PillModel()
    /// Room above the capsule for the transcript; the empty part is clear and lets clicks through.
    private static let size = NSSize(width: 560, height: 220)
    private var shown = 0

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: PillView(model: model))
        return panel
    }()

    func show() {
        shown += 1
        model.reset()
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let origin = NSPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + 24)
            panel.setFrame(NSRect(origin: origin, size: Self.size), display: false)
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        // An ordered-out panel keeps running its timelines, so stop them.
        model.phase = .idle
        panel.orderOut(nil)
    }

    /// Shows what was heard beside the cleaned text, for longer the more there is to read, unless
    /// the next dictation starts first.
    func showResult(raw: String, cleaned: String) {
        model.phase = .result(raw: raw, cleaned: cleaned)
        let shown = self.shown
        let seconds = min(8, 2.5 + 0.15 * Double(History.wordCount(raw)))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, self.shown == shown, case .result = self.model.phase else { return }
            self.hide()
        }
    }
}

struct PillView: View {
    let model: PillModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            switch model.phase {
            case let .result(raw, cleaned):
                TranscriptCard {
                    Text(Self.heard(raw: raw, cleaned: cleaned)).foregroundStyle(Theme.secondary)
                    Text(cleaned).foregroundStyle(Theme.text)
                }
            case .listening, .processing:
                if !model.transcript.isEmpty {
                    TranscriptCard {
                        Text(model.transcript)
                            .foregroundStyle(Theme.text)
                            .lineLimit(4)
                            .truncationMode(.head)
                    }
                }
                capsule
            case .idle:
                EmptyView()
            }
        }
        .frame(width: 560, height: 220, alignment: .bottom)
        .environment(\.colorScheme, .dark)
    }

    /// The words heard, with the ones cleanup removed struck through.
    static func heard(raw: String, cleaned: String) -> AttributedString {
        var text = AttributedString()
        for (index, word) in TranscriptDiff.heard(raw: raw, cleaned: cleaned).enumerated() {
            if index > 0 { text += AttributedString(" ") }
            var piece = AttributedString(word.text)
            if word.removed {
                piece.strikethroughStyle = .single
                piece.foregroundColor = Theme.tertiary
            }
            text += piece
        }
        return text
    }

    private var capsule: some View {
        HStack(spacing: 10) {
            if model.command {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 12)
            } else {
                Circle()
                    .fill(model.phase == .listening ? Theme.alert : Theme.tertiary)
                    .frame(width: 8, height: 8)
            }
            if model.phase == .processing {
                // The signature stripe, growing in real time from the moment of release.
                TimelineView(.animation) { context in
                    let ms = context.date.timeIntervalSince(model.releasedAt) * 1000
                    HStack(spacing: 8) {
                        SpeedStripe(ms: ms, height: 6)
                        Text("\(Int(ms))")
                            .foregroundStyle(Theme.Speed(ms: ms).text)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            } else if model.phase == .listening {
                HStack(spacing: 2) {
                    ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                        Capsule()
                            .fill(model.command ? Theme.text : Theme.cyan)
                            .frame(width: 3, height: 3 + CGFloat(min(1, level.squareRoot() * 2.5)) * 19)
                    }
                }
                .frame(height: 22)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: model.levels)
                TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                    Text(Self.elapsed(since: model.startedAt, now: context.date))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 34)
                }
            }
        }
        .font(.system(size: 12, weight: .medium).monospacedDigit())
        .padding(.horizontal, 14)
        .frame(width: 230, height: 40)
        .pillSurface()
    }

    private static func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct TranscriptCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 520)
            .cardSurface()
            .accessibilityElement(children: .combine)
    }
}

private extension View {
    @ViewBuilder func cardSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(Theme.ground.opacity(0.55)), in: shape)
        } else {
            background(Theme.ground.opacity(0.96), in: shape)
                .overlay(shape.strokeBorder(Theme.seam, lineWidth: 1))
        }
    }

    /// Liquid Glass where the system has it: the pill floats over other apps, which is what glass is for.
    @ViewBuilder func pillSurface() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(Theme.ground.opacity(0.55)), in: Capsule())
        } else {
            background(Theme.ground.opacity(0.96), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.seam, lineWidth: 1))
        }
    }
}
