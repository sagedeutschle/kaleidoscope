import Foundation

public struct PrismetBaccaratShoeCard: Codable, Hashable, Identifiable, Sendable {
    public let deckIndex: Int
    public let card: PrismetPlayingCard

    public init(deckIndex: Int, card: PrismetPlayingCard) {
        self.deckIndex = deckIndex
        self.card = card
    }

    public var id: String { "deck-\(deckIndex)-\(card.id)" }

    public var value: Int {
        switch card.rank {
        case .ace: return 1
        case .two, .three, .four, .five, .six, .seven, .eight, .nine: return card.rank.rawValue
        case .ten, .jack, .queen, .king: return 0
        }
    }
}

public enum PrismetMiniBaccaratPhase: String, Codable, Hashable, Sendable {
    case ready, initialDeal, playerTableau, bankerTableau, complete
}

public enum PrismetMiniBaccaratOutcome: String, CaseIterable, Codable, Hashable, Sendable {
    case player, banker, tie
}

public struct PrismetMiniBaccaratOutcomeCount: Codable, Hashable, Sendable {
    public let outcome: PrismetMiniBaccaratOutcome
    public let count: Int

    public init(outcome: PrismetMiniBaccaratOutcome, count: Int) {
        self.outcome = outcome
        self.count = count
    }
}

public enum PrismetMiniBaccaratLabStateValidationError: Error, Equatable {
    case invalidReadyState
    case missingSeed
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case invalidShoeComposition
    case shuffledShoeMismatch
    case invalidPhaseForDealHistory(PrismetMiniBaccaratPhase)
    case invalidShoeCursor(expected: Int, actual: Int)
    case cardsDoNotMatchDealHistory
    case invalidOutcome(expected: PrismetMiniBaccaratOutcome?, actual: PrismetMiniBaccaratOutcome?)
}

public struct PrismetMiniBaccaratLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let seed: UInt64?
    public let rulesVersion: Int
    public let randomizerVersion: Int?
    public let phase: PrismetMiniBaccaratPhase
    public let playerCards: [PrismetBaccaratShoeCard]
    public let bankerCards: [PrismetBaccaratShoeCard]
    public let outcome: PrismetMiniBaccaratOutcome?
    fileprivate let shuffledShoe: [PrismetBaccaratShoeCard]
    fileprivate let shoeCursor: Int

    public static let ready = PrismetMiniBaccaratLabState(
        seed: nil,
        rulesVersion: PrismetMiniBaccaratLabState.rulesVersion,
        randomizerVersion: nil,
        phase: .ready,
        playerCards: [],
        bankerCards: [],
        outcome: nil,
        shuffledShoe: [],
        shoeCursor: 0
    )

    public var playerTotal: Int { Self.total(of: playerCards) }
    public var bankerTotal: Int { Self.total(of: bankerCards) }
    public var cardsDealt: [PrismetBaccaratShoeCard] { playerCards + bankerCards }
    public var shoeCardCount: Int { shuffledShoe.count }
    public var remainingShoeCardCount: Int { shuffledShoe.count - shoeCursor }

    private enum CodingKeys: String, CodingKey {
        case seed
        case rulesVersion
        case randomizerVersion
        case phase
        case playerCards
        case bankerCards
        case outcome
        case shuffledShoe
        case shoeCursor
    }

    fileprivate init(
        seed: UInt64?,
        rulesVersion: Int,
        randomizerVersion: Int?,
        phase: PrismetMiniBaccaratPhase,
        playerCards: [PrismetBaccaratShoeCard],
        bankerCards: [PrismetBaccaratShoeCard],
        outcome: PrismetMiniBaccaratOutcome?,
        shuffledShoe: [PrismetBaccaratShoeCard],
        shoeCursor: Int
    ) {
        self.seed = seed
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.phase = phase
        self.playerCards = playerCards
        self.bankerCards = bankerCards
        self.outcome = outcome
        self.shuffledShoe = shuffledShoe
        self.shoeCursor = shoeCursor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        let rulesVersion = try container.decodeIfPresent(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decodeIfPresent(Int.self, forKey: .randomizerVersion)
        let phase = try container.decode(PrismetMiniBaccaratPhase.self, forKey: .phase)
        let playerCards = try container.decode([PrismetBaccaratShoeCard].self, forKey: .playerCards)
        let bankerCards = try container.decode([PrismetBaccaratShoeCard].self, forKey: .bankerCards)
        let outcome = try container.decodeIfPresent(PrismetMiniBaccaratOutcome.self, forKey: .outcome)
        let shuffledShoe = try container.decode([PrismetBaccaratShoeCard].self, forKey: .shuffledShoe)
        let shoeCursor = try container.decode(Int.self, forKey: .shoeCursor)

        try Self.validate(
            seed: seed,
            rulesVersion: rulesVersion,
            randomizerVersion: randomizerVersion,
            phase: phase,
            playerCards: playerCards,
            bankerCards: bankerCards,
            outcome: outcome,
            shuffledShoe: shuffledShoe,
            shoeCursor: shoeCursor
        )
        self.init(
            seed: seed,
            rulesVersion: rulesVersion ?? -1,
            randomizerVersion: randomizerVersion,
            phase: phase,
            playerCards: playerCards,
            bankerCards: bankerCards,
            outcome: outcome,
            shuffledShoe: shuffledShoe,
            shoeCursor: shoeCursor
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encodeIfPresent(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(phase, forKey: .phase)
        try container.encode(playerCards, forKey: .playerCards)
        try container.encode(bankerCards, forKey: .bankerCards)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encode(shuffledShoe, forKey: .shuffledShoe)
        try container.encode(shoeCursor, forKey: .shoeCursor)
    }

    fileprivate static func total(of cards: [PrismetBaccaratShoeCard]) -> Int {
        cards.map(\.value).reduce(0, +) % 10
    }

    fileprivate static func validate(
        seed: UInt64?,
        rulesVersion: Int?,
        randomizerVersion: Int?,
        phase: PrismetMiniBaccaratPhase,
        playerCards: [PrismetBaccaratShoeCard],
        bankerCards: [PrismetBaccaratShoeCard],
        outcome: PrismetMiniBaccaratOutcome?,
        shuffledShoe: [PrismetBaccaratShoeCard],
        shoeCursor: Int
    ) throws {
        if phase == .ready {
            guard seed == nil,
                  rulesVersion == Self.rulesVersion,
                  randomizerVersion == nil,
                  playerCards.isEmpty,
                  bankerCards.isEmpty,
                  outcome == nil,
                  shuffledShoe.isEmpty,
                  shoeCursor == 0 else {
                throw PrismetMiniBaccaratLabStateValidationError.invalidReadyState
            }
            return
        }

        guard let seed else {
            throw PrismetMiniBaccaratLabStateValidationError.missingSeed
        }
        guard rulesVersion == Self.rulesVersion else {
            throw PrismetMiniBaccaratLabStateValidationError.unsupportedRulesVersion(rulesVersion ?? -1)
        }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetMiniBaccaratLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion ?? -1)
        }
        guard PrismetMiniBaccaratLabEngine.isValidShoeComposition(shuffledShoe) else {
            throw PrismetMiniBaccaratLabStateValidationError.invalidShoeComposition
        }
        guard shuffledShoe == (try PrismetMiniBaccaratLabEngine.freshShoe(seed: seed)) else {
            throw PrismetMiniBaccaratLabStateValidationError.shuffledShoeMismatch
        }

        let initialPlayerCards = [shuffledShoe[0], shuffledShoe[2]]
        let initialBankerCards = [shuffledShoe[1], shuffledShoe[3]]
        let isNaturalDeal = PrismetMiniBaccaratLabEngine.isNatural(
            total: Self.total(of: initialPlayerCards)
        ) || PrismetMiniBaccaratLabEngine.isNatural(
            total: Self.total(of: initialBankerCards)
        )
        guard !isNaturalDeal || (phase != .playerTableau && phase != .bankerTableau) else {
            throw PrismetMiniBaccaratLabStateValidationError.invalidPhaseForDealHistory(phase)
        }

        let expected = try PrismetMiniBaccaratLabEngine.expectedState(seed: seed, phase: phase)
        guard shoeCursor == expected.shoeCursor else {
            throw PrismetMiniBaccaratLabStateValidationError.invalidShoeCursor(
                expected: expected.shoeCursor,
                actual: shoeCursor
            )
        }
        guard playerCards == expected.playerCards, bankerCards == expected.bankerCards else {
            throw PrismetMiniBaccaratLabStateValidationError.cardsDoNotMatchDealHistory
        }
        guard outcome == expected.outcome else {
            throw PrismetMiniBaccaratLabStateValidationError.invalidOutcome(
                expected: expected.outcome,
                actual: outcome
            )
        }
    }
}

public enum PrismetMiniBaccaratLabEngineError: Error, Equatable {
    case invalidPhase(PrismetMiniBaccaratPhase)
}

public enum PrismetMiniBaccaratLabEngine {
    public static let exactOutcomeCounts: [PrismetMiniBaccaratOutcomeCount] = [
        .init(outcome: .banker, count: 2_292_252_566_437_888),
        .init(outcome: .player, count: 2_230_518_282_592_256),
        .init(outcome: .tie, count: 475_627_426_473_216),
    ]

