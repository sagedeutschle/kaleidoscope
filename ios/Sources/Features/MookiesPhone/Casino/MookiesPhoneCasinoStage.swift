import SwiftUI

/// Visible, presentation-only Reynard host card for the compact Casino.
///
/// The card owns no table, randomizer, result, progress, or navigation state.
/// A caller may choose one of the cosmetic moods explicitly.
public struct MookiesPhoneCasinoHostCard: View {
    public static let accessibilityIdentifier = "mookies-phone-reynard-casino-host"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    private let mood: MookiesPhoneCasinoHostMood

    public init(mood: MookiesPhoneCasinoHostMood = .welcome) {
        self.mood = mood
    }

    public var body: some View {
        let transform = MookiesPhoneMotionPolicy.transform(
            for: hasAppeared ? .settled : .entrance,
            reduceMotion: reduceMotion
        )

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                hostArtwork(diameter: 112)
                hostCopy
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    hostArtwork(diameter: 96)
                    casinoTitle
                }
                hostMessage
            }
        }
        .padding(16)
        .background(hostCardBackground)
        .overlay(hostCardOutline)
        .shadow(color: MookiesPhoneCasinoPalette.ink.opacity(0.34), radius: 16, y: 9)
        .opacity(transform.opacity)
        .scaleEffect(transform.scale)
        .offset(y: transform.yOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mood.accessibilityLabel)
        .accessibilityIdentifier(Self.accessibilityIdentifier)
        .onAppear { settleHost(reduceMotion: reduceMotion) }
        .onChange(of: reduceMotion) { _, isReduced in
            settleHost(reduceMotion: isReduced)
        }
    }

    private func hostArtwork(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MookiesPhoneCasinoPalette.marquee.opacity(0.55),
                            MookiesPhoneCasinoPalette.wine.opacity(0.18),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: diameter * 0.64
                    )
                )
                .frame(width: diameter + 22, height: diameter + 22)

            Image(MookiesPhoneCasinoPresentation.hostAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.24), radius: 7, y: 5)
        }
        .frame(width: diameter + 22, height: diameter + 22)
        .accessibilityHidden(true)
    }

    private var hostCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            casinoTitle
            hostMessage
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var casinoTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("REYNARD PRESENTS")
                .font(.caption2.weight(.black))
                .tracking(1.5)
                .foregroundStyle(MookiesPhoneCasinoPalette.marquee)

            Text(MookiesPhoneCasinoPresentation.destinationName)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(MookiesPhoneCasinoPalette.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var hostMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mood.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MookiesPhoneCasinoPalette.ivory.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Label("18+ practice only · no money or prizes", systemImage: "suit.spade.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(MookiesPhoneCasinoPalette.marquee)
        }
    }

    private var hostCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        MookiesPhoneCasinoPalette.wine,
                        MookiesPhoneCasinoPalette.velvet,
                        MookiesPhoneCasinoPalette.ink,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                MookiesPhoneCasinoCardFan()
                    .frame(width: 98, height: 84)
                    .opacity(0.22)
                    .offset(x: 12, y: -3)
                    .accessibilityHidden(true)
            }
    }

    private var hostCardOutline: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MookiesPhoneCasinoPalette.marquee,
                        MookiesPhoneCasinoPalette.marquee.opacity(0.22),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    private func settleHost(reduceMotion: Bool) {
        let profile = MookiesPhoneMotionPolicy.profile(reduceMotion: reduceMotion)
        guard !reduceMotion else {
            hasAppeared = true
            return
        }

        withAnimation(.easeOut(duration: profile.transitionDuration)) {
            hasAppeared = true
        }
    }
}

/// A theatrical frame for the existing real Casino table content.
///
/// Pass the current table view as `content`; this component contributes only
/// felt depth, light theatre, decorative cards/tokens, and a strong play focus.
public struct MookiesPhoneCasinoTableStage<Content: View>: View {
    public static var accessibilityIdentifier: String {
        "mookies-phone-casino-table-stage"
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = MookiesPhoneCasinoPresentation.layout(usableWidth: proxy.size.width)

            ZStack {
                MookiesPhoneCasinoPalette.roomGradient
                stageLights
                tableRail(cornerRadius: layout.stageCornerRadius)
                decorativeTableProps

                content
                    .frame(maxWidth: .infinity, minHeight: layout.minimumPlayHeight, alignment: .top)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, 54)
                    .padding(.bottom, 20)
                    .environment(\.colorScheme, .dark)
                    .zIndex(2)
            }
            .clipShape(RoundedRectangle(cornerRadius: layout.stageCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: layout.stageCornerRadius, style: .continuous)
                    .strokeBorder(MookiesPhoneCasinoPalette.marquee.opacity(0.74), lineWidth: 1.5)
            }
            .shadow(color: MookiesPhoneCasinoPalette.ink.opacity(0.42), radius: 18, y: 12)
        }
        .frame(minHeight: 434)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reynard’s Casino practice play table")
        .accessibilityIdentifier(Self.accessibilityIdentifier)
    }

    private var stageLights: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                ForEach(0..<11, id: \.self) { index in
                    MookiesPhoneCasinoMarqueeLight(
                        index: index,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .padding(.top, 17)
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private func tableRail(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(18, cornerRadius - 6), style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        MookiesPhoneCasinoPalette.railHighlight,
                        MookiesPhoneCasinoPalette.rail,
                        MookiesPhoneCasinoPalette.ink,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.horizontal, 7)
            .padding(.top, 42)
            .padding(.bottom, 7)
            .overlay {
                RoundedRectangle(cornerRadius: max(16, cornerRadius - 10), style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                MookiesPhoneCasinoPalette.feltLight,
                                MookiesPhoneCasinoPalette.felt,
                                MookiesPhoneCasinoPalette.feltDark,
                            ],
                            center: .top,
                            startRadius: 12,
                            endRadius: 430
                        )
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 50)
                    .padding(.bottom, 14)
            }
            .accessibilityHidden(true)
    }

    private var decorativeTableProps: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                MookiesPhoneCasinoCardFan()
                    .frame(width: 92, height: 72)
                    .rotationEffect(.degrees(-4))

                Spacer()

                MookiesPhoneCasinoTokenStack()
                    .frame(width: 78, height: 62)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 17)
            .opacity(0.52)
        }
        .accessibilityHidden(true)
    }
}

