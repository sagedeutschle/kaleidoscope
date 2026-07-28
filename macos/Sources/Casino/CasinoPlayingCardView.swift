import PrismetShared
import SwiftUI

struct CasinoPlayingCardView: View {
    let card: PrismetBlackjackDisplayedCard

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(card: PrismetBlackjackDisplayedCard) {
        self.card = card
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CasinoTheme.warmIvory)
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)

            switch card {
            case let .faceUp(playingCard):
                faceUpContent(playingCard)
            case .faceDown:
                faceDownContent
            }
        }
        .frame(width: 78, height: 112)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: card))
    }

    static func accessibilityLabel(for card: PrismetBlackjackDisplayedCard) -> String {
        switch card {
        case let .faceUp(playingCard):
            return playingCard.accessibilityLabel(isFaceUp: true)
        case .faceDown:
            return "Face-down card"
        }
    }

    private func faceUpContent(_ playingCard: PrismetPlayingCard) -> some View {
        let tint = suitColor(playingCard.suit)
        return VStack(alignment: .leading, spacing: 2) {
            Text(rankMark(playingCard.rank))
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Text(suitMark(playingCard.suit))
                .font(.system(size: 20, weight: .semibold))
            Spacer(minLength: 4)
            HStack {
                Spacer()
                Text(suitMark(playingCard.suit))
                    .font(.system(size: 35, weight: .medium))
            }
            if differentiateWithoutColor {
                Text(playingCard.suit.displayName.capitalized)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(tint)
        .padding(9)
    }

    private var faceDownContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(CasinoTheme.feltTop)
                .padding(5)
            Image(systemName: "sparkles")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(CasinoTheme.brassSoft)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(CasinoTheme.brass.opacity(0.78), lineWidth: 2)
                .padding(10)
        }
    }

    private func rankMark(_ rank: PrismetCardRank) -> String {
        switch rank {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        default: return String(rank.rawValue)
        }
    }

    private func suitMark(_ suit: PrismetCardSuit) -> String {
        switch suit {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    private func suitColor(_ suit: PrismetCardSuit) -> Color {
        switch suit {
        case .diamonds, .hearts:
            return CasinoTheme.danger
        case .clubs, .spades:
            return CasinoTheme.ink
        }
    }
}
