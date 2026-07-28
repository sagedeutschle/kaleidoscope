import Foundation

/// A Pai Gow study deck is a standard deck plus one distinct joker.
public enum PrismetPaiGowCard: Codable, Hashable, Sendable {
    case standard(PrismetPlayingCard)
    case joker
}

public enum PrismetPaiGowJokerSubstitution: Codable, Hashable, Sendable {
    case ace
    case straight(rank: PrismetCardRank)
    case flush(suit: PrismetCardSuit, rank: PrismetCardRank)
    case straightFlush(suit: PrismetCardSuit, rank: PrismetCardRank)
}

public enum PrismetPaiGowHandCategory: Int, Codable, Comparable, Hashable, Sendable {
    case highCard, onePair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush, fiveAces

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A five-card value. The wheel is encoded as rank 5, below a six-high straight and every
/// other straight, as in ordinary poker ordering.
public struct PrismetPaiGowHighHandValue: Codable, Comparable, Hashable, Sendable {
    public let category: PrismetPaiGowHandCategory
    public let tieBreakRanks: [Int]
    public let jokerSubstitution: PrismetPaiGowJokerSubstitution?

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (left, right) in zip(lhs.tieBreakRanks, rhs.tieBreakRanks) where left != right {
            return left < right
        }
        return lhs.tieBreakRanks.count < rhs.tieBreakRanks.count
    }
}

public enum PrismetPaiGowLowHandCategory: Int, Codable, Comparable, Hashable, Sendable {
    case highCard, pair
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct PrismetPaiGowLowHandValue: Codable, Comparable, Hashable, Sendable {
    public let category: PrismetPaiGowLowHandCategory
    public let tieBreakRanks: [Int]

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (left, right) in zip(lhs.tieBreakRanks, rhs.tieBreakRanks) where left != right {
            return left < right
        }
        return lhs.tieBreakRanks.count < rhs.tieBreakRanks.count
    }
}

/// This bridge makes the cross-size ordering explicit: category tier is compared first,
/// then the category's ordinary lexicographic ranks. A selected split is legal only when
/// its five-card value is greater than its two-card value under this bridge.
public struct PrismetPaiGowComparableValue: Codable, Comparable, Hashable, Sendable {
    public let categoryTier: Int
    public let tieBreakRanks: [Int]

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.categoryTier != rhs.categoryTier { return lhs.categoryTier < rhs.categoryTier }
        for (left, right) in zip(lhs.tieBreakRanks, rhs.tieBreakRanks) where left != right {
            return left < right
        }
        return lhs.tieBreakRanks.count < rhs.tieBreakRanks.count
    }
}

public struct PrismetPaiGowSplitAnalysis: Codable, Hashable, Sendable {
    public let lowCardIndices: [Int]
    public let lowCards: [PrismetPaiGowCard]
    public let highCards: [PrismetPaiGowCard]
    public let lowHand: PrismetPaiGowLowHandValue
    public let highHand: PrismetPaiGowHighHandValue
    public let lowComparableValue: PrismetPaiGowComparableValue
    public let highComparableValue: PrismetPaiGowComparableValue
}

public enum PrismetPaiGowSplitLabPhase: String, Codable, Hashable, Sendable { case dealt, splitSelected }

public enum PrismetPaiGowSplitLabError: Error, Codable, Equatable, Sendable {
    case invalidLowCardCount(Int)
    case duplicateLowCardIndex(Int)
    case invalidLowCardIndex(Int)
    case invalidHighCardCount(Int)
    case duplicateCards
    case highHandDoesNotOutrankLowHand
}

public enum PrismetPaiGowSplitLabStateValidationError: Error, Codable, Equatable, Sendable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case shuffledDeckMismatch
    case invalidCards
    case invalidLowCardIndices
    case invalidPhase
    case invalidAnalysis
}

public struct PrismetPaiGowSplitLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let seed: UInt64
    public let cards: [PrismetPaiGowCard]
    public let phase: PrismetPaiGowSplitLabPhase
    public let lowCardIndices: [Int]?
    public let analysis: PrismetPaiGowSplitAnalysis?
    private let shuffledDeck: [PrismetPaiGowCard]

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, randomizerVersion, seed, cards, phase, lowCardIndices, analysis, shuffledDeck
    }

    private init(seed: UInt64, shuffledDeck: [PrismetPaiGowCard], lowCardIndices: [Int]? = nil, analysis: PrismetPaiGowSplitAnalysis? = nil) {
        self.rulesVersion = Self.rulesVersion
        self.randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        self.seed = seed
        self.cards = Array(shuffledDeck.prefix(7))
        self.phase = lowCardIndices == nil ? .dealt : .splitSelected
        self.lowCardIndices = lowCardIndices
        self.analysis = analysis
        self.shuffledDeck = shuffledDeck
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        let cards = try container.decode([PrismetPaiGowCard].self, forKey: .cards)
        let phase = try container.decode(PrismetPaiGowSplitLabPhase.self, forKey: .phase)
        let lowCardIndices = try container.decodeIfPresent([Int].self, forKey: .lowCardIndices)
        let analysis = try container.decodeIfPresent(PrismetPaiGowSplitAnalysis.self, forKey: .analysis)
        let shuffledDeck = try container.decode([PrismetPaiGowCard].self, forKey: .shuffledDeck)

        try Self.validate(rulesVersion: rulesVersion, randomizerVersion: randomizerVersion, seed: seed, cards: cards, phase: phase, lowCardIndices: lowCardIndices, analysis: analysis, shuffledDeck: shuffledDeck)
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.seed = seed
        self.cards = cards
        self.phase = phase
        self.lowCardIndices = lowCardIndices
        self.analysis = analysis
        self.shuffledDeck = shuffledDeck
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(cards, forKey: .cards)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(lowCardIndices, forKey: .lowCardIndices)
        try container.encodeIfPresent(analysis, forKey: .analysis)
        try container.encode(shuffledDeck, forKey: .shuffledDeck)
    }

    fileprivate static func dealt(seed: UInt64) throws -> Self {
        try Self(seed: seed, shuffledDeck: canonicalDeck(seed: seed))
    }

    fileprivate func selecting(lowCardIndices: [Int], analysis: PrismetPaiGowSplitAnalysis) -> Self {
        Self(seed: seed, shuffledDeck: shuffledDeck, lowCardIndices: lowCardIndices, analysis: analysis)
    }

    private static func canonicalDeck(seed: UInt64) throws -> [PrismetPaiGowCard] {
        var deck = PrismetDeckFactory.standard52().map(PrismetPaiGowCard.standard) + [.joker]
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }

    private static func validate(rulesVersion: Int, randomizerVersion: Int, seed: UInt64, cards: [PrismetPaiGowCard], phase: PrismetPaiGowSplitLabPhase, lowCardIndices: [Int]?, analysis: PrismetPaiGowSplitAnalysis?, shuffledDeck: [PrismetPaiGowCard]) throws {
        guard rulesVersion == Self.rulesVersion else { throw PrismetPaiGowSplitLabStateValidationError.unsupportedRulesVersion(rulesVersion) }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else { throw PrismetPaiGowSplitLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion) }
        guard shuffledDeck == (try canonicalDeck(seed: seed)) else { throw PrismetPaiGowSplitLabStateValidationError.shuffledDeckMismatch }
        guard cards == Array(shuffledDeck.prefix(7)) else { throw PrismetPaiGowSplitLabStateValidationError.invalidCards }
        switch phase {
        case .dealt:
            guard lowCardIndices == nil, analysis == nil else { throw PrismetPaiGowSplitLabStateValidationError.invalidPhase }
        case .splitSelected:
            guard let lowCardIndices, let analysis else { throw PrismetPaiGowSplitLabStateValidationError.invalidPhase }
            let expected: PrismetPaiGowSplitAnalysis
            do { expected = try PrismetPaiGowSplitLab.analyze(cards: cards, lowCardIndices: lowCardIndices) }
            catch { throw PrismetPaiGowSplitLabStateValidationError.invalidLowCardIndices }
            guard analysis == expected else { throw PrismetPaiGowSplitLabStateValidationError.invalidAnalysis }
        }
    }
}

public enum PrismetPaiGowSplitLab {
    public static let totalUnorderedDealCount = 154_143_080 // C(53, 7)
    public static let possibleLowAllocationCount = 21 // C(7, 2)
    public static let uniqueDeck: [PrismetPaiGowCard] = PrismetDeckFactory.standard52().map(PrismetPaiGowCard.standard) + [.joker]

    public static func dealSeven(seed: UInt64) throws -> PrismetPaiGowSplitLabState { try .dealt(seed: seed) }

