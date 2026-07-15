public enum PrismetPokerCategory: Int, CaseIterable, Codable, Comparable, Hashable, Sendable {
    case highCard, onePair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private extension PrismetPokerCategory {
    var exactFiveCardHandCount: Int {
        switch self {
        case .highCard: return 1_302_540
        case .onePair: return 1_098_240
        case .twoPair: return 123_552
        case .threeOfAKind: return 54_912
        case .straight: return 10_200
        case .flush: return 5_108
        case .fullHouse: return 3_744
        case .fourOfAKind: return 624
        case .straightFlush: return 36
        case .royalFlush: return 4
        }
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

public enum PrismetFiveCardPokerStateValidationError: Error, Equatable {
    case unsupportedRandomizerVersion(Int)
    case shuffledDeckMismatch
    case invalidCardCount(Int)
    case duplicateCards
    case invalidHoldIndex(Int)
    case invalidDrawIndex(expected: Int, actual: Int)
    case cardsDoNotMatchDrawHistory
    case invalidCategory(expected: PrismetPokerCategory?, actual: PrismetPokerCategory?)
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

    private enum CodingKeys: String, CodingKey {
        case seed
        case randomizerVersion
        case cards
        case heldIndices
        case phase
        case category
        case shuffledDeck
        case drawIndex
    }

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let cards = try container.decode([PrismetPlayingCard].self, forKey: .cards)
        let heldIndices = try container.decode(Set<Int>.self, forKey: .heldIndices)
        let phase = try container.decode(PrismetFiveCardPokerPhase.self, forKey: .phase)
        let category = try container.decodeIfPresent(PrismetPokerCategory.self, forKey: .category)
        let shuffledDeck = try container.decode([PrismetPlayingCard].self, forKey: .shuffledDeck)
        let drawIndex = try container.decode(Int.self, forKey: .drawIndex)

        try Self.validate(
            seed: seed,
            randomizerVersion: randomizerVersion,
            cards: cards,
            heldIndices: heldIndices,
            phase: phase,
            category: category,
            shuffledDeck: shuffledDeck,
            drawIndex: drawIndex
        )

        self.init(
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seed, forKey: .seed)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(cards, forKey: .cards)
        try container.encode(heldIndices, forKey: .heldIndices)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(shuffledDeck, forKey: .shuffledDeck)
        try container.encode(drawIndex, forKey: .drawIndex)
    }

    fileprivate static func canonicalShuffledDeck(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }

    private static func validate(
        seed: UInt64,
        randomizerVersion: Int,
        cards: [PrismetPlayingCard],
        heldIndices: Set<Int>,
        phase: PrismetFiveCardPokerPhase,
        category: PrismetPokerCategory?,
        shuffledDeck: [PrismetPlayingCard],
        drawIndex: Int
    ) throws {
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetFiveCardPokerStateValidationError.unsupportedRandomizerVersion(
                randomizerVersion
            )
        }
        guard shuffledDeck == (try canonicalShuffledDeck(seed: seed)) else {
            throw PrismetFiveCardPokerStateValidationError.shuffledDeckMismatch
        }
        guard cards.count == 5 else {
            throw PrismetFiveCardPokerStateValidationError.invalidCardCount(cards.count)
        }
        guard Set(cards).count == cards.count else {
            throw PrismetFiveCardPokerStateValidationError.duplicateCards
        }
        if let invalidHoldIndex = heldIndices
            .filter({ !(0..<5).contains($0) })
            .sorted()
            .first {
            throw PrismetFiveCardPokerStateValidationError.invalidHoldIndex(invalidHoldIndex)
        }

        var expectedCards = Array(shuffledDeck.prefix(5))
        let expectedDrawIndex: Int
        let expectedCategory: PrismetPokerCategory?

        switch phase {
        case .choosingHolds:
            expectedDrawIndex = 5
            expectedCategory = nil

        case .complete:
            var nextDrawIndex = 5
            for index in expectedCards.indices where !heldIndices.contains(index) {
                expectedCards[index] = shuffledDeck[nextDrawIndex]
                nextDrawIndex += 1
            }
            expectedDrawIndex = nextDrawIndex
            expectedCategory = try PrismetFiveCardPokerEngine.evaluate(expectedCards)
        }

        guard drawIndex == expectedDrawIndex else {
            throw PrismetFiveCardPokerStateValidationError.invalidDrawIndex(
                expected: expectedDrawIndex,
                actual: drawIndex
            )
        }
        guard cards == expectedCards else {
            throw PrismetFiveCardPokerStateValidationError.cardsDoNotMatchDrawHistory
        }
        guard category == expectedCategory else {
            throw PrismetFiveCardPokerStateValidationError.invalidCategory(
                expected: expectedCategory,
                actual: category
            )
        }
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
    public static let exactCategoryCounts: [PrismetPokerCategoryCount] =
        PrismetPokerCategory.allCases.map {
            PrismetPokerCategoryCount(category: $0, count: $0.exactFiveCardHandCount)
        }

    public static let exactTotalHandCount = 2_598_960

    public static func exactCount(for category: PrismetPokerCategory) -> Int {
        category.exactFiveCardHandCount
    }

    public static func deal(seed: UInt64) throws -> PrismetFiveCardPokerState {
        try .dealt(
            seed: seed,
            shuffledDeck: PrismetFiveCardPokerState.canonicalShuffledDeck(seed: seed)
        )
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
            guard state.shuffledDeck.indices.contains(drawIndex) else {
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
