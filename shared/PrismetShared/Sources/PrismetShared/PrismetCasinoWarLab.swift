import Foundation

public enum PrismetCasinoWarLabPhase: String, Codable, Hashable, Sendable {
    case dealt
    case warReady
    case complete
}

public enum PrismetCasinoWarOutcome: String, Codable, Hashable, Sendable {
    case learnerHigher
    case referenceHigher
    case neutral
}

public enum PrismetCasinoWarAuditAction: String, Codable, Hashable, Sendable {
    case dealt
    case revealWar
}

public struct PrismetCasinoWarAuditEvent: Codable, Hashable, Sendable {
    public let action: PrismetCasinoWarAuditAction
    public let seed: UInt64
    public let randomizerVersion: Int

    public init(action: PrismetCasinoWarAuditAction, seed: UInt64, randomizerVersion: Int = PrismetDeterministicRandom.algorithmVersion) {
        self.action = action
        self.seed = seed
        self.randomizerVersion = randomizerVersion
    }

    public static func dealt(seed: UInt64) -> Self {
        Self(action: .dealt, seed: seed)
    }

    public static func revealWar(seed: UInt64) -> Self {
        Self(action: .revealWar, seed: seed)
    }
}

public enum PrismetCasinoWarLabError: Error, Equatable, Sendable {
    case invalidPhase(PrismetCasinoWarLabPhase)
}

public enum PrismetCasinoWarLabStateValidationError: Error, Equatable, Sendable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case shuffledDeckMismatch
    case invalidDeck
    case invalidCursor(expected: Int, actual: Int)
    case invalidLearnerCard
    case invalidReferenceCard
    case invalidPhase
    case invalidOutcome
    case invalidWarCards
    case invalidAuditHistory
}

