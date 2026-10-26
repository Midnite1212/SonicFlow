import Foundation

public enum WritingStyle: String, CaseIterable, Codable, Sendable {
    case standard, casual, lowercase

    public var title: String {
        switch self {
        case .standard: "Standard"
        case .casual: "Casual"
        case .lowercase: "Lowercase"
        }
    }

    public var example: String {
        switch self {
        case .standard: "Sounds good. I'll send it tonight."
        case .casual: "Sounds good. I'll send it tonight"
        case .lowercase: "sounds good. I'll send it tonight"
        }
    }
}

public struct AppStyle: Identifiable, Codable, Equatable, Sendable {
    public var id: String { bundleID }
    public let bundleID: String
    public let name: String
    public var style: WritingStyle

    public init(bundleID: String, name: String, style: WritingStyle) {
        self.bundleID = bundleID
        self.name = name
        self.style = style
    }
}

/// Which style each app gets: the user's choice for that app, else a built-in default for chat
/// apps and terminals, else the default style.
public struct StylePreferences: Codable, Equatable, Sendable {
    public static let builtIn: [AppStyle] = [
        AppStyle(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", style: .casual),
        AppStyle(bundleID: "com.apple.MobileSMS", name: "Messages", style: .casual),
        AppStyle(bundleID: "com.hnc.Discord", name: "Discord", style: .casual),
        AppStyle(bundleID: "net.whatsapp.WhatsApp", name: "WhatsApp", style: .casual),
        AppStyle(bundleID: "ru.keepcoder.Telegram", name: "Telegram", style: .casual),
        AppStyle(bundleID: "com.microsoft.teams2", name: "Microsoft Teams", style: .casual),
        AppStyle(bundleID: "com.apple.Terminal", name: "Terminal", style: .casual),
        AppStyle(bundleID: "com.googlecode.iterm2", name: "iTerm", style: .casual),
        AppStyle(bundleID: "com.mitchellh.ghostty", name: "Ghostty", style: .casual),
        AppStyle(bundleID: "dev.warp.Warp-Stable", name: "Warp", style: .casual),
    ]

    public var defaultStyle: WritingStyle = .standard
    public private(set) var overrides: [AppStyle] = []

    public init() {}

    public func style(for bundleID: String?) -> WritingStyle {
        guard let bundleID else { return defaultStyle }
        return (overrides.first { $0.bundleID == bundleID }
            ?? Self.builtIn.first { $0.bundleID == bundleID })?.style ?? defaultStyle
    }

    /// Built-ins for the apps `isInstalled` accepts plus every override, sorted by name.
    public func listed(isInstalled: (String) -> Bool) -> [AppStyle] {
        var apps = Self.builtIn.filter { isInstalled($0.bundleID) }
        for app in overrides {
            if let index = apps.firstIndex(where: { $0.bundleID == app.bundleID }) {
                apps[index] = app
            } else {
                apps.append(app)
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public mutating func set(_ style: WritingStyle, for app: AppStyle) {
        overrides.removeAll { $0.bundleID == app.bundleID }
        overrides.append(AppStyle(bundleID: app.bundleID, name: app.name, style: style))
    }

    public mutating func remove(_ bundleID: String) {
        overrides.removeAll { $0.bundleID == bundleID }
    }
}
