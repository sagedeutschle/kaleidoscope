// PRISM: RELEASE Agent-Design(shell) 2026-07-03 — v10 design pass
import SwiftUI

// Kaleidoscope design system (iOS) — "rustic scroll + kaleidoscope iris", paper-aware
// for readability. Trimmed from the macOS app: pure SwiftUI, no AppKit, no image asset.

enum KaleidoPaper: String, CaseIterable, Identifiable {
    case contrast = "High Contrast"
    case parchment = "Parchment"
    case dark = "Dark"
    var id: String { rawValue }
}

enum Kaleido {
    static let paperKey = "kaleido.paper"
    // v10: the cabinet is dark by default — stored choices always win.
    static var paper: KaleidoPaper {
        KaleidoPaper(rawValue: UserDefaults.standard.string(forKey: paperKey) ?? "") ?? .dark
    }

    struct Palette {
        var ground, panel, panelHi, hairline, outline, ink, ink2, ink3: Color
        var isDark: Bool
    }

    static var palette: Palette { palette(for: paper) }

    /// Palette for an arbitrary paper — lets the shell (Settings) render true-color
    /// swatches for papers other than the active one.
    static func palette(for paper: KaleidoPaper) -> Palette {
        switch paper {
        case .contrast:
            let ink = Color(red: 0.11, green: 0.10, blue: 0.07)
            return Palette(ground: Color(red: 0.964, green: 0.950, blue: 0.912),
                           panel: Color(red: 0.993, green: 0.985, blue: 0.964),
                           panelHi: Color(red: 0.902, green: 0.878, blue: 0.818),
                           hairline: Color.black.opacity(0.20), outline: Color.black.opacity(0.36),
                           ink: ink, ink2: ink.opacity(0.82), ink3: ink.opacity(0.58), isDark: false)
        case .parchment:
            let ink = Color(red: 0.16, green: 0.11, blue: 0.05)
            return Palette(ground: Color(red: 0.937, green: 0.902, blue: 0.816),
                           panel: Color(red: 0.968, green: 0.940, blue: 0.872),
                           panelHi: Color(red: 0.900, green: 0.852, blue: 0.742),
                           hairline: Color(red: 0.34, green: 0.24, blue: 0.12).opacity(0.30),
                           outline: Color(red: 0.34, green: 0.24, blue: 0.12).opacity(0.50),
                           ink: ink, ink2: ink.opacity(0.76), ink3: ink.opacity(0.54), isDark: false)
        case .dark:
            let ink = Color(red: 0.95, green: 0.96, blue: 0.99)
            return Palette(ground: Color(red: 0.063, green: 0.067, blue: 0.102),
                           panel: Color(red: 0.106, green: 0.114, blue: 0.165),
                           panelHi: Color(red: 0.157, green: 0.169, blue: 0.235),
                           hairline: Color.white.opacity(0.10), outline: Color.white.opacity(0.18),
                           ink: ink, ink2: ink.opacity(0.66), ink3: ink.opacity(0.42), isDark: true)
        }
    }

    static var ground: Color { palette.ground }
    static var panel: Color { palette.panel }
    static var panelHi: Color { palette.panelHi }
    static var hairline: Color { palette.hairline }
    static var outline: Color { palette.outline }
    static var ink: Color { palette.ink }
    static var ink2: Color { palette.ink2 }
    static var ink3: Color { palette.ink3 }
    static var isDark: Bool { palette.isDark }

    static let gold = Color(red: 0.72, green: 0.54, blue: 0.20)

    static let wheel: [Color] = [
        Color(red: 0.86, green: 0.28, blue: 0.34), Color(red: 0.90, green: 0.55, blue: 0.20),
        Color(red: 0.80, green: 0.66, blue: 0.22), Color(red: 0.30, green: 0.55, blue: 0.42),
        Color(red: 0.24, green: 0.46, blue: 0.66), Color(red: 0.46, green: 0.34, blue: 0.62),
        Color(red: 0.86, green: 0.28, blue: 0.34)
    ]

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

func irisColors(_ accent: Color) -> [Color] {
    [accent, accent.opacity(0.40), Kaleido.gold.opacity(0.6), accent.opacity(0.40), accent]
}

struct FacetBackdrop: View {
    var accent: Color
    var multiHue: Bool = false
    var body: some View {
        ZStack {
            Kaleido.ground
            RadialGradient(colors: [accent.opacity(multiHue ? 0.18 : 0.13), .clear],
                           center: .topLeading, startRadius: 6, endRadius: 520)
            if multiHue {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: Kaleido.wheel), center: .center))
                    .frame(width: 520, height: 520).blur(radius: 150).opacity(0.16)
                    .offset(x: 120, y: -200)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func facetBackground(_ accent: Color, multiHue: Bool = false) -> some View {
        background(FacetBackdrop(accent: accent, multiHue: multiHue))
    }
    func kaleidoCard(cornerRadius: CGFloat = 16) -> some View {
        padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Kaleido.panel)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Kaleido.outline, lineWidth: 1))
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
    }
}

struct GameHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Circle().strokeBorder(AngularGradient(gradient: Gradient(colors: irisColors(accent)), center: .center), lineWidth: 2.5)
                Image(systemName: systemImage).font(.system(size: 20, weight: .bold)).foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Kaleido.title(26)).foregroundStyle(Kaleido.ink)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Kaleido.ink2) }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension GameHeader where Trailing == EmptyView {
    init(title: String, systemImage: String, accent: Color, subtitle: String? = nil) {
        self.init(title: title, systemImage: systemImage, accent: accent, subtitle: subtitle) { EmptyView() }
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    var accent: Color = Kaleido.ink
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(Kaleido.ink3)
            Text(value).font(Kaleido.rounded(22)).monospacedDigit().foregroundStyle(accent)
        }
        .frame(minWidth: 60, alignment: .trailing)
    }
}

struct AccentButtonStyle: ButtonStyle {
    var accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(accent.gradient)).foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.82 : 1).scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(Kaleido.panelHi).overlay(Capsule().strokeBorder(Kaleido.outline, lineWidth: 1)))
            .foregroundStyle(Kaleido.ink)
            .opacity(configuration.isPressed ? 0.8 : 1).scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
