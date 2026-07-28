import SwiftUI

struct MookiesCasinoTheatreView<Content: View>: View {
    let tableTitle: String
    let tableSubtitle: String
    let onLeave: () -> Void
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(
        tableTitle: String = MookiesMacCopy.casinoTitle,
        tableSubtitle: String = "A playful probability theatre",
        onLeave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.tableTitle = tableTitle
        self.tableSubtitle = tableSubtitle
        self.onLeave = onLeave
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let presentation = MookiesMacLayoutPolicy.presentation(for: proxy.size.width)
            let mascotWidth = MookiesMacLayoutPolicy.mascotWidth(for: proxy.size.width)
            let tableInset = MookiesMacLayoutPolicy.tableInset(for: proxy.size.width)

            ZStack {
                MookiesCasinoFelt(
                    differentiateWithoutColor: differentiateWithoutColor
                )
                MookiesCasinoStageLights()
                    .opacity(accessibilityReduceMotion ? 0.5 : 0.86)

                VStack(spacing: 0) {
                    theatreHeader

                    switch presentation {
                    case .compact:
                        compactStage(mascotWidth: mascotWidth, tableInset: tableInset)
                    case .standard:
                        standardStage(mascotWidth: mascotWidth, tableInset: tableInset)
                    case .cinematic:
                        cinematicStage(mascotWidth: mascotWidth, tableInset: tableInset)
                    }
                }

                stageDecorations
            }
        }
        .frame(minHeight: MookiesMacLayoutPolicy.minimumTableHeight)
        .background(MookiesMacBrand.nearBlack)
        .onExitCommand(perform: onLeave)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(MookiesMacCopy.casinoTitle). \(tableTitle). \(tableSubtitle)")
    }

    private var theatreHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .foregroundStyle(MookiesMacBrand.brassHighlight)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(tableTitle)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                Text(tableSubtitle)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(MookiesMacBrand.warmWhite.opacity(0.72))
            }
            .foregroundStyle(MookiesMacBrand.warmWhite)

            Spacer(minLength: 12)

            Text(MookiesMacCopy.practiceDisclosure)
                .font(.caption2)
                .foregroundStyle(MookiesMacBrand.warmWhite.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 340, alignment: .trailing)

            Button("Leave Casino", systemImage: "door.left.hand.open", action: onLeave)
                .buttonStyle(.bordered)
                .tint(MookiesMacBrand.brass)
                .frame(minHeight: MookiesMacBrand.minimumTarget)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(MookiesMacBrand.nearBlack.opacity(0.86))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MookiesMacBrand.brassRail)
                .frame(height: 3)
                .accessibilityHidden(true)
        }
    }

    private func compactStage(mascotWidth: CGFloat, tableInset: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                MookiesMacMascotView(
                    character: .mookie,
                    width: mascotWidth * 0.62,
                    message: "Deal you in?",
                    showsNameplate: false
                )
                Spacer(minLength: 8)
                MookiesMacMascotView(
                    character: .reynard,
                    width: mascotWidth * 0.7,
                    message: "The table is ready.",
                    showsNameplate: false
                )
            }
            .frame(height: 124)
            .padding(.horizontal, tableInset)

            tableFrame
                .padding(.horizontal, tableInset)
                .padding(.bottom, tableInset)
        }
    }

    private func standardStage(mascotWidth: CGFloat, tableInset: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            MookiesMacMascotView(
                character: .mookie,
                width: mascotWidth * 0.72,
                message: MookiesMacCopy.mookieGreeting
            )

            tableFrame

            MookiesMacMascotView(
                character: .reynard,
                width: mascotWidth * 0.8,
                message: MookiesMacCopy.reynardGreeting
            )
        }
        .padding(tableInset)
    }

    private func cinematicStage(mascotWidth: CGFloat, tableInset: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 18) {
            MookiesMacMascotView(
                character: .mookie,
                width: mascotWidth * 0.78,
                message: MookiesMacCopy.mookieGreeting
            )

            tableFrame

            MookiesMacMascotView(
                character: .reynard,
                width: mascotWidth,
                message: MookiesMacCopy.reynardGreeting
            )
        }
        .padding(tableInset)
    }

    private var tableFrame: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MookiesMacBrand.feltShadow.opacity(0.48))
            .clipShape(RoundedRectangle(cornerRadius: MookiesMacBrand.stageCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MookiesMacBrand.stageCornerRadius)
                    .stroke(MookiesMacBrand.brassRail, lineWidth: differentiateWithoutColor ? 5 : 3)
            }
            .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(tableTitle) game table")
    }

    private var stageDecorations: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                MookiesDecorativeChipStack()
                Spacer()
                MookiesDecorativeCardFan()
            }
            .padding(18)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MookiesCasinoFelt: View {
    let differentiateWithoutColor: Bool

    var body: some View {
        ZStack {
            MookiesMacBrand.feltBackground

            MookiesFeltDiamondPattern()
                .stroke(
                    differentiateWithoutColor
                        ? MookiesMacBrand.warmWhite.opacity(0.14)
                        : MookiesMacBrand.brass.opacity(0.1),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 10])
                )
                .accessibilityHidden(true)

            RadialGradient(
                colors: [MookiesMacBrand.brass.opacity(0.12), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 560
            )
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

private struct MookiesFeltDiamondPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 46
        var offset = -rect.height
        while offset < rect.width {
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + rect.height, y: rect.height))
            path.move(to: CGPoint(x: offset, y: rect.height))
            path.addLine(to: CGPoint(x: offset + rect.height, y: 0))
            offset += spacing
        }
        return path
    }
}

