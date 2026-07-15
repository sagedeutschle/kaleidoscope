import Foundation
import SwiftUI

enum CasinoTheme {
    static let minimumTarget: CGFloat = 44
    static let compactSpacing: CGFloat = 16
    static let regularSpacing: CGFloat = 24

    static let accent = Color(red: 0.843, green: 0.659, blue: 0.290)
    static let feltTop = Color(red: 0.071, green: 0.247, blue: 0.212)
    static let feltBottom = Color(red: 0.043, green: 0.239, blue: 0.204)
    static let feltEdge = Color(red: 0.063, green: 0.165, blue: 0.149)
    static let cardFace = Color(red: 0.969, green: 0.957, blue: 0.918)
    static let warmIvory = cardFace
    static let mutedIvory = Color(red: 0.910, green: 0.894, blue: 0.847)
    static let ink = Color(red: 0.063, green: 0.165, blue: 0.149)
    static let mutedInk = Color(red: 0.235, green: 0.318, blue: 0.298)
    static let cardBack = Color(red: 0.18, green: 0.35, blue: 0.48)
    static let redSuit = Color(red: 0.72, green: 0.12, blue: 0.16)
    static let blackSuit = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let headerPrimary = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let headerSecondary = Color.white.opacity(0.76)
    static let brassText = Color(red: 0.54, green: 0.35, blue: 0.0)

    static var panel: Color { warmIvory }
    static var panelRaised: Color { mutedIvory }
    static var outline: Color { ink.opacity(0.18) }

    static var feltBackground: LinearGradient {
        LinearGradient(
            colors: [feltTop, feltBottom, feltEdge],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum CasinoMobileActionSet: Equatable {
    case decisions
    case newHand
}

enum CasinoMobileActionPolicy {
    static func actions(canStartNewHand: Bool) -> CasinoMobileActionSet {
        canStartNewHand ? .newHand : .decisions
    }
}

enum CasinoMobileLayout: Equatable {
    case compact
    case regular(sidebarWidth: CGFloat)
}

enum CasinoMobileLayoutPolicy {
    static let regularMinimumWidth: CGFloat = 760
    static let libraryWidth: CGFloat = 180
    static let hubSpacing: CGFloat = 12
    static let hubPadding: CGFloat = 16
    static let regularTableMinimumHeight: CGFloat = 520

    static func layout(isCompactWidth: Bool, usableWidth: CGFloat) -> CasinoMobileLayout {
        guard !isCompactWidth, usableWidth >= regularMinimumWidth else {
            return .compact
        }
        let sidebarWidth = min(max(usableWidth * 0.30, 300), 340)
        return .regular(sidebarWidth: sidebarWidth)
    }

    static func availableTableWidth(usableWidth: CGFloat, sidebarWidth: CGFloat) -> CGFloat {
        max(0, usableWidth - (hubPadding * 2) - (hubSpacing * 2) - libraryWidth - sidebarWidth)
    }
}

enum CasinoFairPlayCopy {
    static let disclosure = "Practice only. No money, purchases, wagering, prizes, or rewards."
    static let rulesTitle = "Practice Blackjack rules v1"
    static let dealerPolicy = "Dealer stands on every 17, including soft 17."
    static let hitOddsAssumption = "Uses only your cards and the dealer’s face-up card; the hole card and draw pile are treated as unseen."
    static let pendingAudit = "Replay & Fairness becomes available after this hand ends."
}

struct CasinoPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CasinoTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(CasinoTheme.outline, lineWidth: 1)
                    )
            )
            .foregroundStyle(CasinoTheme.ink)
            .environment(\.colorScheme, .light)
            .shadow(color: CasinoTheme.feltEdge.opacity(0.12), radius: 8, y: 3)
    }
}

extension View {
    func casinoPanel() -> some View {
        modifier(CasinoPanelModifier())
    }
}

struct CasinoActionButtonStyle: ButtonStyle {
    let prominent: Bool

    init(prominent: Bool = false) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: CasinoTheme.minimumTarget)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? CasinoTheme.accent : CasinoTheme.panelRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(CasinoTheme.outline, lineWidth: prominent ? 0 : 1)
                    )
            )
            .foregroundStyle(CasinoTheme.ink)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

enum CasinoProbabilityRosetteStyle: Equatable {
    case watermark
    case wheel
}

private struct CasinoRosetteSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct CasinoProbabilityRosette: View {
    static let segmentCount = 12

    let style: CasinoProbabilityRosetteStyle
    var highlightedSegment: Int? = nil
    var diameter: CGFloat = 176

    var body: some View {
        ZStack {
            ForEach(0..<Self.segmentCount, id: \.self) { index in
                let segment = CasinoRosetteSegment(
                    startAngle: .degrees(Double(index * 30) - 90),
                    endAngle: .degrees(Double((index + 1) * 30) - 90)
                )
                segment
                    .fill(segmentFill(index))
                    .overlay {
                        segment.stroke(
                            highlightedSegment == index + 1 ? CasinoTheme.accent : segmentBorder,
                            lineWidth: highlightedSegment == index + 1 ? 3 : 1
                        )
                    }
            }

            if style == .wheel {
                GeometryReader { proxy in
                    ForEach(0..<Self.segmentCount, id: \.self) { index in
                        let angle = (Double(index) * 30 - 75) * Double.pi / 180
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(index < 6 ? CasinoTheme.ink : CasinoTheme.warmIvory)
                            .position(
                                x: proxy.size.width / 2 + cos(angle) * proxy.size.width * 0.35,
                                y: proxy.size.height / 2 + sin(angle) * proxy.size.height * 0.35
                            )
                    }
                }
                Circle()
                    .fill(CasinoTheme.accent)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var segmentBorder: Color {
        style == .wheel ? CasinoTheme.accent.opacity(0.72) : CasinoTheme.warmIvory.opacity(0.16)
    }

    private func segmentFill(_ index: Int) -> Color {
        switch style {
        case .watermark:
            return index.isMultiple(of: 2)
                ? CasinoTheme.warmIvory.opacity(0.10)
                : CasinoTheme.accent.opacity(0.09)
        case .wheel:
            return index < 6 ? CasinoTheme.warmIvory : CasinoTheme.feltTop
        }
    }

    private var accessibilityLabel: String {
        if let highlightedSegment {
            return "Twelve equal segments. Segment \(highlightedSegment) revealed."
        }
        return style == .wheel
            ? "Fair Wheel with twelve equal numbered segments"
            : "Twelve-part equal-probability rosette"
    }
}
