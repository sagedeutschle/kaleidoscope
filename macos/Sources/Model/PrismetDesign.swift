import SwiftUI

// NOTE TO THE OTHER AGENT: two agents share this project — see docs/AGENT-COORDINATION.md
// for lanes + conventions. New design tokens go HERE (don't reference undefined ones).

// MARK: - Prismet design system  ·  "Rustic scroll + kaleidoscope iris"
//
// Warm parchment/vellum surfaces, sepia ink, and gilt edges — the whole app reads
// like an illuminated scroll (congruent with the Oracle/Wizard King's Decree). The
// signature is still the conic "iris" gradient (a kaleidoscope lens) sitting on the
// scroll. Titles are serif; numbers/stats stay rounded-monospaced.
//
// The token API is intentionally STABLE so facets that use it inherit the theme.

/// User-selectable "paper" — controls overall contrast/readability. Persisted in
/// UserDefaults (`PrismetDesign.paperKey`); the shell re-themes the whole app on change.
enum PrismetPaper: String, CaseIterable, Identifiable {
    case contrast = "High Contrast"
    case parchment = "Parchment"
    case dark = "Dark"
    var id: String { rawValue }
}

enum PrismetDesign {
    static let paperKey = "kaleido.paper"

    /// Active paper. Dark is the default (Sage, 2026-07-03) — a stored choice wins.
    static var paper: PrismetPaper {
        PrismetPaper(rawValue: UserDefaults.standard.string(forKey: paperKey) ?? "") ?? .dark
    }

    struct Palette {
        var ground, panel, panelHi, hairline, outline, ink, ink2, ink3: Color
        var isDark: Bool
    }

    static var palette: Palette {
        switch paper {
        case .contrast:
            let ink = Color(red: 0.11, green: 0.10, blue: 0.07)        // near-black
            return Palette(ground: Color(red: 0.964, green: 0.950, blue: 0.912),
                           panel: Color(red: 0.993, green: 0.985, blue: 0.964),
                           panelHi: Color(red: 0.902, green: 0.878, blue: 0.818),
                           hairline: Color.black.opacity(0.20),
                           outline: Color.black.opacity(0.36),
                           ink: ink, ink2: ink.opacity(0.82), ink3: ink.opacity(0.58),
                           isDark: false)
        case .parchment:
            let ink = Color(red: 0.16, green: 0.11, blue: 0.05)        // deep sepia
            return Palette(ground: Color(red: 0.937, green: 0.902, blue: 0.816),
                           panel: Color(red: 0.968, green: 0.940, blue: 0.872),
                           panelHi: Color(red: 0.900, green: 0.852, blue: 0.742),
                           hairline: Color(red: 0.34, green: 0.24, blue: 0.12).opacity(0.30),
                           outline: Color(red: 0.34, green: 0.24, blue: 0.12).opacity(0.50),
                           ink: ink, ink2: ink.opacity(0.76), ink3: ink.opacity(0.54),
                           isDark: false)
        case .dark:
            let ink = Color(red: 0.95, green: 0.96, blue: 0.99)
            return Palette(ground: Color(red: 0.063, green: 0.067, blue: 0.102),
                           panel: Color(red: 0.106, green: 0.114, blue: 0.165),
                           panelHi: Color(red: 0.157, green: 0.169, blue: 0.235),
                           hairline: Color.white.opacity(0.10),
                           outline: Color.white.opacity(0.18),
                           ink: ink, ink2: ink.opacity(0.66), ink3: ink.opacity(0.42),
                           isDark: true)
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

    static let gold = Color(red: 0.72, green: 0.54, blue: 0.20)        // gilt accent

    /// The jewel wheel for the kaleidoscope iris — colourful refraction on the scroll.
    static let wheel: [Color] = [
        Color(red: 0.86, green: 0.28, blue: 0.34),  // garnet
        Color(red: 0.90, green: 0.55, blue: 0.20),  // amber
        Color(red: 0.80, green: 0.66, blue: 0.22),  // gold
        Color(red: 0.30, green: 0.55, blue: 0.42),  // jade
        Color(red: 0.24, green: 0.46, blue: 0.66),  // lapis
        Color(red: 0.46, green: 0.34, blue: 0.62),  // amethyst
        Color(red: 0.86, green: 0.28, blue: 0.34)   // back to garnet for a seamless loop
    ]

    /// Serif display, like an illuminated manuscript heading.
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A facet's accent refracted into a ring of related stops.
func irisColors(_ accent: Color) -> [Color] {
    [accent, accent.opacity(0.40), PrismetDesign.gold.opacity(0.6), accent.opacity(0.40), accent]
}

// MARK: - Backdrop

/// The parchment ground with a soft accent wash and an aged vignette, so each facet
/// looks like a page of the same scroll. Drop behind any facet with `.facetBackground(accent)`.
struct FacetBackdrop: View {
    var accent: Color
    var multiHue: Bool = false

    var body: some View {
        ZStack {
            PrismetDesign.ground
            if !PrismetDesign.isDark {
                // Real parchment grain (multiplied so it textures without washing out).
                Image("oracle_parchment")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.55)
                    .blendMode(.multiply)
            }
            RadialGradient(colors: [accent.opacity(multiHue ? 0.16 : 0.12), .clear],
                           center: .topLeading, startRadius: 6, endRadius: 560)
            if multiHue {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: PrismetDesign.wheel), center: .center))
                    .frame(width: 680, height: 680)
                    .blur(radius: 170)
                    .opacity(0.18)
                    .offset(x: 200, y: -250)
            }
            // Aged edge vignette for a scroll feel — light papers only; the warm
            // brown wash muddies the cool dark palette.
            if !PrismetDesign.isDark {
                RadialGradient(colors: [.clear, Color(red: 0.34, green: 0.24, blue: 0.12).opacity(0.18)],
                               center: .center, startRadius: 240, endRadius: 760)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func facetBackground(_ accent: Color, multiHue: Bool = false) -> some View {
        background(FacetBackdrop(accent: accent, multiHue: multiHue))
    }

    /// A raised vellum card used to frame a playfield.
    func prismetCard(cornerRadius: CGFloat = 16) -> some View {
        padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PrismetDesign.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.30), .clear],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(PrismetDesign.outline, lineWidth: 1)
                    )
            )
            .shadow(color: Color(red: 0.30, green: 0.20, blue: 0.10).opacity(0.28), radius: 16, y: 10)
    }
}