struct MookiesCasinoStageLights: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var lightsAreWarm = false

    var body: some View {
        HStack {
            lightCluster(rotation: -12)
            Spacer()
            lightCluster(rotation: 12)
        }
        .padding(.horizontal, 42)
        .padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(accessibilityReduceMotion ? 0.52 : (lightsAreWarm ? 0.92 : 0.62))
        .animation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
            value: lightsAreWarm
        )
        .onAppear {
            lightsAreWarm = !accessibilityReduceMotion
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func lightCluster(rotation: Double) -> some View {
        VStack(spacing: -4) {
            Circle()
                .fill(MookiesMacBrand.brassHighlight)
                .frame(width: 18, height: 18)
                .shadow(color: MookiesMacBrand.brassHighlight.opacity(0.8), radius: 16)

            MookiesSpotlightBeam()
                .fill(
                    LinearGradient(
                        colors: [MookiesMacBrand.brassHighlight.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 150, height: 340)
        }
        .rotationEffect(.degrees(rotation), anchor: .top)
    }
}

private struct MookiesSpotlightBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 7, y: 0))
        path.addLine(to: CGPoint(x: rect.midX + 7, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct MookiesDecorativeChipStack: View {
    private let colors = [
        MookiesMacBrand.hatPurple,
        MookiesMacBrand.bowTieRed,
        MookiesMacBrand.brass,
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: -8) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                ZStack {
                    Circle()
                        .fill(color)
                    Circle()
                        .stroke(MookiesMacBrand.warmWhite.opacity(0.9), style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
                        .padding(4)
                    Circle()
                        .fill(MookiesMacBrand.nearBlack.opacity(0.5))
                        .frame(width: 10, height: 10)
                }
                .frame(width: 42, height: 42)
                .offset(y: CGFloat(-index * 5))
                .rotationEffect(.degrees(Double(index * 8 - 8)))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
            }
        }
    }
}

struct MookiesDecorativeCardFan: View {
    private let marks = ["A\n♠", "K\n♥", "Q\n♦"]

    var body: some View {
        ZStack {
            ForEach(Array(marks.enumerated()), id: \.offset) { index, mark in
                Text(mark)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(index == 0 ? MookiesMacBrand.nearBlack : MookiesMacBrand.bowTieRed)
                    .frame(width: 46, height: 62)
                    .background(MookiesMacBrand.warmWhite, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(MookiesMacBrand.brass, lineWidth: 1)
                    }
                    .rotationEffect(.degrees(Double(index - 1) * 16))
                    .offset(x: CGFloat(index - 1) * 25, y: CGFloat(abs(index - 1) * 6))
                    .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
            }
        }
        .frame(width: 104, height: 82)
    }
}
