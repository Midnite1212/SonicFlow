import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PillModel {
    enum Phase {
        case idle, listening, processing
    }

    static let barCount = 28

    var phase: Phase = .idle
    var command = false
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
    private static let size = NSSize(width: 230, height: 40)

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
}

struct PillView: View {
    let model: PillModel

    var body: some View {
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
                .animation(.linear(duration: 0.1), value: model.levels)
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
        .background(Theme.ground.opacity(0.96), in: Capsule())
        .overlay(Capsule().stroke(Theme.seam, lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private static func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