    public static func selectLowCards(at indices: [Int], in state: PrismetPaiGowSplitLabState) throws -> PrismetPaiGowSplitLabState {
        let analysis = try analyze(cards: state.cards, lowCardIndices: indices)
        return state.selecting(lowCardIndices: indices.sorted(), analysis: analysis)
    }

    public static func changingSplit(to indices: [Int], in state: PrismetPaiGowSplitLabState) throws -> PrismetPaiGowSplitLabState {
        try selectLowCards(at: indices, in: state)
    }

    public static func analyze(cards: [PrismetPaiGowCard], lowCardIndices: [Int]) throws -> PrismetPaiGowSplitAnalysis {
        guard cards.count == 7 else { throw PrismetPaiGowSplitLabError.invalidHighCardCount(cards.count - 2) }
        guard Set(cards).count == cards.count else { throw PrismetPaiGowSplitLabError.duplicateCards }
        let sortedIndices = try validatedLowIndices(lowCardIndices)
        let lowCards = sortedIndices.map { cards[$0] }
        let highCards = cards.enumerated().compactMap { sortedIndices.contains($0.offset) ? nil : $0.element }
        let lowHand = try evaluateLowHand(lowCards)
        let highHand = try evaluateHighHand(highCards)
        let lowComparableValue = comparableValue(for: lowHand)
        let highComparableValue = comparableValue(for: highHand)
        guard highComparableValue > lowComparableValue else { throw PrismetPaiGowSplitLabError.highHandDoesNotOutrankLowHand }
        return PrismetPaiGowSplitAnalysis(lowCardIndices: sortedIndices, lowCards: lowCards, highCards: highCards, lowHand: lowHand, highHand: highHand, lowComparableValue: lowComparableValue, highComparableValue: highComparableValue)
    }

    public static func evaluateLowHand(_ cards: [PrismetPaiGowCard]) throws -> PrismetPaiGowLowHandValue {
        guard cards.count == 2 else { throw PrismetPaiGowSplitLabError.invalidLowCardCount(cards.count) }
        guard Set(cards).count == cards.count else { throw PrismetPaiGowSplitLabError.duplicateCards }
        let ranks = cards.map { card -> Int in
            if case .joker = card { return PrismetCardRank.ace.rawValue }
            if case let .standard(card) = card { return card.rank.rawValue }
            return PrismetCardRank.ace.rawValue
        }.sorted(by: >)
        if ranks[0] == ranks[1] { return PrismetPaiGowLowHandValue(category: .pair, tieBreakRanks: [ranks[0]]) }
        return PrismetPaiGowLowHandValue(category: .highCard, tieBreakRanks: ranks)
    }

    public static func evaluateHighHand(_ cards: [PrismetPaiGowCard]) throws -> PrismetPaiGowHighHandValue {
        guard cards.count == 5 else { throw PrismetPaiGowSplitLabError.invalidHighCardCount(cards.count) }
        guard Set(cards).count == cards.count else { throw PrismetPaiGowSplitLabError.duplicateCards }
        let standard = cards.compactMap { if case let .standard(card) = $0 { return card }; return nil }
        guard cards.count - standard.count <= 1 else { throw PrismetPaiGowSplitLabError.duplicateCards }
        guard cards.contains(.joker) else { return try value(cards: standard, substitution: nil) }

        var candidates: [PrismetPaiGowHighHandValue] = []
        candidates.append(try value(cards: standard, substitution: .ace))
        for suit in PrismetCardSuit.allCases {
            for rank in PrismetCardRank.allCases {
                let candidate = PrismetPlayingCard(rank: rank, suit: suit)
                // The joker can stand in for a qualifying card, but it must remain
                // virtual: it cannot copy a natural card already in this hand.
                guard !standard.contains(candidate) else { continue }
                let augmented = standard + [candidate]
                let straight = straightHighRank(augmented.map { $0.rank.rawValue }) != nil
                let flush = Set(augmented.map(\.suit)).count == 1
                guard straight || flush else { continue }
                let substitution: PrismetPaiGowJokerSubstitution
                if straight && flush { substitution = .straightFlush(suit: suit, rank: rank) }
                else if straight { substitution = .straight(rank: rank) }
                else { substitution = .flush(suit: suit, rank: rank) }
                candidates.append(try value(cards: augmented, substitution: substitution))
            }
        }
        if let best = candidates.max() { return best }
        return try value(cards: standard, substitution: .ace)
    }

