import AppKit
import SwiftUI

/// The "field notebook" look: warm paper, ink, and a red pencil for the one thing that matters.
/// Every colour has a night-notebook twin for dark mode.
enum Theme {
    static let paper = dynamic(light: 0xF6F1E6, dark: 0x1C1916)
    static let paperRaised = dynamic(light: 0xFBF8F1, dark: 0x25211C)
    static let sidebar = dynamic(light: 0xEDE5D4, dark: 0x161411)
    static let ink = dynamic(light: 0x1F1B16, dark: 0xEDE6D6)
    static let inkMuted = dynamic(light: 0x524636, dark: 0xC9BEA8)  // 8:1 on paper
    static let inkFaint = dynamic(light: 0x6E604A, dark: 0xA89B83)  // 5.4:1, still readable
    static let rule = dynamic(light: 0xE4DCCB, dark: 0x2A2621)
    static let marginLine = dynamic(light: 0xD9826F, dark: 0x6E3A2F)
    static let pencil = dynamic(light: 0xC8402D, dark: 0xE2705B)

    // Older names, kept so every view picks up the notebook palette.
    static let brand = pencil
    static let brandText = pencil
    static let brandGradient = LinearGradient(colors: [pencil, pencil], startPoint: .top, endPoint: .bottom)

    static let good = dynamic(light: 0x3E7D4F, dark: 0x7DBB8C)
    static let partial = dynamic(light: 0xA86B12, dark: 0xE0A84A)
    static let bad = dynamic(light: 0xB3261E, dark: 0xF07A6A)

    static func scoreColor(_ points: Int) -> Color {
        points >= 2 ? good : points == 1 ? partial : bad
    }

    static let cardFill = paperRaised
    static let cardStroke = dynamic(light: 0xD8CDB6, dark: 0x3A342C)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    /// New York, the system serif: used for anything you read (titles, questions, notes).
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Small, tracked, uppercase sans: the labels you'd write in the margin.
    static let label = Font.system(size: 10.5, weight: .bold)
}

extension Skill {
    /// Ink colours rather than bright UI colours, so the page stays calm.
    var color: Color {
        switch self {
        case .scoping: return Theme.dynamic(light: 0x5A5348, dark: 0xB5AB9A)
        case .design: return Theme.dynamic(light: 0x5B3A7A, dark: 0xB79AD6)
        case .systemDesign: return Theme.dynamic(light: 0x3B5A6E, dark: 0x93B4C9)
        case .readingCode: return Theme.dynamic(light: 0x2F4B7C, dark: 0x8AA6D6)
        case .testing: return Theme.dynamic(light: 0x3E7D4F, dark: 0x7DBB8C)
        case .codeReview: return Theme.dynamic(light: 0x2D6E6A, dark: 0x7CC2BC)
        case .shipping: return Theme.dynamic(light: 0xA86B12, dark: 0xE0A84A)
        case .operating: return Theme.dynamic(light: 0x7A4A2A, dark: 0xD39C78)
        case .debugging: return Theme.dynamic(light: 0x9E2B25, dark: 0xE88A80)
        case .explaining: return Theme.dynamic(light: 0x8A3B62, dark: 0xD98CB2)
        }
    }
}

func roman(_ n: Int) -> String {
    ["", "I", "II", "III", "IV", "V"][max(0, min(5, n))]
}

// MARK: - Paper

/// Ruled notebook paper. Purely decorative, so it stays faint.
struct RuledPaper: View {
    var spacing: CGFloat = 28
    var marginX: CGFloat?

    var body: some View {
        Canvas { ctx, size in
            var y = spacing
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Theme.rule))
                y += spacing
            }
            if let marginX {
                ctx.fill(Path(CGRect(x: marginX, y: 0, width: 1, height: size.height)),
                         with: .color(Theme.marginLine.opacity(0.7)))
            }
        }
        .background(Theme.paper)
    }
}

/// A rubber stamp for milestones: tilted, pencil-red, a little faded.
struct Stamp: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(1.1)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.pencil)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(Rectangle().strokeBorder(Theme.pencil, lineWidth: 1.8))
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .rotationEffect(.degrees(6))
            .opacity(0.88)
    }
}

/// An index card on the "known cold" shelf.
struct IndexCard: View {
    let text: String
    var tilt: Double = 0.6

    var body: some View {
        // Only the card is tilted. Rotating the text itself by a fraction of a degree blurs it.
        Text(text)
            .font(.serif(12.5))
            .foregroundStyle(Theme.ink)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Rectangle()
                    .fill(Theme.paperRaised)
                    .overlay(Rectangle().strokeBorder(Theme.cardStroke))
                    .shadow(color: Theme.rule, radius: 0, x: 1, y: 2)
                    .rotationEffect(.degrees(tilt))
            )
    }
}

// MARK: - Building blocks

struct CardModifier: ViewModifier {
    var padding: CGFloat = 12
    var radius: CGFloat = 3
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.cardFill))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(highlighted ? Theme.ink : Theme.cardStroke, lineWidth: highlighted ? 1.5 : 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 12, radius: CGFloat = 3, highlighted: Bool = false) -> some View {
        modifier(CardModifier(padding: padding, radius: radius, highlighted: highlighted))
    }
}

/// Red pencil block with small uppercase text, like a stamped instruction.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10.5 : 11.5, weight: .bold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(Theme.paperRaised)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 5 : 7)
            .background(Rectangle().fill(Theme.pencil))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

/// Ink outline: for secondary actions.
struct SoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Rectangle().fill(tint.opacity(configuration.isPressed ? 0.1 : 0)))
            .overlay(Rectangle().strokeBorder(tint.opacity(0.45)))
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.inkMuted)
            .frame(width: 26, height: 26)
            .overlay(Rectangle().strokeBorder(Theme.cardStroke))
            .background(Rectangle().fill(Theme.ink.opacity(configuration.isPressed ? 0.08 : 0)))
            .contentShape(Rectangle())
    }
}

struct Chip: View {
    let text: String
    var icon: String?
    var color: Color = Theme.pencil
    var mono = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
            Text(text).font(.system(size: 10, weight: .bold, design: mono ? .monospaced : .default)).tracking(0.4)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(color.opacity(0.5)))
    }
}

/// Pencil-red margin label: "THIS WEEK", "CHAPTERS".
struct SectionHeader: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.label)
                .tracking(1.4)
                .foregroundStyle(Theme.pencil)
            if let count {
                Text("\(count)").font(.label).foregroundStyle(Theme.inkFaint)
            }
            Spacer()
        }
    }
}

struct ScoreRing: View {
    let value: Double
    var color: Color = Theme.pencil
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(Theme.rule, lineWidth: lineWidth)
            if value > 0 {
                Circle()
                    .trim(from: 0, to: min(1, value))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

/// ●●○○○ progress through a chapter, or through a review item's streak.
struct Dots: View {
    let filled: Int
    let total: Int
    var color: Color = Theme.pencil

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < filled ? color : .clear)
                    .overlay(Circle().strokeBorder(color.opacity(i < filled ? 0 : 0.6), lineWidth: 1))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(Rectangle().fill(Theme.ink.opacity(hovering ? 0.04 : 0)))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }
}