/// One-call compact composition for destinations that want both integration
/// pieces while keeping their real table view unchanged.
public struct MookiesPhoneCasinoScene<Content: View>: View {
    private let mood: MookiesPhoneCasinoHostMood
    private let content: Content

    public init(
        mood: MookiesPhoneCasinoHostMood = .welcome,
        @ViewBuilder content: () -> Content
    ) {
        self.mood = mood
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 14) {
            MookiesPhoneCasinoHostCard(mood: mood)
            MookiesPhoneCasinoTableStage { content }
        }
    }
}

private enum MookiesPhoneCasinoPalette {
    static let ink = Color(red: 0.043, green: 0.035, blue: 0.055)
    static let velvet = Color(red: 0.20, green: 0.025, blue: 0.075)
    static let wine = Color(red: 0.36, green: 0.035, blue: 0.11)
    static let felt = Color(red: 0.02, green: 0.29, blue: 0.20)
    static let feltLight = Color(red: 0.035, green: 0.40, blue: 0.27)
    static let feltDark = Color(red: 0.01, green: 0.13, blue: 0.095)
    static let rail = Color(red: 0.22, green: 0.11, blue: 0.045)
    static let railHighlight = Color(red: 0.48, green: 0.28, blue: 0.10)
    static let marquee = Color(red: 0.96, green: 0.72, blue: 0.26)
    static let ivory = Color(red: 0.98, green: 0.96, blue: 0.89)

    static let roomGradient = LinearGradient(
        colors: [velvet, ink, Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct MookiesPhoneCasinoMarqueeLight: View {
    let index: Int
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { context in
            let brightness = resolvedBrightness(at: context.date)
            Circle()
                .fill(MookiesPhoneCasinoPalette.marquee.opacity(brightness))
                .frame(width: 8, height: 8)
                .shadow(
                    color: MookiesPhoneCasinoPalette.marquee.opacity(reduceMotion ? 0.34 : brightness),
                    radius: reduceMotion ? 3 : 7
                )
        }
    }

    private func resolvedBrightness(at date: Date) -> Double {
        guard !reduceMotion else { return 0.72 }
        let phase = (date.timeIntervalSinceReferenceDate * 1.7) + (Double(index) * 0.38)
        return 0.66 + ((sin(phase) + 1) * 0.14)
    }
}

private struct MookiesPhoneCasinoCardFan: View {
    var body: some View {
        ZStack {
            card(rank: "Q", suit: "♥", angle: -13, x: -20)
            card(rank: "A", suit: "♠", angle: 0, x: 0)
            card(rank: "K", suit: "♦", angle: 13, x: 20)
        }
    }

    private func card(
        rank: String,
        suit: String,
        angle: Double,
        x: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(MookiesPhoneCasinoPalette.ivory)
            .overlay(alignment: .topLeading) {
                VStack(spacing: -2) {
                    Text(rank)
                    Text(suit)
                }
                .font(.caption2.weight(.black))
                .foregroundStyle(suit == "♠" ? MookiesPhoneCasinoPalette.ink : MookiesPhoneCasinoPalette.wine)
                .padding(5)
            }
            .frame(width: 42, height: 58)
            .rotationEffect(.degrees(angle))
            .offset(x: x)
            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
    }
}

private struct MookiesPhoneCasinoTokenStack: View {
    var body: some View {
        ZStack {
            token(color: MookiesPhoneCasinoPalette.wine, y: 19)
            token(color: MookiesPhoneCasinoPalette.marquee, y: 10)
            token(color: MookiesPhoneCasinoPalette.feltLight, y: 1)
        }
    }

    private func token(color: Color, y: CGFloat) -> some View {
        Capsule()
            .fill(color)
            .overlay(Capsule().stroke(MookiesPhoneCasinoPalette.ivory.opacity(0.72), lineWidth: 2))
            .frame(width: 52, height: 17)
            .offset(y: y)
            .shadow(color: .black.opacity(0.24), radius: 2, y: 2)
    }
}
