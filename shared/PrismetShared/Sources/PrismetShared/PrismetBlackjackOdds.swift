public struct PrismetBlackjackHitOdds: Codable, Hashable, Sendable {
    public static let visibleInformationAssumption =
        "Uses only your cards and the dealer’s face-up card; the hole card and draw pile are treated as unseen."

    public let bustingCardCount: Int
    public let unseenCardCount: Int
    public let unseenCardCountsByRank: [PrismetCardRank: Int]
    public let assumption: String

    public var probability: Double {
        guard unseenCardCount > 0 else { return 0 }
        return Double(bustingCardCount) / Double(unseenCardCount)
    }

    public init(
        playerCards: [PrismetPlayingCard],
        dealerFaceUpCard: PrismetPlayingCard
    ) {
        var unseenCards = PrismetDeckFactory.standard52()
        for visibleCard in playerCards + [dealerFaceUpCard] {
            if let index = unseenCards.firstIndex(of: visibleCard) {
                unseenCards.remove(at: index)
            }
        }

        var counts = Dictionary(
            uniqueKeysWithValues: PrismetCardRank.allCases.map { ($0, 0) }
        )
        for card in unseenCards {
            counts[card.rank, default: 0] += 1
        }

        self.bustingCardCount = unseenCards.reduce(into: 0) { count, card in
            if PrismetBlackjackHandValue(cards: playerCards + [card]).isBust {
                count += 1
            }
        }
        self.unseenCardCount = unseenCards.count
        self.unseenCardCountsByRank = counts
        self.assumption = Self.visibleInformationAssumption
    }
}
