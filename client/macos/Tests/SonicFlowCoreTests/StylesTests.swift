import Foundation
import Testing

@testable import SonicFlowCore

@Test func styleResolvesOverrideThenBuiltInThenDefault() {
    var preferences = StylePreferences()
    #expect(preferences.style(for: "com.tinyspeck.slackmacgap") == .casual)
    #expect(preferences.style(for: "com.apple.mail") == .standard)
    #expect(preferences.style(for: nil) == .standard)

    preferences.defaultStyle = .lowercase
    #expect(preferences.style(for: "com.apple.mail") == .lowercase)

    let slack = StylePreferences.builtIn[0]
    preferences.set(.standard, for: slack)
    #expect(preferences.style(for: slack.bundleID) == .standard)
    preferences.remove(slack.bundleID)
    #expect(preferences.style(for: slack.bundleID) == .casual)
}

@Test func listedShowsInstalledBuiltInsMergedWithOverrides() {
    var preferences = StylePreferences()
    preferences.set(.lowercase, for: AppStyle(bundleID: "com.apple.Notes", name: "Notes", style: .standard))
    preferences.set(.standard, for: StylePreferences.builtIn[0])
    let installed: Set = ["com.tinyspeck.slackmacgap", "com.apple.Terminal"]
    let listed = preferences.listed { installed.contains($0) }
    #expect(listed.map(\.name) == ["Notes", "Slack", "Terminal"])
    #expect(listed.map(\.style) == [.lowercase, .standard, .casual])
}

@Test func preferencesRoundTripAndStartMessageCarriesStyle() throws {
    var preferences = StylePreferences()
    preferences.defaultStyle = .casual
    let decoded = try JSONDecoder().decode(
        StylePreferences.self, from: JSONEncoder().encode(preferences)
    )
    #expect(decoded == preferences)
    let json = StartMessage.json(app: nil, style: .casual, dictionary: [], snippets: [])
    #expect(json == #"{"dictionary":[],"snippets":[],"style":"casual","type":"start"}"#)
}
