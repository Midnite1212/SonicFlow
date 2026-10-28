import AppKit
import SonicFlowCore
import SwiftUI

struct StylesView: View {
    @Bindable var store: Personalization

    var body: some View {
        let listed = store.styles.listed { Self.url(for: $0) != nil }
        Group {
            GlassSection {
                GlassRow("Default style", hint: "Used in every app not listed below.") {
                    Picker("Default style", selection: $store.styles.defaultStyle) {
                        ForEach(WritingStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .rowPicker()
                }
            }
            GlassSection("Apps") {
                Menu("Add App") {
                    ForEach(Self.runningApps(excluding: Set(listed.map(\.bundleID))), id: \.bundleID) { app in
                        Button(app.name) { store.styles.set(store.styles.defaultStyle, for: app) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } content: {
                ForEach(listed) { app in
                    HStack(spacing: 10) {
                        AppIconImage(bundleID: app.bundleID)
                        Text(app.name).foregroundStyle(Theme.text)
                        Spacer()
                        if store.styles.overrides.contains(where: { $0.bundleID == app.bundleID }) {
                            Button("Reset", systemImage: "arrow.uturn.backward") {
                                store.styles.remove(app.bundleID)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Back to the default for this app")
                        }
                        Picker(app.name, selection: binding(for: app)) {
                            ForEach(WritingStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .rowPicker()
                    }
                    .padding(.vertical, 10)
                    if app.id != listed.last?.id { Seam() }
                }
            }
            GlassSection("How each style writes") {
                ForEach(WritingStyle.allCases, id: \.self) { style in
                    GlassRow(style.title) {
                        Text(style.example).foregroundStyle(Theme.secondary)
                    }
                    if style != WritingStyle.allCases.last { Seam() }
                }
            }
        }
        .glassColumn()
        .navigationTitle("Styles")
    }

    private func binding(for app: AppStyle) -> Binding<WritingStyle> {
        Binding(get: { app.style }, set: { store.styles.set($0, for: app) })
    }

    static func url(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private static func runningApps(excluding listed: Set<String>) -> [AppStyle] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppStyle? in
                guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier,
                    !listed.contains(id)
                else { return nil }
                return AppStyle(bundleID: id, name: app.localizedName ?? id, style: .standard)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct AppIconImage: View {
    let bundleID: String

    var body: some View {
        if let url = StylesView.url(for: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app").frame(width: 20, height: 20)
        }
    }
}
