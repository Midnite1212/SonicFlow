import AppKit
import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class PairingModel: Identifiable {
    var code: String
    var message: String?
    var busy = false

    /// Starts from the clipboard when it holds a pairing code, as it does after Copy on the other Mac.
    init() {
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        code = EngineEndpoint(pairingCode: clipboard) == nil ? "" : clipboard
    }
}

struct PairingView: View {
    @Bindable var model: PairingModel
    let pair: (String) async throws -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pair with Another Mac").font(.title2.weight(.semibold))
            Text(
                "On the Mac whose engine you want to use, open SonicFlow › Settings, turn on Share this "
                    + "Mac's engine, and copy its pairing code. Both Macs need to be on the same network."
            )
            .foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            TextField("Pairing code", text: $model.code, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .font(.callout.monospaced())
                .autocorrectionDisabled()
            if let message = model.message {
                Text(message).foregroundStyle(Theme.alert).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Pair") {
                    Task {
                        model.busy = true
                        model.message = nil
                        do {
                            try await pair(model.code)
                        } catch {
                            model.message = error.localizedDescription
                        }
                        model.busy = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.busy || EngineEndpoint(pairingCode: model.code) == nil)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
