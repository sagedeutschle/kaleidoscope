import SwiftUI

enum CasinoTheme {
    static let minimumTarget: CGFloat = 44
    static let compactSpacing: CGFloat = 16
    static let regularSpacing: CGFloat = 24

    static let accent = Color(red: 0.83, green: 0.61, blue: 0.24)
    static let feltTop = Color(red: 0.12, green: 0.34, blue: 0.29)
    static let feltBottom = Color(red: 0.06, green: 0.19, blue: 0.18)
    static let feltEdge = Color(red: 0.04, green: 0.13, blue: 0.12)
    static let cardFace = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let cardBack = Color(red: 0.18, green: 0.35, blue: 0.48)
    static let redSuit = Color(red: 0.72, green: 0.12, blue: 0.16)
    static let blackSuit = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let headerPrimary = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let headerSecondary = Color.white.opacity(0.76)

    static var panel: Color { Color(uiColor: .secondarySystemBackground) }
    static var panelRaised: Color { Color(uiColor: .tertiarySystemBackground) }
    static var outline: Color { Color.primary.opacity(0.16) }
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

    static func layout(isCompactWidth: Bool, usableWidth: CGFloat) -> CasinoMobileLayout {
        guard !isCompactWidth, usableWidth >= regularMinimumWidth else {
            return .compact
        }
        let sidebarWidth = min(max(usableWidth * 0.30, 300), 340)
        return .regular(sidebarWidth: sidebarWidth)
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
            .foregroundStyle(prominent ? Color.black : Color.primary)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
