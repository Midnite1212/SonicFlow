import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PillModel {
    enum Phase {
        case listening, processing
    }

    static let barCount = 28

    var phase: Phase = .listening
    var levels = [Float](repeating: 0, count: barCount)
    var startedAt = Date()

    func reset() {
        phase = .listening
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
        panel.orderOut(nil)
    }
}

struct PillView: View {
    let model: PillModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.phase == .listening ? Color.red : Color.secondary)
                .frame(width: 8, height: 8)
            HStack(spacing: 2) {
                ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Color.primary.opacity(0.75))
                        .frame(width: 3, height: 3 + CGFloat(min(1, level.squareRoot() * 2.5)) * 19)
                }
            }
            .frame(height: 22)
            .animation(.linear(duration: 0.1), value: model.levels)
            Group {
                if model.phase == .processing {
                    ProgressView().controlSize(.small)
                } else {
                    TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                        Text(Self.elapsed(since: model.startedAt, now: context.date))
                    }
                }
            }
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .frame(width: 34)
        }
        .padding(.horizontal, 14)
        .frame(width: 230, height: 40)
        .background(.regularMaterial, in: Capsule())
    }

    private static func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
