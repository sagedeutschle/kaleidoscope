public enum PrismetCaribbeanStudQualification: String, Codable, Hashable, Sendable {
    case pairOrBetter
    case aceKingHigh
    case doesNotQualify

    public static func evaluate(_ cards: [PrismetPlayingCard]) throws -> Self {
        let value = try PrismetPokerHandValue(cards: cards)
        if value.category >= .onePair { return .pairOrBetter }
        return value.tieBreakRanks.starts(with: [14, 13]) ? .aceKingHigh : .doesNotQualify
    }
}

public enum PrismetCaribbeanStudLabPhase: String, Codable, Hashable, Sendable { case dealt, revealed }
public enum PrismetCaribbeanStudLabError: Error, Equatable { case invalidPhase(PrismetCaribbeanStudLabPhase) }

public enum PrismetCaribbeanStudLabStateValidationError: Error, Equatable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case shuffledDeckMismatch
    case invalidCursor(expected: Int, actual: Int)
    case invalidReferenceFaceUpCount(expected: Int, actual: Int)
    case invalidLearnerCards
    case invalidReferenceCards
    case invalidComparison
    case invalidQualification
}

public struct PrismetCaribbeanStudLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let seed: UInt64
    public let learnerCards: [PrismetPlayingCard]
    public let phase: PrismetCaribbeanStudLabPhase
    public let comparison: PrismetPokerComparison?
    public let referenceQualification: PrismetCaribbeanStudQualification?
    public let referenceCards: [PrismetLabVisibleCard]
    private let shuffledDeck: [PrismetPlayingCard]
    private let dealtReferenceCards: [PrismetPlayingCard]
    private let cursor: Int
    private let referenceFaceUpCount: Int

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, randomizerVersion, seed, learnerCards, phase, comparison, referenceQualification, shuffledDeck, dealtReferenceCards, cursor, referenceFaceUpCount
    }

    private init(seed: UInt64, shuffledDeck: [PrismetPlayingCard], phase: PrismetCaribbeanStudLabPhase, comparison: PrismetPokerComparison?, referenceQualification: PrismetCaribbeanStudQualification?, referenceFaceUpCount: Int) {
        self.rulesVersion = Self.rulesVersion
        self.randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        self.seed = seed
        self.learnerCards = Array(shuffledDeck.prefix(5))
        self.dealtReferenceCards = Array(shuffledDeck[5..<10])
        self.phase = phase
        self.comparison = comparison
        self.referenceQualification = referenceQualification
        self.shuffledDeck = shuffledDeck
        self.cursor = 10
        self.referenceFaceUpCount = referenceFaceUpCount
        self.referenceCards = Self.visibleCards(dealtReferenceCards: self.dealtReferenceCards, count: referenceFaceUpCount)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        let learnerCards = try container.decode([PrismetPlayingCard].self, forKey: .learnerCards)
        let phase = try container.decode(PrismetCaribbeanStudLabPhase.self, forKey: .phase)
        let comparison = try container.decodeIfPresent(PrismetPokerComparison.self, forKey: .comparison)
        let referenceQualification = try container.decodeIfPresent(PrismetCaribbeanStudQualification.self, forKey: .referenceQualification)
        let shuffledDeck = try container.decode([PrismetPlayingCard].self, forKey: .shuffledDeck)
        let dealtReferenceCards = try container.decode([PrismetPlayingCard].self, forKey: .dealtReferenceCards)
        let cursor = try container.decode(Int.self, forKey: .cursor)
        let referenceFaceUpCount = try container.decode(Int.self, forKey: .referenceFaceUpCount)
        try Self.validate(rulesVersion: rulesVersion, randomizerVersion: randomizerVersion, seed: seed, learnerCards: learnerCards, phase: phase, comparison: comparison, referenceQualification: referenceQualification, shuffledDeck: shuffledDeck, dealtReferenceCards: dealtReferenceCards, cursor: cursor, referenceFaceUpCount: referenceFaceUpCount)
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.seed = seed
        self.learnerCards = learnerCards
        self.phase = phase
        self.comparison = comparison
        self.referenceQualification = referenceQualification
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
        try container.encodeIfPresent(referenceQualification, forKey: .referenceQualification)
        try container.encode(shuffledDeck, forKey: .shuffledDeck)
        try container.encode(dealtReferenceCards, forKey: .dealtReferenceCards)
        try container.encode(cursor, forKey: .cursor)
        try container.encode(referenceFaceUpCount, forKey: .referenceFaceUpCount)
    }

    fileprivate static func dealt(seed: UInt64, shuffledDeck: [PrismetPlayingCard]) -> Self { Self(seed: seed, shuffledDeck: shuffledDeck, phase: .dealt, comparison: nil, referenceQualification: nil, referenceFaceUpCount: 1) }

    fileprivate func revealing() throws -> Self {
        let learner = try PrismetPokerHandValue(cards: learnerCards)
        let reference = try PrismetPokerHandValue(cards: dealtReferenceCards)
        return Self(seed: seed, shuffledDeck: shuffledDeck, phase: .revealed, comparison: PrismetPokerComparison.compare(learner: learner, reference: reference), referenceQualification: try PrismetCaribbeanStudQualification.evaluate(dealtReferenceCards), referenceFaceUpCount: 5)
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

    private static func validate(rulesVersion: Int, randomizerVersion: Int, seed: UInt64, learnerCards: [PrismetPlayingCard], phase: PrismetCaribbeanStudLabPhase, comparison: PrismetPokerComparison?, referenceQualification: PrismetCaribbeanStudQualification?, shuffledDeck: [PrismetPlayingCard], dealtReferenceCards: [PrismetPlayingCard], cursor: Int, referenceFaceUpCount: Int) throws {
        guard rulesVersion == Self.rulesVersion else { throw PrismetCaribbeanStudLabStateValidationError.unsupportedRulesVersion(rulesVersion) }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else { throw PrismetCaribbeanStudLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion) }
        guard shuffledDeck == (try canonicalDeck(seed: seed)) else { throw PrismetCaribbeanStudLabStateValidationError.shuffledDeckMismatch }
        guard cursor == 10 else { throw PrismetCaribbeanStudLabStateValidationError.invalidCursor(expected: 10, actual: cursor) }
        guard learnerCards == Array(shuffledDeck.prefix(5)) else { throw PrismetCaribbeanStudLabStateValidationError.invalidLearnerCards }
        guard dealtReferenceCards == Array(shuffledDeck[5..<10]) else { throw PrismetCaribbeanStudLabStateValidationError.invalidReferenceCards }
        let expectedFaceUp = phase == .dealt ? 1 : 5
        guard referenceFaceUpCount == expectedFaceUp else { throw PrismetCaribbeanStudLabStateValidationError.invalidReferenceFaceUpCount(expected: expectedFaceUp, actual: referenceFaceUpCount) }
        if phase == .dealt {
            guard comparison == nil else { throw PrismetCaribbeanStudLabStateValidationError.invalidComparison }
            guard referenceQualification == nil else { throw PrismetCaribbeanStudLabStateValidationError.invalidQualification }
        } else {
            let learner = try PrismetPokerHandValue(cards: learnerCards)
            let reference = try PrismetPokerHandValue(cards: dealtReferenceCards)
            guard comparison == PrismetPokerComparison.compare(learner: learner, reference: reference) else { throw PrismetCaribbeanStudLabStateValidationError.invalidComparison }
            guard referenceQualification == (try PrismetCaribbeanStudQualification.evaluate(dealtReferenceCards)) else { throw PrismetCaribbeanStudLabStateValidationError.invalidQualification }
        }
    }
}

public enum PrismetCaribbeanStudLab {
    public static let exactLabeledDealCount = 3_986_646_103_440

    public static func deal(seed: UInt64) throws -> PrismetCaribbeanStudLabState {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return .dealt(seed: seed, shuffledDeck: deck)
    }

    public static func revealComparison(in state: PrismetCaribbeanStudLabState) throws -> PrismetCaribbeanStudLabState {
        guard state.phase == .dealt else { throw PrismetCaribbeanStudLabError.invalidPhase(state.phase) }
        return try state.revealing()
    }
}
