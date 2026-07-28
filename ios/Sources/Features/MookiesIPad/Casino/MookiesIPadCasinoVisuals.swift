import PrismetShared
import SwiftUI

enum MookiesIPadCasinoPalette {
    static let midnight = Color(red: 0.035, green: 0.035, blue: 0.055)
    static let felt = Color(red: 0.025, green: 0.205, blue: 0.145)
    static let feltDeep = Color(red: 0.015, green: 0.095, blue: 0.075)
    static let tableFelt = Color(red: 0.025, green: 0.245, blue: 0.165)
    static let panel = Color(red: 0.965, green: 0.945, blue: 0.885)
    static let brassLight = Color(red: 1.0, green: 0.825, blue: 0.38)
    static let brass = Color(red: 0.82, green: 0.58, blue: 0.18)
    static let brassDark = Color(red: 0.38, green: 0.20, blue: 0.04)
    static let mookiePurple = Color(red: 0.486, green: 0.361, blue: 1.0)
    static let mookiePurpleDark = Color(red: 0.294, green: 0.180, blue: 0.514)
    static let reynardOrange = Color(red: 0.941, green: 0.412, blue: 0.165)
    static let reynardRed = Color(red: 0.702, green: 0.071, blue: 0.169)
}

struct MookiesIPadCasinoBackdrop: View {
    let motionMode: MookiesCasinoMotionMode

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: motionMode == .staticOnly)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * 0.55
            let glow = motionMode == .staticOnly ? 0.20 : 0.20 + ((sin(phase) + 1) * 0.05)

            ZStack {
                LinearGradient(
                    colors: [
                        MookiesIPadCasinoPalette.midnight,
                        MookiesIPadCasinoPalette.feltDeep,
                        MookiesIPadCasinoPalette.midnight,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                MookiesIPadCasinoFeltLattice()
                    .opacity(0.22)
                RadialGradient(
                    colors: [
                        MookiesIPadCasinoPalette.brassLight.opacity(glow),
                        .clear,
                    ],
                    center: .top,
                    startRadius: 30,
                    endRadius: 520
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct MookiesIPadCasinoFeltLattice: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 34
            var offset: CGFloat = -size.height

            while offset < size.width {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                path.move(to: CGPoint(x: offset + size.height, y: 0))
                path.addLine(to: CGPoint(x: offset, y: size.height))
                offset += spacing
            }

            context.stroke(
                path,
                with: .color(MookiesIPadCasinoPalette.brassLight.opacity(0.24)),
                lineWidth: 0.6
            )
        }
    }
}

struct MookiesIPadCasinoStageMarquee: View {
    var body: some View {
        HStack(spacing: 14) {
            MookiesIPadCasinoCardFan()
            VStack(alignment: .leading, spacing: 2) {
                Text("THE PRACTICE FLOOR")
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                Text("Cards, chance, and open rules")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)
            MookiesIPadCasinoChipStack()
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 12)
        .background(.black.opacity(0.22), in: Capsule())
        .overlay {
            Capsule()
                .stroke(MookiesIPadCasinoPalette.brass.opacity(0.48), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Practice Floor. Cards, chance, and open rules.")
    }
}

private struct MookiesIPadCasinoCardFan: View {
    private let angles = [-13.0, 0.0, 13.0]
    private let suits = ["suit.spade.fill", "suit.heart.fill", "suit.club.fill"]

    var body: some View {
        ZStack {
            ForEach(angles.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 26, height: 38)
                    .overlay {
                        Image(systemName: suits[index])
                            .font(.caption2)
                            .foregroundStyle(index == 1 ? MookiesIPadCasinoPalette.reynardRed : .black)
                    }
                    .rotationEffect(.degrees(angles[index]), anchor: .bottom)
                    .offset(x: CGFloat(index - 1) * 8)
            }
        }
        .frame(width: 52, height: 44)
        .accessibilityHidden(true)
    }
}

private struct MookiesIPadCasinoChipStack: View {
    var body: some View {
        HStack(spacing: 7) {
            chipStack(color: MookiesIPadCasinoPalette.mookiePurple, count: 3)
            chipStack(color: MookiesIPadCasinoPalette.reynardRed, count: 4)
            chipStack(color: MookiesIPadCasinoPalette.brassLight, count: 2)
        }
        .frame(width: 74, height: 42, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func chipStack(color: Color, count: Int) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 21, height: 7)
                    .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1))
                    .offset(y: CGFloat(-index * 5))
            }
        }
        .frame(width: 22, height: 34, alignment: .bottom)
    }
}
