public enum PrismetBlackjackRulesV1 {
    public static let canonicalGameID = "blackjack"
    public static let name = "Practice Blackjack"
    public static let rulesVersion = 1
    public static let payloadVersion = 1
    public static let deckCount = 1
    public static let dealerStandsOnSoft17 = true
}

public enum PrismetBlackjackParticipant: String, Codable, Hashable, Sendable {
    case player
    case dealer
}

public enum PrismetBlackjackPhase: String, Codable, Hashable, Sendable {
    case playerTurn
    case dealerTurn
    case completed
    case abandoned
}

public enum PrismetBlackjackCommand: String, CaseIterable, Codable, Hashable, Sendable {
    case hit
    case stand
}

public struct PrismetBlackjackHandValue: Codable, Hashable, Sendable {
    public let total: Int
    public let isSoft: Bool
    public let isBust: Bool
    public let isNatural: Bool

    public init(cards: [PrismetPlayingCard]) {
        var total = 0
        var softAces = 0

        for card in cards {
            switch card.rank {
            case .ace:
                total += 11
                softAces += 1
            case .king, .queen, .jack, .ten:
                total += 10
            default:
                total += card.rank.rawValue
            }
        }

        while total > 21, softAces > 0 {
            total -= 10
            softAces -= 1
        }

        self.total = total
        self.isSoft = softAces > 0
        self.isBust = total > 21
        self.isNatural = cards.count == 2 && total == 21
    }
}

public enum PrismetBlackjackOutcome: String, Codable, Hashable, Sendable {
    case playerWins
    case dealerWins
    case tie
    case abandoned
}

public enum PrismetBlackjackResolutionReason: String, Codable, Hashable, Sendable {
    case playerNatural
    case dealerNatural
    case playerBust
    case dealerBust
    case playerHigherTotal
    case dealerHigherTotal
    case equalTotals
    case endedByPlayer
}

public struct PrismetBlackjackResolution: Codable, Hashable, Sendable {
    public let outcome: PrismetBlackjackOutcome
    public let reason: PrismetBlackjackResolutionReason
    public let playerValue: PrismetBlackjackHandValue
    public let dealerValue: PrismetBlackjackHandValue

    public init(
        outcome: PrismetBlackjackOutcome,
        reason: PrismetBlackjackResolutionReason,
        playerValue: PrismetBlackjackHandValue,
        dealerValue: PrismetBlackjackHandValue
    ) {
        self.outcome = outcome
        self.reason = reason
        self.playerValue = playerValue
        self.dealerValue = dealerValue
    }

    public static func resolve(
        playerCards: [PrismetPlayingCard],
        dealerCards: [PrismetPlayingCard]
    ) -> PrismetBlackjackResolution {
        let player = PrismetBlackjackHandValue(cards: playerCards)
        let dealer = PrismetBlackjackHandValue(cards: dealerCards)

        if player.isBust {
            return PrismetBlackjackResolution(
                outcome: .dealerWins,
                reason: .playerBust,
                playerValue: player,
                dealerValue: dealer
            )
        }
        if dealer.isBust {
            return PrismetBlackjackResolution(
                outcome: .playerWins,
                reason: .dealerBust,
                playerValue: player,
                dealerValue: dealer
            )
        }
        if player.isNatural, !dealer.isNatural {
            return PrismetBlackjackResolution(
                outcome: .playerWins,
                reason: .playerNatural,
                playerValue: player,
                dealerValue: dealer
            )
        }
        if dealer.isNatural, !player.isNatural {
            return PrismetBlackjackResolution(
                outcome: .dealerWins,
                reason: .dealerNatural,
                playerValue: player,
                dealerValue: dealer
            )
        }
        if player.total > dealer.total {
            return PrismetBlackjackResolution(
                outcome: .playerWins,
                reason: .playerHigherTotal,
                playerValue: player,
                dealerValue: dealer
            )
        }
        if dealer.total > player.total {
            return PrismetBlackjackResolution(
                outcome: .dealerWins,
                reason: .dealerHigherTotal,
                playerValue: player,
                dealerValue: dealer
            )
        }
        return PrismetBlackjackResolution(
            outcome: .tie,
            reason: .equalTotals,
            playerValue: player,
            dealerValue: dealer
        )
    }
}
