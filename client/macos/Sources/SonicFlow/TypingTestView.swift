import Observation
import SonicFlowCore
import SwiftUI

/// One run of the typing test. Only the resulting speed is kept; the typed text is discarded.
@MainActor
@Observable
final class TypingTestModel: Identifiable {
    let passage = TypingTest.passages.randomElement()!
    private(set) var startedAt: Date?
    private(set) var finishedAt: Date?

    var typed = "" {
        didSet {
            if startedAt == nil, !typed.isEmpty { startedAt = Date() }
            if finishedAt == nil, typed.count >= passage.count { finishedAt = Date() }
        }
    }

    func wordsPerMinute(at now: Date) -> Double? {
        guard let startedAt else { return nil }
        let seconds = (finishedAt ?? now).timeIntervalSince(startedAt)
        return seconds < 1 ? nil : TypingTest.wordsPerMinute(typed: typed, passage: passage, seconds: seconds)
    }
}

struct TypingTestView: View {
    @Bindable var model: TypingTestModel
    let save: (Double) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typing Test").font(.title2.weight(.semibold))
            Text("Type the passage below at your normal pace. The timer starts with your first key.")
                .foregroundStyle(Theme.secondary)
            passage
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            TextField("Start typing here", text: $model.typed, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
                .autocorrectionDisabled()
            HStack {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let speed = model.wordsPerMinute(at: context.date)
                    Text(speed.map { "\(Int($0.rounded())) wpm" } ?? "— wpm")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(speed == nil ? Theme.tertiary : Theme.text)
                }
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Use This Speed") {
                    if let speed = model.wordsPerMinute(at: Date()) { save(speed) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.finishedAt == nil)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    /// The passage, with typed characters shown as correct or wrong and the rest dimmed.
    private var passage: Text {
        var text = AttributedString(model.passage)
        let typed = Array(model.typed)
        for (offset, index) in text.characters.indices.enumerated() {
            let next = text.characters.index(after: index)
            text[index..<next].foregroundColor =
                offset >= typed.count
                ? Theme.tertiary : typed[offset] == text.characters[index] ? Theme.text : Theme.alert
        }
        return Text(text).font(.title3)
    }
}