// MARK: - Header

/// A facet's title block: an accent SF Symbol inside the signature iris ring,
/// a serif title, an optional subtitle, and a trailing slot for stats.
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
                Circle().strokeBorder(
                    AngularGradient(gradient: Gradient(colors: irisColors(accent)), center: .center),
                    lineWidth: 2.5)
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PrismetDesign.title(30))
                    .foregroundStyle(PrismetDesign.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PrismetDesign.ink2)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
    }
}

extension GameHeader where Trailing == EmptyView {
    init(title: String, systemImage: String, accent: Color, subtitle: String? = nil) {
        self.init(title: title, systemImage: systemImage, accent: accent, subtitle: subtitle) { EmptyView() }
    }
}

/// A small labelled statistic — uppercase caption over a monospaced value.
struct StatBadge: View {
    let label: String
    let value: String
    var accent: Color = PrismetDesign.ink

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(PrismetDesign.ink3)
            Text(value)
                .font(PrismetDesign.rounded(24))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
        .frame(minWidth: 64, alignment: .trailing)
    }
}

// MARK: - Buttons

/// Filled accent capsule for the primary action in a facet.
struct AccentButtonStyle: ButtonStyle {
    var accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(accent.gradient))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet parchment capsule for secondary actions.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(PrismetDesign.panelHi)
                    .overlay(Capsule().strokeBorder(PrismetDesign.outline, lineWidth: 1))
            )
            .foregroundStyle(PrismetDesign.ink)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Accent lookup

extension FacetRegistry {
    /// The accent colour registered for a facet id (used by each facet to self-theme).
    static func accent(for id: String) -> Color {
        descriptor(for: id)?.accent ?? PrismetDesign.gold
    }
}
