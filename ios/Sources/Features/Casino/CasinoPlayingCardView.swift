import PrismetShared
import SwiftUI

struct CasinoPlayingCardView: View {
    let displayedCard: PrismetBlackjackDisplayedCard
    var maximumWidth: CGFloat = 88

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CasinoTheme.cardFace)
                .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: CasinoTheme.feltEdge.opacity(0.24), radius: 4, y: 2)

            if let card {
                VStack(spacing: 4) {
                    Text(rankLabel(card.rank))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(suitSymbol(card.suit))
                        .font(.system(size: 28, weight: .semibold))
                }
                .foregroundStyle(suitColor(card.suit))
                .minimumScaleFactor(0.7)
                .padding(8)
            } else {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(CasinoTheme.cardBack.gradient)
                    .padding(5)
                    .overlay {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.86))
                    }
            }
        }
        .aspectRatio(0.68, contentMode: .fit)
        .frame(maxWidth: maximumWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var card: PrismetPlayingCard? {
        guard case .faceUp(let card) = displayedCard else { return nil }
        return card
    }

    private var accessibilityLabel: String {
        guard let card else { return "Face-down card" }
        return card.accessibilityLabel(isFaceUp: true)
    }

    private func rankLabel(_ rank: PrismetCardRank) -> String {
        switch rank {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(rank.rawValue)
        }
    }

    private func suitSymbol(_ suit: PrismetCardSuit) -> String {
        switch suit {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    private func suitColor(_ suit: PrismetCardSuit) -> Color {
        switch suit {
        case .diamonds, .hearts: return CasinoTheme.redSuit
        case .clubs, .spades: return CasinoTheme.blackSuit
        }
    }
}