    public static let exactOutcomeDenominator = 4_998_398_275_503_360

    public static func freshShoe(seed: UInt64) throws -> [PrismetBaccaratShoeCard] {
        var shoe = unshuffledShoe()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&shoe)
        return shoe
    }

    public static func deal(seed: UInt64) throws -> PrismetMiniBaccaratLabState {
        try expectedState(seed: seed, phase: .initialDeal)
    }

    public static func advance(
        _ state: PrismetMiniBaccaratLabState
    ) throws -> PrismetMiniBaccaratLabState {
        guard let seed = state.seed else {
            throw PrismetMiniBaccaratLabEngineError.invalidPhase(state.phase)
        }
        switch state.phase {
        case .ready, .complete:
            throw PrismetMiniBaccaratLabEngineError.invalidPhase(state.phase)
        case .initialDeal:
            let nextPhase: PrismetMiniBaccaratPhase =
                isNatural(total: state.playerTotal) || isNatural(total: state.bankerTotal)
                ? .complete : .playerTableau
            return try expectedState(seed: seed, phase: nextPhase)
        case .playerTableau:
            return try expectedState(seed: seed, phase: .bankerTableau)
        case .bankerTableau:
            return try expectedState(seed: seed, phase: .complete)
        }
    }

    public static func isNatural(total: Int) -> Bool { total == 8 || total == 9 }

    public static func playerShouldDraw(total: Int) -> Bool { (0...5).contains(total) }

    public static func bankerShouldDraw(bankerTotal: Int, playerThirdCardValue: Int?) -> Bool {
        guard (0...7).contains(bankerTotal) else { return false }
        guard let playerThirdCardValue else { return bankerTotal <= 5 }
        switch bankerTotal {
        case 0...2: return true
        case 3: return playerThirdCardValue != 8
        case 4: return (2...7).contains(playerThirdCardValue)
        case 5: return (4...7).contains(playerThirdCardValue)
        case 6: return playerThirdCardValue == 6 || playerThirdCardValue == 7
        case 7: return false
        default: return false
        }
    }

    fileprivate static func expectedState(
        seed: UInt64,
        phase: PrismetMiniBaccaratPhase
    ) throws -> PrismetMiniBaccaratLabState {
        let shoe = try freshShoe(seed: seed)
        var playerCards = [shoe[0], shoe[2]]
        var bankerCards = [shoe[1], shoe[3]]
        var shoeCursor = 4
        let initialPlayerTotal = PrismetMiniBaccaratLabState.total(of: playerCards)
        let initialBankerTotal = PrismetMiniBaccaratLabState.total(of: bankerCards)
        let natural = isNatural(total: initialPlayerTotal) || isNatural(total: initialBankerTotal)

        if phase == .playerTableau || phase == .bankerTableau || (phase == .complete && !natural) {
            if playerShouldDraw(total: initialPlayerTotal) {
                playerCards.append(shoe[shoeCursor])
                shoeCursor += 1
            }
        }
        if phase == .bankerTableau || (phase == .complete && !natural) {
            let playerThirdCardValue = playerCards.count == 3 ? playerCards[2].value : nil
            if bankerShouldDraw(bankerTotal: initialBankerTotal, playerThirdCardValue: playerThirdCardValue) {
                bankerCards.append(shoe[shoeCursor])
                shoeCursor += 1
            }
        }

        let outcome: PrismetMiniBaccaratOutcome?
        if phase == .complete {
            outcome = resolvedOutcome(playerTotal: PrismetMiniBaccaratLabState.total(of: playerCards), bankerTotal: PrismetMiniBaccaratLabState.total(of: bankerCards))
        } else {
            outcome = nil
        }

        return PrismetMiniBaccaratLabState(
            seed: seed,
            rulesVersion: PrismetMiniBaccaratLabState.rulesVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            phase: phase,
            playerCards: playerCards,
            bankerCards: bankerCards,
            outcome: outcome,
            shuffledShoe: shoe,
            shoeCursor: shoeCursor
        )
    }

    fileprivate static func isValidShoeComposition(_ shoe: [PrismetBaccaratShoeCard]) -> Bool {
        shoe.count == 416 && Set(shoe) == Set(unshuffledShoe())
    }

    private static func unshuffledShoe() -> [PrismetBaccaratShoeCard] {
        (0..<8).flatMap { deckIndex in
            PrismetDeckFactory.standard52().map { PrismetBaccaratShoeCard(deckIndex: deckIndex, card: $0) }
        }
    }

    private static func resolvedOutcome(playerTotal: Int, bankerTotal: Int) -> PrismetMiniBaccaratOutcome {
        if playerTotal == bankerTotal { return .tie }
        return playerTotal > bankerTotal ? .player : .banker
    }
}
