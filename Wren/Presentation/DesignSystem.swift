import AppKit
import SwiftUI

/// "Paper & Panel": warm paper carries the human sentences, a dark graphite
/// readout carries the live numbers. Colour is reserved for health state.
enum Palette {
    // Warm paper surfaces. Cool graphite is reserved for the readout instrument.
    static let paper = Color(light: 0xF6F2EB, dark: 0x1B1815)
    static let paperCard = Color(light: 0xFFFBF4, dark: 0x262119)
    static let ink = Color(light: 0x241F1A, dark: 0xF1EAE0)
    static let inkSoft = Color(light: 0x6E6357, dark: 0xA2968A)
    static let rule = Color(light: 0xE3DACC, dark: 0x3A3229)

    static let readout = Color(light: 0x12151C, dark: 0x12151C)
    static let readoutCard = Color(light: 0x1A1F28, dark: 0x1A1F28)
    static let readoutInk = Color(light: 0xE9EDF5, dark: 0xE9EDF5)
    static let readoutSoft = Color(light: 0x8A93A6, dark: 0x8A93A6)
    static let readoutRule = Color(light: 0x2A3140, dark: 0x2A3140)

    static let accent = Color(light: 0x3A4BA0, dark: 0x9BA6F0)

    static func health(_ level: HealthLevel) -> Color {
        switch level {
        case .normal: return healthNormal
        case .moderateLoad: return healthModerateLoad
        case .highLoad: return healthHighLoad
        case .potentialProblem: return healthPotentialProblem
        }
    }

    // Cached like every other palette entry. Building these per call allocated
    // a fresh dynamic NSColor for each row on each sample.
    private static let healthNormal = Color(light: 0x3E8F63, dark: 0x5CBE8B)
    private static let healthModerateLoad = Color(light: 0xB7832E, dark: 0xDCA84E)
    private static let healthHighLoad = Color(light: 0xB96A2E, dark: 0xDE9254)
    private static let healthPotentialProblem = Color(light: 0xB2453E, dark: 0xE0706A)
}

/// Two voices: New York for sentences a person wrote, rounded sans for
/// instrument labels, mono for values the machine reports.
enum Typeface {
    static func verdict() -> Font { .system(size: 25, weight: .semibold, design: .serif) }
    static func prose(_ size: CGFloat = 14.5) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func proseEmphasis(_ size: CGFloat = 15.5) -> Font { .system(size: size, weight: .semibold, design: .serif) }

    static func eyebrow() -> Font { .system(size: 10, weight: .semibold, design: .rounded) }
    static func heading(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }

    static func data(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
    static func dataLarge(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

enum Metrics {
    static let cardRadius: CGFloat = 14
    static let readoutRadius: CGFloat = 18
    static let tileRadius: CGFloat = 10
}

enum Motion {
    static let settle = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let drift = Animation.easeInOut(duration: 0.2)
    static let reveal = Animation.easeOut(duration: 0.28)
    static let arrive = Animation.easeOut(duration: 0.15)

    /// These are for moments that happen once — a hover, a tab change, a row
    /// arriving — never for values that change on every sample. An animation
    /// in flight re-rasterizes the window's text at display refresh and keeps
    /// glyph bitmaps churning in the heap; one 0.2s easing per one-second
    /// tick measured +40% CPU and +140MB. Per-sample values snap instead.
    ///
    /// Respects Reduce Motion by collapsing animation to an instant change.
    static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : animation
    }
}

extension Color {
    /// Adaptive colour driven by light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Surface treatments

struct PaperCardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .fill(Palette.paperCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.rule, lineWidth: 1)
            )
    }
}

extension View {
    func paperCard(padding: CGFloat = 16) -> some View {
        modifier(PaperCardStyle(padding: padding))
    }
}

/// Tracked-out section marker with a hairline running to the edge of the column.
struct SectionEyebrow: View {
    let title: String
    var tint: Color = Palette.inkSoft

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(Typeface.eyebrow())
                .tracking(1.1)
                .foregroundStyle(tint)
            Rectangle()
                .fill(tint.opacity(0.28))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