public struct PrismetCasinoWarLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let seed: UInt64
    public let learnerCard: PrismetPlayingCard
    public let referenceCard: PrismetPlayingCard
    public let phase: PrismetCasinoWarLabPhase
    public let outcome: PrismetCasinoWarOutcome?
    public let learnerWarCards: [PrismetLabVisibleCard]
    public let referenceWarCards: [PrismetLabVisibleCard]
    public let auditHistory: [PrismetCasinoWarAuditEvent]

    public var cardsConsumed: Int { cursor }

    private let shuffledDeck: [PrismetPlayingCard]
    private let cursor: Int
    private let dealtWarCards: [PrismetPlayingCard]

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, randomizerVersion, seed, learnerCard, referenceCard, phase, outcome
        case learnerWarCards, referenceWarCards, auditHistory, shuffledDeck, cursor, dealtWarCards
    }

    private init(seed: UInt64, shuffledDeck: [PrismetPlayingCard], phase: PrismetCasinoWarLabPhase, outcome: PrismetCasinoWarOutcome?, warFaceUp: Bool, auditHistory: [PrismetCasinoWarAuditEvent]) {
        self.rulesVersion = Self.rulesVersion
        self.randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        self.seed = seed
        self.shuffledDeck = shuffledDeck
        self.learnerCard = shuffledDeck[0]
        self.referenceCard = shuffledDeck[1]
        self.phase = phase
        self.outcome = outcome
        self.dealtWarCards = Array(shuffledDeck[2..<10])
        self.cursor = warFaceUp ? 10 : 2
        self.learnerWarCards = Self.visibleWarCards(dealtWarCards: self.dealtWarCards, faceUp: warFaceUp, isLearner: true)
        self.referenceWarCards = Self.visibleWarCards(dealtWarCards: self.dealtWarCards, faceUp: warFaceUp, isLearner: false)
        self.auditHistory = auditHistory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        let learnerCard = try container.decode(PrismetPlayingCard.self, forKey: .learnerCard)
        let referenceCard = try container.decode(PrismetPlayingCard.self, forKey: .referenceCard)
        let phase = try container.decode(PrismetCasinoWarLabPhase.self, forKey: .phase)
        let outcome = try container.decodeIfPresent(PrismetCasinoWarOutcome.self, forKey: .outcome)
        let learnerWarCards = try container.decode([PrismetLabVisibleCard].self, forKey: .learnerWarCards)
        let referenceWarCards = try container.decode([PrismetLabVisibleCard].self, forKey: .referenceWarCards)
        let auditHistory = try container.decode([PrismetCasinoWarAuditEvent].self, forKey: .auditHistory)
        let shuffledDeck = try container.decode([PrismetPlayingCard].self, forKey: .shuffledDeck)
        let cursor = try container.decode(Int.self, forKey: .cursor)
        let dealtWarCards = try container.decode([PrismetPlayingCard].self, forKey: .dealtWarCards)
        try Self.validate(rulesVersion: rulesVersion, randomizerVersion: randomizerVersion, seed: seed, learnerCard: learnerCard, referenceCard: referenceCard, phase: phase, outcome: outcome, learnerWarCards: learnerWarCards, referenceWarCards: referenceWarCards, auditHistory: auditHistory, shuffledDeck: shuffledDeck, cursor: cursor, dealtWarCards: dealtWarCards)
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.seed = seed
        self.learnerCard = learnerCard
        self.referenceCard = referenceCard
        self.phase = phase
        self.outcome = outcome
        self.learnerWarCards = learnerWarCards
        self.referenceWarCards = referenceWarCards
        self.auditHistory = auditHistory
        self.shuffledDeck = shuffledDeck
        self.cursor = cursor
        self.dealtWarCards = dealtWarCards
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(learnerCard, forKey: .learnerCard)
        try container.encode(referenceCard, forKey: .referenceCard)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encode(learnerWarCards, forKey: .learnerWarCards)
        try container.encode(referenceWarCards, forKey: .referenceWarCards)
        try container.encode(auditHistory, forKey: .auditHistory)
        try container.encode(shuffledDeck, forKey: .shuffledDeck)
        try container.encode(cursor, forKey: .cursor)
        try container.encode(dealtWarCards, forKey: .dealtWarCards)
    }

    fileprivate static func dealt(seed: UInt64, shuffledDeck: [PrismetPlayingCard]) -> Self {
        let first = shuffledDeck[0].rank.rawValue
        let second = shuffledDeck[1].rank.rawValue
        let phase: PrismetCasinoWarLabPhase = first == second ? .warReady : .complete
        let outcome: PrismetCasinoWarOutcome? = first == second ? nil : first > second ? .learnerHigher : .referenceHigher
        return Self(seed: seed, shuffledDeck: shuffledDeck, phase: phase, outcome: outcome, warFaceUp: false, auditHistory: [.dealt(seed: seed)])
    }

    fileprivate func revealingWar() -> Self {
        let learnerRank = dealtWarCards[6].rank.rawValue
        let referenceRank = dealtWarCards[7].rank.rawValue
        let outcome: PrismetCasinoWarOutcome = learnerRank > referenceRank ? .learnerHigher : learnerRank < referenceRank ? .referenceHigher : .neutral
        return Self(seed: seed, shuffledDeck: shuffledDeck, phase: .complete, outcome: outcome, warFaceUp: true, auditHistory: auditHistory + [.revealWar(seed: seed)])
    }

    private static func visibleWarCards(dealtWarCards: [PrismetPlayingCard], faceUp: Bool, isLearner: Bool) -> [PrismetLabVisibleCard] {
        guard faceUp else { return Array(repeating: .hidden, count: 4) }
        let faceUpCard = dealtWarCards[isLearner ? 6 : 7]
        return [PrismetLabVisibleCard.hidden, .hidden, .hidden, PrismetLabVisibleCard(card: faceUpCard)]
    }

    private static func validate(rulesVersion: Int, randomizerVersion: Int, seed: UInt64, learnerCard: PrismetPlayingCard, referenceCard: PrismetPlayingCard, phase: PrismetCasinoWarLabPhase, outcome: PrismetCasinoWarOutcome?, learnerWarCards: [PrismetLabVisibleCard], referenceWarCards: [PrismetLabVisibleCard], auditHistory: [PrismetCasinoWarAuditEvent], shuffledDeck: [PrismetPlayingCard], cursor: Int, dealtWarCards: [PrismetPlayingCard]) throws {
        guard rulesVersion == Self.rulesVersion else { throw PrismetCasinoWarLabStateValidationError.unsupportedRulesVersion(rulesVersion) }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else { throw PrismetCasinoWarLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion) }
        guard shuffledDeck.count == 52, Set(shuffledDeck).count == 52 else { throw PrismetCasinoWarLabStateValidationError.invalidDeck }
        guard shuffledDeck == (try canonicalDeck(seed: seed)) else { throw PrismetCasinoWarLabStateValidationError.shuffledDeckMismatch }
        guard learnerCard == shuffledDeck[0] else { throw PrismetCasinoWarLabStateValidationError.invalidLearnerCard }
        guard referenceCard == shuffledDeck[1] else { throw PrismetCasinoWarLabStateValidationError.invalidReferenceCard }
        guard dealtWarCards == Array(shuffledDeck[2..<10]) else { throw PrismetCasinoWarLabStateValidationError.invalidWarCards }
        let tied = learnerCard.rank == referenceCard.rank
        guard tied || auditHistory.count == 1 else { throw PrismetCasinoWarLabStateValidationError.invalidAuditHistory }
        let expectedPhase: PrismetCasinoWarLabPhase = tied ? (auditHistory.count == 2 ? .complete : .warReady) : .complete
        guard phase == expectedPhase else { throw PrismetCasinoWarLabStateValidationError.invalidPhase }
        let expectedCursor = auditHistory.count == 2 ? 10 : 2
        guard cursor == expectedCursor else { throw PrismetCasinoWarLabStateValidationError.invalidCursor(expected: expectedCursor, actual: cursor) }
        guard auditHistory == (auditHistory.count == 1 ? [.dealt(seed: seed)] : [.dealt(seed: seed), .revealWar(seed: seed)]) else { throw PrismetCasinoWarLabStateValidationError.invalidAuditHistory }
        guard learnerWarCards.count == 4, referenceWarCards.count == 4 else { throw PrismetCasinoWarLabStateValidationError.invalidWarCards }
        let warVisible = auditHistory.count == 2
        guard learnerWarCards == visibleWarCards(dealtWarCards: dealtWarCards, faceUp: warVisible, isLearner: true), referenceWarCards == visibleWarCards(dealtWarCards: dealtWarCards, faceUp: warVisible, isLearner: false) else { throw PrismetCasinoWarLabStateValidationError.invalidWarCards }
        let expectedOutcome: PrismetCasinoWarOutcome? = if !tied { learnerCard.rank.rawValue > referenceCard.rank.rawValue ? .learnerHigher : .referenceHigher } else if warVisible { dealtWarCards[6].rank.rawValue > dealtWarCards[7].rank.rawValue ? .learnerHigher : dealtWarCards[6].rank.rawValue < dealtWarCards[7].rank.rawValue ? .referenceHigher : .neutral } else { nil }
        guard outcome == expectedOutcome else { throw PrismetCasinoWarLabStateValidationError.invalidOutcome }
    }

    private static func canonicalDeck(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }
}

public enum PrismetCasinoWarLab {
    public static let exactOutcomeSampleCount = 20_825
    public static let exactOutcomeCounts: [PrismetCasinoWarOutcome: Int] = [.learnerHigher: 10_376, .referenceHigher: 10_376, .neutral: 73]

    public static func deal(seed: UInt64) throws -> PrismetCasinoWarLabState {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return .dealt(seed: seed, shuffledDeck: deck)
    }

    public static func revealWar(in state: PrismetCasinoWarLabState) throws -> PrismetCasinoWarLabState {
        guard state.phase == .warReady, state.learnerCard.rank == state.referenceCard.rank else { throw PrismetCasinoWarLabError.invalidPhase(state.phase) }
        return state.revealingWar()
    }
}
