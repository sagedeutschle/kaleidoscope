import Foundation
@testable import PrismetShared

enum PrismetBlackjackFixtures {
    static func card(
        _ rank: PrismetCardRank,
        _ suit: PrismetCardSuit = .spades
    ) -> PrismetPlayingCard {
        PrismetPlayingCard(rank: rank, suit: suit)
    }

    static func cards(_ ranks: PrismetCardRank...) -> [PrismetPlayingCard] {
        ranks.enumerated().map { index, rank in
            PrismetPlayingCard(
                rank: rank,
                suit: PrismetCardSuit.allCases[index % PrismetCardSuit.allCases.count]
            )
        }
    }

    static func deck(drawing cards: [PrismetPlayingCard]) -> [PrismetPlayingCard] {
        precondition(Set(cards).count == cards.count)
        return cards + PrismetDeckFactory.standard52().filter { !cards.contains($0) }
    }
}
