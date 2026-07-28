import Foundation

public enum PrismetHoldemHandLabPhase: String, Codable, Hashable, Sendable {
    case ready, holeCards, flop, turn, river, complete
}

public enum PrismetHoldemHandLabStateValidationError: Error, Equatable {
    case missingSeed
    case unexpectedSeed
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case invalidHoleCards
    case invalidCommunityCards
    case invalidBurnedCardCount(expected: Int, actual: Int)
    case invalidCategory(expected: PrismetPokerCategory?, actual: PrismetPokerCategory?)
}

public struct PrismetHoldemHandLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let seed: UInt64?
    public let rulesVersion: Int
    public let randomizerVersion: Int?
    public let phase: PrismetHoldemHandLabPhase
    public let holeCards: [PrismetPlayingCard]
    public let communityCards: [PrismetPlayingCard]
    public let burnedCardCount: Int
    public let bestCategory: PrismetPokerCategory?

    private let shuffledDeck: [PrismetPlayingCard]

    public static let ready = PrismetHoldemHandLabState(
        seed: nil,
        rulesVersion: PrismetHoldemHandLabState.rulesVersion,
        randomizerVersion: nil,
        phase: .ready,
        holeCards: [],
        communityCards: [],
        burnedCardCount: 0,
        bestCategory: nil,
        shuffledDeck: []
    )

    private enum CodingKeys: String, CodingKey {
        case seed
        case rulesVersion
        case randomizerVersion
        case phase
        case holeCards
        case communityCards
        case burnedCardCount
        case bestCategory
    }

    private init(
        seed: UInt64?,
        rulesVersion: Int,
        randomizerVersion: Int?,
        phase: PrismetHoldemHandLabPhase,
        holeCards: [PrismetPlayingCard],
        communityCards: [PrismetPlayingCard],
        burnedCardCount: Int,
        bestCategory: PrismetPokerCategory?,
        shuffledDeck: [PrismetPlayingCard]
    ) {
        self.seed = seed
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.phase = phase
        self.holeCards = holeCards
        self.communityCards = communityCards
        self.burnedCardCount = burnedCardCount
        self.bestCategory = bestCategory
        self.shuffledDeck = shuffledDeck
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        let rulesVersion = try container.decodeIfPresent(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decodeIfPresent(Int.self, forKey: .randomizerVersion)
        let phase = try container.decode(PrismetHoldemHandLabPhase.self, forKey: .phase)
        let holeCards = try container.decode([PrismetPlayingCard].self, forKey: .holeCards)
        let communityCards = try container.decode([PrismetPlayingCard].self, forKey: .communityCards)
        let burnedCardCount = try container.decode(Int.self, forKey: .burnedCardCount)
        let bestCategory = try container.decodeIfPresent(PrismetPokerCategory.self, forKey: .bestCategory)

        let shuffledDeck = try Self.validate(
            seed: seed,
            rulesVersion: rulesVersion,
            randomizerVersion: randomizerVersion,
            phase: phase,
            holeCards: holeCards,
            communityCards: communityCards,
            burnedCardCount: burnedCardCount,
            bestCategory: bestCategory
        )

        self.init(
            seed: seed,
            rulesVersion: rulesVersion ?? -1,
            randomizerVersion: randomizerVersion,
            phase: phase,
            holeCards: holeCards,
            communityCards: communityCards,
            burnedCardCount: burnedCardCount,
            bestCategory: bestCategory,
            shuffledDeck: shuffledDeck
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encodeIfPresent(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(phase, forKey: .phase)
        try container.encode(holeCards, forKey: .holeCards)
        try container.encode(communityCards, forKey: .communityCards)
        try container.encode(burnedCardCount, forKey: .burnedCardCount)
        try container.encodeIfPresent(bestCategory, forKey: .bestCategory)
    }

    fileprivate static func dealt(seed: UInt64) throws -> Self {
        let shuffledDeck = try canonicalShuffledDeck(seed: seed)
        return try state(seed: seed, phase: .holeCards, shuffledDeck: shuffledDeck)
    }

    fileprivate func advancing(to phase: PrismetHoldemHandLabPhase) throws -> Self {
        guard let seed else { throw PrismetHoldemHandLabStateValidationError.missingSeed }
        return try Self.state(seed: seed, phase: phase, shuffledDeck: shuffledDeck)
    }

    fileprivate static func canonicalShuffledDeck(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }

    private static func state(
        seed: UInt64,
        phase: PrismetHoldemHandLabPhase,
        shuffledDeck: [PrismetPlayingCard]
    ) throws -> Self {
        let layout = layout(for: phase)
        let holeCards = Array(shuffledDeck.prefix(2))
        let communityCards: [PrismetPlayingCard]
        switch layout.communityCardCount {
        case 0:
            communityCards = []
        case 3:
            communityCards = Array(shuffledDeck[3...5])
        case 4:
            communityCards = Array(shuffledDeck[3...5]) + [shuffledDeck[7]]
        case 5:
            communityCards = Array(shuffledDeck[3...5]) + [shuffledDeck[7], shuffledDeck[9]]
        default:
            communityCards = []
        }
        let bestCategory = phase == .complete
            ? try PrismetHoldemHandLabEngine.bestCategory(for: holeCards + communityCards)
            : nil

        return Self(
            seed: seed,
            rulesVersion: Self.rulesVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            phase: phase,
            holeCards: holeCards,
            communityCards: communityCards,
            burnedCardCount: layout.burnedCardCount,
            bestCategory: bestCategory,
            shuffledDeck: shuffledDeck
        )
    }

    private static func validate(
        seed: UInt64?,
        rulesVersion: Int?,
        randomizerVersion: Int?,
        phase: PrismetHoldemHandLabPhase,
        holeCards: [PrismetPlayingCard],
        communityCards: [PrismetPlayingCard],
        burnedCardCount: Int,
        bestCategory: PrismetPokerCategory?
    ) throws -> [PrismetPlayingCard] {
        guard phase != .ready else {
            guard seed == nil, rulesVersion == Self.rulesVersion, randomizerVersion == nil, holeCards.isEmpty, communityCards.isEmpty,
                burnedCardCount == 0, bestCategory == nil else {
                throw PrismetHoldemHandLabStateValidationError.unexpectedSeed
            }
            return []
        }

        guard let seed else { throw PrismetHoldemHandLabStateValidationError.missingSeed }
        guard rulesVersion == Self.rulesVersion else {
            throw PrismetHoldemHandLabStateValidationError.unsupportedRulesVersion(rulesVersion ?? -1)
        }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetHoldemHandLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion ?? -1)
        }

        let deck = try canonicalShuffledDeck(seed: seed)
        let expected = try state(seed: seed, phase: phase, shuffledDeck: deck)
        guard holeCards == expected.holeCards else {
            throw PrismetHoldemHandLabStateValidationError.invalidHoleCards
        }
        guard communityCards == expected.communityCards else {
            throw PrismetHoldemHandLabStateValidationError.invalidCommunityCards
        }
        guard burnedCardCount == expected.burnedCardCount else {
            throw PrismetHoldemHandLabStateValidationError.invalidBurnedCardCount(
                expected: expected.burnedCardCount,
                actual: burnedCardCount
            )
        }
        guard bestCategory == expected.bestCategory else {
            throw PrismetHoldemHandLabStateValidationError.invalidCategory(
                expected: expected.bestCategory,
                actual: bestCategory
            )
        }
        return deck
    }

    private static func layout(for phase: PrismetHoldemHandLabPhase) -> (communityCardCount: Int, burnedCardCount: Int) {
        switch phase {
        case .ready, .holeCards:
            return (0, 0)
        case .flop:
            return (3, 1)
        case .turn:
            return (4, 2)
        case .river, .complete:
            return (5, 3)
        }
    }
}

