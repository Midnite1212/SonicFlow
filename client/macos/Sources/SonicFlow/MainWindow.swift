import AppKit
import Observation
import SonicFlowCore
import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case home, history, dictionary, snippets, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .dictionary: "Dictionary"
        case .snippets: "Snippets"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        case .snippets: "text.insert"
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
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "SonicFlow"
        window.setContentSize(NSSize(width: 860, height: 600))
        window.contentMinSize = NSSize(width: 720, height: 480)
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
        if controller.settings.onboarded {
            NavigationSplitView {
                List(Pane.allCases, selection: $navigation.pane) { pane in
                    Label(pane.title, systemImage: pane.symbol).tag(pane)
                }
                .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
            } detail: {
                switch navigation.pane ?? .home {
                case .home: HomeView(controller: controller, navigation: navigation)
                case .history: HistoryView(
                        controller: controller, settings: controller.settings, model: navigation.history
                    )
                case .dictionary: DictionaryView(store: controller.vocabulary)
                case .snippets: SnippetsView(store: controller.vocabulary)
                case .settings: SettingsView(settings: controller.settings, model: settingsModel)
                }
            }
        } else {
            OnboardingView(
                controller: controller, settings: controller.settings, settingsModel: settingsModel,
                model: navigation.onboarding
            )
        }
    }
}
