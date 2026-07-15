public enum PrismetPokerCategory: Int, CaseIterable, Codable, Comparable, Hashable, Sendable {
    case highCard, onePair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PrismetPokerCategoryCount: Codable, Hashable, Sendable {
    public let category: PrismetPokerCategory
    public let count: Int

    public init(category: PrismetPokerCategory, count: Int) {
        self.category = category
        self.count = count
    }
}

public enum PrismetFiveCardPokerPhase: String, Codable, Hashable, Sendable {
    case choosingHolds, complete
}

public struct PrismetFiveCardPokerState: Codable, Hashable, Sendable {
    public let seed: UInt64
    public let randomizerVersion: Int
    public let cards: [PrismetPlayingCard]
    public let heldIndices: Set<Int>
    public let phase: PrismetFiveCardPokerPhase
    public let category: PrismetPokerCategory?
    fileprivate let shuffledDeck: [PrismetPlayingCard]
    fileprivate let drawIndex: Int

    private init(
        seed: UInt64,
        randomizerVersion: Int,
        cards: [PrismetPlayingCard],
        heldIndices: Set<Int>,
        phase: PrismetFiveCardPokerPhase,
        category: PrismetPokerCategory?,
        shuffledDeck: [PrismetPlayingCard],
        drawIndex: Int
    ) {
        self.seed = seed
        self.randomizerVersion = randomizerVersion
        self.cards = cards
        self.heldIndices = heldIndices
        self.phase = phase
        self.category = category
        self.shuffledDeck = shuffledDeck
        self.drawIndex = drawIndex
    }

    fileprivate func withHeldIndices(_ heldIndices: Set<Int>) -> Self {
        Self(
            seed: seed,
            randomizerVersion: randomizerVersion,
            cards: cards,
            heldIndices: heldIndices,
            phase: phase,
            category: category,
            shuffledDeck: shuffledDeck,
            drawIndex: drawIndex
        )
    }

    fileprivate func completing(with cards: [PrismetPlayingCard], category: PrismetPokerCategory, drawIndex: Int) -> Self {
        Self(
            seed: seed,
            randomizerVersion: randomizerVersion,
            cards: cards,
            heldIndices: heldIndices,
            phase: .complete,
            category: category,
            shuffledDeck: shuffledDeck,
            drawIndex: drawIndex
        )
    }

    fileprivate static func dealt(seed: UInt64, shuffledDeck: [PrismetPlayingCard]) -> Self {
        Self(
            seed: seed,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            cards: Array(shuffledDeck.prefix(5)),
            heldIndices: [],
            phase: .choosingHolds,
            category: nil,
            shuffledDeck: shuffledDeck,
            drawIndex: 5
        )
    }
}

public enum PrismetFiveCardPokerEngineError: Error, Equatable {
    case invalidCardCount(Int)
    case duplicateCards
    case invalidHoldIndex(Int)
    case invalidPhase(PrismetFiveCardPokerPhase)
    case deckExhausted
}

public enum PrismetFiveCardPokerEngine {
    /// Mutually exclusive five-card hand counts; straight flush excludes royal flush.
    public static let exactCategoryCounts: [PrismetPokerCategoryCount] = [
        .init(category: .highCard, count: 1_302_540),
        .init(category: .onePair, count: 1_098_240),
        .init(category: .twoPair, count: 123_552),
        .init(category: .threeOfAKind, count: 54_912),
        .init(category: .straight, count: 10_200),
        .init(category: .flush, count: 5_108),
        .init(category: .fullHouse, count: 3_744),
        .init(category: .fourOfAKind, count: 624),
        .init(category: .straightFlush, count: 36),
        .init(category: .royalFlush, count: 4),
    ]

    public static let exactTotalHandCount = 2_598_960

    public static func exactCount(for category: PrismetPokerCategory) -> Int {
        exactCategoryCounts.first(where: { $0.category == category })!.count
    }

    public static func deal(seed: UInt64) throws -> PrismetFiveCardPokerState {
        var shuffledDeck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&shuffledDeck)
        return .dealt(seed: seed, shuffledDeck: shuffledDeck)
    }

    public static func togglingHold(
        at index: Int,
        in state: PrismetFiveCardPokerState
    ) throws -> PrismetFiveCardPokerState {
        guard state.phase == .choosingHolds else {
            throw PrismetFiveCardPokerEngineError.invalidPhase(state.phase)
        }
        guard state.cards.indices.contains(index) else {
            throw PrismetFiveCardPokerEngineError.invalidHoldIndex(index)
        }

        var heldIndices = state.heldIndices
        if !heldIndices.insert(index).inserted {
            heldIndices.remove(index)
        }
        return state.withHeldIndices(heldIndices)
    }

    public static func drawing(_ state: PrismetFiveCardPokerState) throws -> PrismetFiveCardPokerState {
        guard state.phase == .choosingHolds else {
            throw PrismetFiveCardPokerEngineError.invalidPhase(state.phase)
        }

        var finalCards = state.cards
        var drawIndex = state.drawIndex
        for index in finalCards.indices where !state.heldIndices.contains(index) {
            guard drawIndex < state.shuffledDeck.count else {
                throw PrismetFiveCardPokerEngineError.deckExhausted
            }
            finalCards[index] = state.shuffledDeck[drawIndex]
            drawIndex += 1
        }

        return state.completing(
            with: finalCards,
            category: try evaluate(finalCards),
            drawIndex: drawIndex
        )
    }

    public static func evaluate(_ cards: [PrismetPlayingCard]) throws -> PrismetPokerCategory {
        guard cards.count == 5 else {
            throw PrismetFiveCardPokerEngineError.invalidCardCount(cards.count)
        }
        guard Set(cards).count == cards.count else {
            throw PrismetFiveCardPokerEngineError.duplicateCards
        }

        let ranks = cards.map(\.rank.rawValue)
        let rankCounts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
        let groups = rankCounts.values.sorted(by: >)
        let isFlush = Set(cards.map(\.suit)).count == 1
        let isStraight = isStraight(ranks)

        if isFlush && isStraight {
            return Set(ranks) == Set([10, 11, 12, 13, 14]) ? .royalFlush : .straightFlush
        }
        if groups == [4, 1] { return .fourOfAKind }
        if groups == [3, 2] { return .fullHouse }
        if isFlush { return .flush }
        if isStraight { return .straight }
        if groups == [3, 1, 1] { return .threeOfAKind }
        if groups == [2, 2, 1] { return .twoPair }
        if groups == [2, 1, 1, 1] { return .onePair }
        return .highCard
    }

    private static func isStraight(_ ranks: [Int]) -> Bool {
        let uniqueRanks = Set(ranks)
        guard uniqueRanks.count == 5 else { return false }
        if uniqueRanks == Set([2, 3, 4, 5, 14]) { return true }

        guard let low = uniqueRanks.min(), let high = uniqueRanks.max() else { return false }
        return high - low == 4
    }
}
