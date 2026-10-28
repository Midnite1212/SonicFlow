import AppKit
import Observation
import SonicFlowCore
import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case home, history, dictionary, snippets, styles, models, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .dictionary: "Dictionary"
        case .snippets: "Snippets"
        case .styles: "Styles"
        case .models: "Models"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        case .snippets: "text.insert"
        case .styles: "textformat"
        case .models: "cpu"
        case .settings: "gearshape"
        }
    }
}

@MainActor
@Observable
final class Navigation {
    var pane: Pane? = .home
    let history = HistoryViewModel()
    let onboarding = OnboardingModel()
    let models = ModelsModel()
    let vocabulary = VocabularyModel()
}

/// Owns the app window. SonicFlow is a menu-bar accessory, so it joins the Dock and the app
/// switcher only while this window is open.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    let navigation = Navigation()
    private let controller: DictationController
    private let settingsModel: SettingsModel
    private var window: NSWindow?

    init(controller: DictationController, settingsModel: SettingsModel) {
        self.controller = controller
        self.settingsModel = settingsModel
    }

    func show(_ pane: Pane? = nil) {
        if let pane { navigation.pane = pane }
        let window = window ?? makeWindow()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let root = RootView(controller: controller, settingsModel: settingsModel, navigation: navigation)
        let hosting = NSHostingController(rootView: root)
        // By default the window resizes to the content's ideal size, which a List makes enormous.
        hosting.sizingOptions = []
        hosting.sceneBridgingOptions = [.title, .toolbars]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.title = (navigation.pane ?? .home).title
        // The window is the night-session world in either system appearance.
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.groundNS
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 980, height: 680))
        window.contentMinSize = NSSize(width: 820, height: 560)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("SonicFlowMain")
        self.window = window
        return window
    }
}

struct RootView: View {
    let controller: DictationController
    let settingsModel: SettingsModel
    @Bindable var navigation: Navigation

    var body: some View {
        // Affirmative green, so switches and default buttons never borrow a speed colour.
        content.tint(Theme.ready).background(AmbientLight())
    }

    @ViewBuilder private var content: some View {
        if controller.settings.onboarded {
            NavigationSplitView {
                List {
                    Section { rows(.home, .history) }
                    Section("Personalize") { rows(.dictionary, .snippets, .styles) }
                    Section("Setup") { rows(.models, .settings) }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 200, ideal: 210, max: 240)
            } detail: {
                switch navigation.pane ?? .home {
                case .home:
                    HomeView(controller: controller, settingsModel: settingsModel, navigation: navigation)
                case .history: HistoryView(
                        controller: controller, settings: controller.settings, model: navigation.history
                    )
                case .dictionary: DictionaryView(store: controller.personalization, model: navigation.vocabulary)
                case .snippets: SnippetsView(store: controller.personalization, model: navigation.vocabulary)
                case .styles: StylesView(store: controller.personalization)
                case .models: ModelsView(model: navigation.models)
                case .settings:
                    SettingsView(
                        controller: controller, settings: controller.settings, model: settingsModel,
                        navigation: navigation
                    )
                }
            }
        } else {
            OnboardingView(
                controller: controller, settings: controller.settings, settingsModel: settingsModel,
                model: navigation.onboarding
            )
        }
    }

    /// Rows draw their own selection: the native one is the system accent blue, which SwiftUI's tint
    /// can't reach without an asset catalog.
    private func rows(_ panes: Pane...) -> some View {
        ForEach(panes) { pane in
            Button { navigation.pane = pane } label: {
                Label(pane.title, systemImage: pane.symbol)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .badge(count(pane))
            .listRowBackground(SidebarSelection(isSelected: (navigation.pane ?? .home) == pane))
            .accessibilityAddTraits((navigation.pane ?? .home) == pane ? .isSelected : [])
        }
    }

    private func count(_ pane: Pane) -> Int {
        switch pane {
        case .history: controller.history.entries.count
        case .dictionary: controller.personalization.terms.count
        case .snippets: controller.personalization.snippets.count
        default: 0
        }
    }
}

private struct SidebarSelection: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(isSelected ? 0.11 : 0))
            .padding(.horizontal, 10)
    }
}