public enum PrismetHoldemHandLabEngineError: Error, Equatable {
    case invalidPhase(expected: PrismetHoldemHandLabPhase, actual: PrismetHoldemHandLabPhase)
    case invalidCardCount(Int)
    case duplicateCards
}

public enum PrismetHoldemHandLabEngine {
    public static let exactCategoryCounts: [PrismetPokerCategoryCount] = [
        .init(category: .highCard, count: 23_294_460),
        .init(category: .onePair, count: 58_627_800),
        .init(category: .twoPair, count: 31_433_400),
        .init(category: .threeOfAKind, count: 6_461_620),
        .init(category: .straight, count: 6_180_020),
        .init(category: .flush, count: 4_047_644),
        .init(category: .fullHouse, count: 3_473_184),
        .init(category: .fourOfAKind, count: 224_848),
        .init(category: .straightFlush, count: 37_260),
        .init(category: .royalFlush, count: 4_324),
    ]

    public static let exactTotalHandCount = 133_784_560

    public static func exactCount(for category: PrismetPokerCategory) -> Int {
        exactCategoryCounts.first(where: { $0.category == category })?.count ?? 0
    }

    public static func deal(seed: UInt64) throws -> PrismetHoldemHandLabState {
        try .dealt(seed: seed)
    }

    public static func revealFlop(in state: PrismetHoldemHandLabState) throws -> PrismetHoldemHandLabState {
        try advance(state, expected: .holeCards, to: .flop)
    }

    public static func revealTurn(in state: PrismetHoldemHandLabState) throws -> PrismetHoldemHandLabState {
        try advance(state, expected: .flop, to: .turn)
    }

    public static func revealRiver(in state: PrismetHoldemHandLabState) throws -> PrismetHoldemHandLabState {
        try advance(state, expected: .turn, to: .river)
    }

    public static func complete(_ state: PrismetHoldemHandLabState) throws -> PrismetHoldemHandLabState {
        try advance(state, expected: .river, to: .complete)
    }

    public static func bestCategory(for cards: [PrismetPlayingCard]) throws -> PrismetPokerCategory {
        guard cards.count == 7 else {
            throw PrismetHoldemHandLabEngineError.invalidCardCount(cards.count)
        }
        guard Set(cards).count == cards.count else {
            throw PrismetHoldemHandLabEngineError.duplicateCards
        }

        var best: PrismetPokerCategory?
        for first in 0..<3 {
            for second in (first + 1)..<4 {
                for third in (second + 1)..<5 {
                    for fourth in (third + 1)..<6 {
                        for fifth in (fourth + 1)..<7 {
                            let category = try PrismetFiveCardPokerEngine.evaluate([
                                cards[first], cards[second], cards[third], cards[fourth], cards[fifth],
                            ])
                            if best.map({ category > $0 }) ?? true {
                                best = category
                            }
                        }
                    }
                }
            }
        }
        guard let best else {
            throw PrismetHoldemHandLabEngineError.invalidCardCount(cards.count)
        }
        return best
    }

    private static func advance(
        _ state: PrismetHoldemHandLabState,
        expected: PrismetHoldemHandLabPhase,
        to nextPhase: PrismetHoldemHandLabPhase
    ) throws -> PrismetHoldemHandLabState {
        guard state.phase == expected else {
            throw PrismetHoldemHandLabEngineError.invalidPhase(expected: expected, actual: state.phase)
        }
        return try state.advancing(to: nextPhase)
    }
}
