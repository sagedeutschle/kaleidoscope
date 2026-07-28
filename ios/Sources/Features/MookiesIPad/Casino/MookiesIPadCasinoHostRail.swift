import PrismetShared
import SwiftUI

public struct MookiesIPadCasinoHostRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let plan: MookiesCasinoMascotPresencePlan
    @Binding private var visibility: MookiesCasinoMascotVisibility

    public init(
        plan: MookiesCasinoMascotPresencePlan = .casino,
        visibility: Binding<MookiesCasinoMascotVisibility>
    ) {
        self.plan = plan
        _visibility = visibility
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            railHeader

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { mascotCards }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { mascotCards }
                    VStack(spacing: 10) { mascotCards }
                }
            }

            if visibility.visiblePresentations(in: plan).count < plan.presentations.count {
                Button {
                    visibility.restoreAll()
                } label: {
                    Label("Bring back Mookie and Reynard", systemImage: "arrow.uturn.backward.circle")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(MookiesIPadCasinoPalette.brassLight)
                .accessibilityHint("Returns the dismissed hosts without changing the game.")
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: visibility)
    }

    private var railHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(MookiesBrandIdentity.casinoName)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text("inside \(MookiesBrandIdentity.appName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 8)
            Label("Practice only", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(MookiesIPadCasinoPalette.brassLight)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(MookiesBrandIdentity.casinoName), inside \(MookiesBrandIdentity.appName). Practice only.")
    }

    @ViewBuilder
    private var mascotCards: some View {
        ForEach(visibility.visiblePresentations(in: plan), id: \.character) { presentation in
            MookiesIPadCasinoMascotCard(
                presentation: presentation,
                motionMode: MookiesCasinoMotionPolicy.mode(reduceMotion: reduceMotion)
            ) {
                visibility.dismiss(presentation.character)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MookiesIPadCasinoMascotCard: View {
    let presentation: MookiesMascotPresentation
    let motionMode: MookiesCasinoMotionMode
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .body) private var artworkSize: CGFloat = 104

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            mascotArtwork

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.headline.weight(.black))
                Text(presentation.message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)

            if presentation.isDismissible {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.82))
                .accessibilityLabel("Dismiss \(presentation.title)")
                .accessibilityHint("Hides this host without changing the game.")
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: cardColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MookiesIPadCasinoPalette.brass.opacity(0.72), lineWidth: 1.5)
        }
        .shadow(color: cardColors[0].opacity(0.32), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var mascotArtwork: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: motionMode == .staticOnly)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * 1.35
            let lift = motionMode == .staticOnly ? 0.0 : sin(phase) * 2.4
            let glow = motionMode == .staticOnly ? 0.34 : 0.34 + ((sin(phase) + 1) * 0.12)

            Image(presentation.assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: min(artworkSize, 144), height: min(artworkSize, 144))
                .offset(y: lift)
                .background {
                    Circle()
                        .fill(.white.opacity(glow))
                        .blur(radius: 9)
                        .padding(8)
                }
                .accessibilityHidden(true)
        }
    }

    private var cardColors: [Color] {
        switch presentation.character {
        case .mookie:
            [
                MookiesIPadCasinoPalette.mookiePurple.opacity(0.96),
                MookiesIPadCasinoPalette.mookiePurpleDark.opacity(0.96),
            ]
        case .reynard:
            [
                MookiesIPadCasinoPalette.reynardOrange.opacity(0.94),
                MookiesIPadCasinoPalette.reynardRed.opacity(0.94),
            ]
        }
    }
}
