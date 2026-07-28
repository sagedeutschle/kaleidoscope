public enum PrismetThreeCardPokerCategory: Int, CaseIterable, Codable, Comparable, Hashable, Sendable {
    case highCard, onePair, flush, straight, threeOfAKind, straightFlush

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum PrismetThreeCardPokerHandValueError: Error, Equatable {
    case invalidCardCount(Int)
    case duplicateCards
}

public struct PrismetThreeCardPokerHandValue: Codable, Comparable, Hashable, Sendable {
    public let category: PrismetThreeCardPokerCategory
    public let tieBreakRanks: [Int]

    public init(cards: [PrismetPlayingCard]) throws {
        guard cards.count == 3 else { throw PrismetThreeCardPokerHandValueError.invalidCardCount(cards.count) }
        guard Set(cards).count == cards.count else { throw PrismetThreeCardPokerHandValueError.duplicateCards }

        let ranks = cards.map { $0.rank.rawValue }
        let groups = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
        let orderedGroups = groups.map { (rank: $0.key, count: $0.value) }
        let sortedRanks = ranks.sorted(by: >)
        let straightHigh = Self.straightHighRank(ranks)
        let isFlush = Set(cards.map(\.suit)).count == 1

        if let straightHigh, isFlush {
            category = .straightFlush
            tieBreakRanks = [straightHigh]
        } else if let trips = orderedGroups.first(where: { $0.count == 3 }) {
            category = .threeOfAKind
            tieBreakRanks = [trips.rank]
        } else if let straightHigh {
            category = .straight
            tieBreakRanks = [straightHigh]
        } else if isFlush {
            category = .flush
            tieBreakRanks = sortedRanks
        } else if let pair = orderedGroups.first(where: { $0.count == 2 }) {
            category = .onePair
            tieBreakRanks = [pair.rank] + orderedGroups.filter { $0.count == 1 }.map(\.rank)
        } else {
            category = .highCard
            tieBreakRanks = sortedRanks
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (left, right) in zip(lhs.tieBreakRanks, rhs.tieBreakRanks) where left != right { return left < right }
        return lhs.tieBreakRanks.count < rhs.tieBreakRanks.count
    }

    private static func straightHighRank(_ ranks: [Int]) -> Int? {
        let unique = Set(ranks)
        guard unique.count == 3 else { return nil }
        if unique == Set([2, 3, 14]) { return 3 }
        guard let low = unique.min(), let high = unique.max(), high - low == 2 else { return nil }
        return high
    }
}

public struct PrismetLabVisibleCard: Codable, Hashable, Sendable {
    public let card: PrismetPlayingCard?

    public static let hidden = Self(card: nil)
    public init(card: PrismetPlayingCard?) { self.card = card }
}

public enum PrismetThreeCardPokerPhase: String, Codable, Hashable, Sendable { case dealt, revealed }

public enum PrismetThreeCardPokerLabError: Error, Equatable { case invalidPhase(PrismetThreeCardPokerPhase) }

public enum PrismetThreeCardPokerLabStateValidationError: Error, Equatable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case shuffledDeckMismatch
    case invalidCursor(expected: Int, actual: Int)
    case invalidReferenceFaceUpCount(expected: Int, actual: Int)
    case invalidLearnerCards
    case invalidReferenceCards
    case invalidComparison
}

public struct PrismetThreeCardPokerLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let seed: UInt64
    public let learnerCards: [PrismetPlayingCard]
    public let phase: PrismetThreeCardPokerPhase
    public let comparison: PrismetPokerComparison?
    public let referenceCards: [PrismetLabVisibleCard]
    private let shuffledDeck: [PrismetPlayingCard]
    private let dealtReferenceCards: [PrismetPlayingCard]
    private let cursor: Int
    private let referenceFaceUpCount: Int

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, randomizerVersion, seed, learnerCards, phase, comparison, shuffledDeck, dealtReferenceCards, cursor, referenceFaceUpCount
    }

    private init(seed: UInt64, shuffledDeck: [PrismetPlayingCard], phase: PrismetThreeCardPokerPhase, comparison: PrismetPokerComparison?, referenceFaceUpCount: Int) {
        self.rulesVersion = Self.rulesVersion
        self.randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        self.seed = seed
        self.learnerCards = Array(shuffledDeck.prefix(3))
        self.dealtReferenceCards = Array(shuffledDeck[3..<6])
        self.phase = phase
        self.comparison = comparison
        self.shuffledDeck = shuffledDeck
        self.cursor = 6
        self.referenceFaceUpCount = referenceFaceUpCount
        self.referenceCards = Self.visibleCards(dealtReferenceCards: self.dealtReferenceCards, count: referenceFaceUpCount)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        let learnerCards = try container.decode([PrismetPlayingCard].self, forKey: .learnerCards)
        let phase = try container.decode(PrismetThreeCardPokerPhase.self, forKey: .phase)
        let comparison = try container.decodeIfPresent(PrismetPokerComparison.self, forKey: .comparison)
        let shuffledDeck = try container.decode([PrismetPlayingCard].self, forKey: .shuffledDeck)
        let dealtReferenceCards = try container.decode([PrismetPlayingCard].self, forKey: .dealtReferenceCards)
        let cursor = try container.decode(Int.self, forKey: .cursor)
        let referenceFaceUpCount = try container.decode(Int.self, forKey: .referenceFaceUpCount)
        try Self.validate(rulesVersion: rulesVersion, randomizerVersion: randomizerVersion, seed: seed, learnerCards: learnerCards, phase: phase, comparison: comparison, shuffledDeck: shuffledDeck, dealtReferenceCards: dealtReferenceCards, cursor: cursor, referenceFaceUpCount: referenceFaceUpCount)
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.seed = seed
        self.learnerCards = learnerCards
        self.phase = phase
        self.comparison = comparison
        self.shuffledDeck = shuffledDeck
        self.dealtReferenceCards = dealtReferenceCards
        self.cursor = cursor
        self.referenceFaceUpCount = referenceFaceUpCount
        self.referenceCards = Self.visibleCards(dealtReferenceCards: dealtReferenceCards, count: referenceFaceUpCount)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(learnerCards, forKey: .learnerCards)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(comparison, forKey: .comparison)
        try container.encode(shuffledDeck, forKey: .shuffledDeck)
        try container.encode(dealtReferenceCards, forKey: .dealtReferenceCards)
        try container.encode(cursor, forKey: .cursor)
        try container.encode(referenceFaceUpCount, forKey: .referenceFaceUpCount)
    }

    fileprivate static func dealt(seed: UInt64, shuffledDeck: [PrismetPlayingCard]) -> Self { Self(seed: seed, shuffledDeck: shuffledDeck, phase: .dealt, comparison: nil, referenceFaceUpCount: 0) }

    fileprivate func revealing() throws -> Self {
        let learner = try PrismetThreeCardPokerHandValue(cards: learnerCards)
        let reference = try PrismetThreeCardPokerHandValue(cards: dealtReferenceCards)
        let comparison: PrismetPokerComparison = learner > reference ? .learnerHigher : learner < reference ? .referenceHigher : .neutral
        return Self(seed: seed, shuffledDeck: shuffledDeck, phase: .revealed, comparison: comparison, referenceFaceUpCount: 3)
    }

    private static func canonicalDeck(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }

    private static func visibleCards(dealtReferenceCards: [PrismetPlayingCard], count: Int) -> [PrismetLabVisibleCard] {
        dealtReferenceCards.enumerated().map { index, card in index < count ? PrismetLabVisibleCard(card: card) : .hidden }
    }

    private static func validate(rulesVersion: Int, randomizerVersion: Int, seed: UInt64, learnerCards: [PrismetPlayingCard], phase: PrismetThreeCardPokerPhase, comparison: PrismetPokerComparison?, shuffledDeck: [PrismetPlayingCard], dealtReferenceCards: [PrismetPlayingCard], cursor: Int, referenceFaceUpCount: Int) throws {
        guard rulesVersion == Self.rulesVersion else { throw PrismetThreeCardPokerLabStateValidationError.unsupportedRulesVersion(rulesVersion) }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else { throw PrismetThreeCardPokerLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion) }
        guard shuffledDeck == (try canonicalDeck(seed: seed)) else { throw PrismetThreeCardPokerLabStateValidationError.shuffledDeckMismatch }
        guard cursor == 6 else { throw PrismetThreeCardPokerLabStateValidationError.invalidCursor(expected: 6, actual: cursor) }
        guard learnerCards == Array(shuffledDeck.prefix(3)) else { throw PrismetThreeCardPokerLabStateValidationError.invalidLearnerCards }
        guard dealtReferenceCards == Array(shuffledDeck[3..<6]) else { throw PrismetThreeCardPokerLabStateValidationError.invalidReferenceCards }
        let expectedFaceUp = phase == .dealt ? 0 : 3
        guard referenceFaceUpCount == expectedFaceUp else { throw PrismetThreeCardPokerLabStateValidationError.invalidReferenceFaceUpCount(expected: expectedFaceUp, actual: referenceFaceUpCount) }
        if phase == .dealt {
            guard comparison == nil else { throw PrismetThreeCardPokerLabStateValidationError.invalidComparison }
        } else {
            let learner = try PrismetThreeCardPokerHandValue(cards: learnerCards)
            let reference = try PrismetThreeCardPokerHandValue(cards: dealtReferenceCards)
            let expected: PrismetPokerComparison = learner > reference ? .learnerHigher : learner < reference ? .referenceHigher : .neutral
            guard comparison == expected else { throw PrismetThreeCardPokerLabStateValidationError.invalidComparison }
        }
    }
}

public enum PrismetThreeCardPokerLab {
    public static let exactTotalSingleHandCount = 22_100
    public static let exactCategoryCounts: [PrismetThreeCardPokerCategory: Int] = [.straightFlush: 48, .threeOfAKind: 52, .straight: 720, .flush: 1_096, .onePair: 3_744, .highCard: 16_440]

    public static func deal(seed: UInt64) throws -> PrismetThreeCardPokerLabState {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return .dealt(seed: seed, shuffledDeck: deck)
    }

    public static func revealComparison(in state: PrismetThreeCardPokerLabState) throws -> PrismetThreeCardPokerLabState {
        guard state.phase == .dealt else { throw PrismetThreeCardPokerLabError.invalidPhase(state.phase) }
        return try state.revealing()
    }
}
