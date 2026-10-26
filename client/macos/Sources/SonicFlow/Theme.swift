import AppKit
import SwiftUI

/// The night-session palette: velodrome navy with the logo's cyan, blue and violet as a speed
/// scale. Flat colour only; depth comes from a step of lightness and a hairline seam.
enum Theme {
    static let ground = Color(hex: 0x0F1A33)
    static let board = Color(hex: 0x132042)
    static let panel = Color(hex: 0x18264A)
    static let seam = Color(hex: 0x26365F)
    static let text = Color(hex: 0xE8ECF5)
    static let secondary = Color(hex: 0xAEB8D0)
    static let tertiary = Color(hex: 0x8392B5)

    static let cyan = Color(hex: 0x2FD3F0)
    static let blue = Color(hex: 0x3D6BFF)
    static let violet = Color(hex: 0x8B5CF6)
    /// Lighter steps of blue and violet for text on navy, where the stripe colours are too dark.
    static let blueText = Color(hex: 0x7F9CFF)
    static let violetText = Color(hex: 0xB59BFA)

    static let ready = Color(hex: 0x4CC38A)
    static let alert = Color(hex: 0xF2706A)

    static let groundNS = NSColor(red: 0x0F / 255, green: 0x1A / 255, blue: 0x33 / 255, alpha: 1)

    /// Every stripe shares this scale so any two latencies compare by length.
    static let scaleMs: Double = 600
    static let budgetMs: Double = 500

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
    var showsBudget = false

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
                if showsBudget {
                    Rectangle()
                        .fill(Theme.tertiary)
                        .frame(width: 1, height: height + 8)
                        .offset(x: width * Theme.budgetMs / Theme.scaleMs)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 8)
        .accessibilityLabel(ms.map { "\(Int($0.rounded())) milliseconds" } ?? "No time yet")
    }
}

/// A console panel: one step lighter than the ground, a hairline seam, a small title.
struct Panel<Content: View>: View {
    let title: String
    var trailing: AnyView?
    @ViewBuilder let content: Content

    init(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
                Spacer()
                trailing
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.seam, lineWidth: 1))
    }
}

extension View {
    /// The navy ground behind a pane, with system list and form backgrounds removed.
    func paneBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.ground)
    }

    /// Pane content as a centred column of panels on the navy ground.
    func panelColumn() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { self }
                .padding(24)
                .frame(maxWidth: 760, alignment: .topLeading)
                .frame(maxWidth: .infinity)
        }
        .paneBackground()
    }
}

/// One setting inside a panel: label on the left, its control on the right, an optional hint.
struct SettingRow<Control: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder let control: Control

    init(_ label: String, hint: String? = nil, @ViewBuilder control: () -> Control) {
        self.label = label
        self.hint = hint
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundStyle(Theme.text)
                Spacer()
                control
            }
            if let hint {
                Text(hint).font(.callout).foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    /// A picker shown as its value and a chevron, without the bordered popup and its accent cap.
    func quietPicker() -> some View {
        labelsHidden().pickerStyle(.menu).buttonStyle(.borderless).tint(Theme.secondary).fixedSize()
    }
}

struct Seam: View {
    var body: some View { Rectangle().fill(Theme.seam).frame(height: 1) }
}

enum Format {
    static func ms(_ value: Double) -> String { "\(Int(value.rounded())) ms" }
}