    public static func comparableValue(for value: PrismetPaiGowHighHandValue) -> PrismetPaiGowComparableValue {
        PrismetPaiGowComparableValue(categoryTier: value.category.rawValue, tieBreakRanks: value.tieBreakRanks)
    }

    public static func comparableValue(for value: PrismetPaiGowLowHandValue) -> PrismetPaiGowComparableValue {
        PrismetPaiGowComparableValue(categoryTier: value.category.rawValue, tieBreakRanks: value.tieBreakRanks)
    }

    private static func validatedLowIndices(_ indices: [Int]) throws -> [Int] {
        guard indices.count == 2 else { throw PrismetPaiGowSplitLabError.invalidLowCardCount(indices.count) }
        for index in indices where !(0..<7).contains(index) { throw PrismetPaiGowSplitLabError.invalidLowCardIndex(index) }
        let sorted = indices.sorted()
        guard sorted[0] != sorted[1] else { throw PrismetPaiGowSplitLabError.duplicateLowCardIndex(sorted[0]) }
        return sorted
    }

    private static func value(cards: [PrismetPlayingCard], substitution: PrismetPaiGowJokerSubstitution?) throws -> PrismetPaiGowHighHandValue {
        let ranks = cards.map { $0.rank.rawValue }
        let evaluatedRanks = substitution == .ace ? ranks + [PrismetCardRank.ace.rawValue] : ranks
        let grouped = Dictionary(grouping: evaluatedRanks, by: { $0 }).mapValues(\.count)
        let groups = grouped.map { (rank: $0.key, count: $0.value) }
        let sortedRanks = evaluatedRanks.sorted(by: >)
        let straightHigh = straightHighRank(evaluatedRanks)
        let isFlush = cards.count == 5 && Set(cards.map(\.suit)).count == 1
        let isFiveAces = substitution == .ace && evaluatedRanks.count == 5 && evaluatedRanks.allSatisfy { $0 == PrismetCardRank.ace.rawValue }

        if isFiveAces { return PrismetPaiGowHighHandValue(category: .fiveAces, tieBreakRanks: [14], jokerSubstitution: substitution) }
        if let straightHigh, isFlush { return PrismetPaiGowHighHandValue(category: Set(ranks) == Set(10...14) ? .royalFlush : .straightFlush, tieBreakRanks: [straightHigh], jokerSubstitution: substitution) }
        if let four = groups.first(where: { $0.count == 4 }) { return PrismetPaiGowHighHandValue(category: .fourOfAKind, tieBreakRanks: [four.rank] + groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >), jokerSubstitution: substitution) }
        if let trips = groups.first(where: { $0.count == 3 }), let pair = groups.first(where: { $0.count == 2 }) { return PrismetPaiGowHighHandValue(category: .fullHouse, tieBreakRanks: [trips.rank, pair.rank], jokerSubstitution: substitution) }
        if isFlush { return PrismetPaiGowHighHandValue(category: .flush, tieBreakRanks: sortedRanks, jokerSubstitution: substitution) }
        if let straightHigh { return PrismetPaiGowHighHandValue(category: .straight, tieBreakRanks: [straightHigh], jokerSubstitution: substitution) }
        if let trips = groups.first(where: { $0.count == 3 }) { return PrismetPaiGowHighHandValue(category: .threeOfAKind, tieBreakRanks: [trips.rank] + groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >), jokerSubstitution: substitution) }
        let pairs = groups.filter { $0.count == 2 }.map(\.rank).sorted(by: >)
        if pairs.count == 2 { return PrismetPaiGowHighHandValue(category: .twoPair, tieBreakRanks: pairs + groups.filter { $0.count == 1 }.map(\.rank), jokerSubstitution: substitution) }
        if let pair = pairs.first { return PrismetPaiGowHighHandValue(category: .onePair, tieBreakRanks: [pair] + groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >), jokerSubstitution: substitution) }
        return PrismetPaiGowHighHandValue(category: .highCard, tieBreakRanks: sortedRanks, jokerSubstitution: substitution)
    }

    private static func straightHighRank(_ ranks: [Int]) -> Int? {
        let unique = Set(ranks)
        guard unique.count == 5 else { return nil }
        if unique == Set([2, 3, 4, 5, 14]) { return 5 }
        guard let low = unique.min(), let high = unique.max(), high - low == 4 else { return nil }
        return high
    }
}
