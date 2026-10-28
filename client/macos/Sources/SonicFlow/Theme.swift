import AppKit
import SwiftUI

/// The night-session palette: a deep, quiet navy with the system cyan, blue and purple (the logo's
/// hues, calibrated) as a speed scale. Content is flat; glass belongs to the chrome and the pill.
enum Theme {
    static let ground = Color(hex: 0x0D111C)
    static let panel = Color(hex: 0x161D2D)
    static let seam = Color(hex: 0x262E42)
    static let text = Color(hex: 0xE8EBF2)
    static let secondary = Color(hex: 0xA4ACBF)
    static let tertiary = Color(hex: 0x8089A0)

    static let cyan = Color(hex: 0x64D2FF)
    static let blue = Color(hex: 0x0A84FF)
    static let violet = Color(hex: 0xBF5AF2)
    /// Lighter steps of blue and violet for text on navy, where the stripe colours are too dark.
    static let blueText = Color(hex: 0x5EADFF)
    static let violetText = Color(hex: 0xDA8FFF)

    static let ready = Color(hex: 0x4CC38A)
    static let alert = Color(hex: 0xF2706A)

    static let groundNS = NSColor(red: 0x0D / 255, green: 0x11 / 255, blue: 0x1C / 255, alpha: 1)

    /// Every stripe shares this scale so any two latencies compare by length.
    static let scaleMs: Double = 600
    /// Under about 100 ms a response feels instantaneous (Card, Moran & Newell; Nielsen's 0.1 s limit).
    static let instantMs: Double = 100

    enum Speed {
        case fast, normal, slow

        init(ms: Double) {
            self = ms < 200 ? .fast : ms < 500 ? .normal : .slow
        }

        var stripe: Color {
            switch self {
            case .fast: Theme.cyan
            case .normal: Theme.blue
            case .slow: Theme.violet
            }
        }

        var text: Color {
            switch self {
            case .fast: Theme.cyan
            case .normal: Theme.blueText
            case .slow: Theme.violetText
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A latency drawn as a livery stripe: its length is the time on the shared 0–600 ms scale.
struct SpeedStripe: View {
    let ms: Double?
    var height: CGFloat = 6
    var showsInstant = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.seam).frame(height: 1)
                if let ms {
                    Capsule()
                        .fill(Theme.Speed(ms: ms).stripe)
                        .frame(width: max(height, width * min(ms / Theme.scaleMs, 1)), height: height)
                }
                if let ms, ms > Theme.scaleMs {
                    // A break notch: the time runs past the scale, so the length is not to scale.
                    HStack(spacing: 2) {
                        ForEach(0..<2, id: \.self) { _ in
                            Rectangle().fill(Theme.ground).frame(width: 2, height: height + 6).rotationEffect(.degrees(20))
                        }
                    }
                    .offset(x: width - 16)
                }
                if showsInstant {
                    Rectangle()
                        .fill(Theme.tertiary)
                        .frame(width: 1, height: height + 8)
                        .offset(x: width * Theme.instantMs / Theme.scaleMs)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 8)
        .accessibilityLabel(ms.map { "\(Int($0.rounded())) milliseconds" } ?? "No time yet")
    }
}

extension View {
    /// Lets the window's ambient light show through, with system list and form backgrounds removed.
    func paneBackground() -> some View {
        scrollContentBackground(.hidden)
    }

    /// A Liquid Glass panel for the few groups that float on Home; Panel navy before macOS 26.
    @ViewBuilder func glassPanel(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(Theme.panel, in: shape)
        }
    }

    /// Apple's glass button where the system has it, a bordered button before.
    @ViewBuilder func glassButton() -> some View {
        if #available(macOS 26, *) {
            // Clear tint: the green control tint would otherwise colour every glass button.
            buttonStyle(.glass(.regular)).tint(.clear)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// A System Settings–style grouped form on the navy ground.
    func settingsForm() -> some View {
        formStyle(.grouped)
            .glassButton()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .paneBackground()
    }
}

/// A faint wash of the speed hues behind the whole window, so the glass sidebar and toolbar have light
/// to bend. Without it they sit on flat navy and read as plain panels.
struct AmbientLight: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Theme.ground
                ZStack {
                    Circle().fill(Theme.cyan.opacity(0.34))
                        .frame(width: size.width * 0.42).position(x: size.width * 0.06, y: size.height * 0.18)
                    Circle().fill(Theme.blue.opacity(0.26))
                        .frame(width: size.width * 0.5).position(x: size.width * 0.45, y: -size.height * 0.02)
                    Circle().fill(Theme.violet.opacity(0.26))
                        .frame(width: size.width * 0.34).position(x: size.width * 0.88, y: size.height * 0.3)
                    Circle().fill(Theme.violet.opacity(0.16))
                        .frame(width: size.width * 0.5).position(x: size.width * 0.7, y: size.height * 1.05)
                }
                .blur(radius: 90)
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
    }
}

/// A one-device-pixel rule, so seams stay crisp at any display scale.
struct Seam: View {
    @Environment(\.displayScale) private var scale

    var body: some View { Rectangle().fill(Theme.seam).frame(height: 1 / scale) }
}

enum Format {
    static func ms(_ value: Double) -> String { "\(Int(value.rounded())) ms" }
}
