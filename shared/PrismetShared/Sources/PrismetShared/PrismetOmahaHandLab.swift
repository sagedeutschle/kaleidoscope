import Foundation

public enum PrismetOmahaHandLabPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case holeCards
    case flop
    case turn
    case river
    case complete
}

public struct PrismetOmahaClassification: Codable, Equatable, Hashable, Sendable {
    public let category: PrismetPokerCategory
    public let evaluatedCandidateCount: Int
    public let holeCardCount: Int
    public let boardCardCount: Int

    public init(category: PrismetPokerCategory, evaluatedCandidateCount: Int = 60) {
        self.category = category
        self.evaluatedCandidateCount = evaluatedCandidateCount
        self.holeCardCount = 2
        self.boardCardCount = 3
    }
}

public struct PrismetOmahaRedactedState: Codable, Equatable, Hashable, Sendable {
    public let phase: PrismetOmahaHandLabPhase
    public let holeCards: [PrismetPlayingCard]
    public let visibleBoard: [PrismetPlayingCard]
    public let burnedCardCount: Int
    public let classification: PrismetOmahaClassification?

    fileprivate init(_ state: PrismetOmahaHandLabState) {
        phase = state.phase
        holeCards = state.holeCards
        visibleBoard = state.visibleBoard
        burnedCardCount = state.burnedCards.count
        classification = state.classification
    }
}

public enum PrismetOmahaHandLabError: Error, Codable, Equatable, Hashable, Sendable {
    case invalidPhase(PrismetOmahaHandLabPhase)
    case invalidHoleCardCount(Int)
    case invalidBoardCardCount(Int)
    case duplicateCards
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case shuffledDeckMismatch
    case invalidDrawIndex(expected: Int, actual: Int)
    case cardsDoNotMatchDrawHistory
    case invalidClassification
}

public struct PrismetOmahaHandLabState: Codable, Equatable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let seed: UInt64
    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let holeCards: [PrismetPlayingCard]
    public let visibleBoard: [PrismetPlayingCard]
    public let burnedCards: [PrismetPlayingCard]
    public let phase: PrismetOmahaHandLabPhase
    public let classification: PrismetOmahaClassification?
    fileprivate let shuffledDeck: [PrismetPlayingCard]
    fileprivate let drawIndex: Int

    public var visibleCards: [PrismetPlayingCard] { holeCards + visibleBoard }
    public var remainingDeckCount: Int { shuffledDeck.count - drawIndex }
    public var candidateCount: Int { classification?.evaluatedCandidateCount ?? 0 }
    public var redactedState: PrismetOmahaRedactedState { PrismetOmahaRedactedState(self) }
    public var redactedDescription: String {
        "phase=\(phase.rawValue), holeCards=\(holeCards.count), board=\(visibleBoard.count), burns=\(burnedCards.count)"
    }

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, seed, randomizerVersion, holeCards, visibleBoard, burnedCards, phase, classification, shuffledDeck, drawIndex
    }

    fileprivate init(seed: UInt64, deck: [PrismetPlayingCard], phase: PrismetOmahaHandLabPhase, holeCards: [PrismetPlayingCard], visibleBoard: [PrismetPlayingCard], burnedCards: [PrismetPlayingCard], classification: PrismetOmahaClassification?, drawIndex: Int) {
        self.seed = seed
        rulesVersion = Self.rulesVersion
        randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        shuffledDeck = deck
        self.phase = phase
        self.holeCards = holeCards
        self.visibleBoard = visibleBoard
        self.burnedCards = burnedCards
        self.classification = classification
        self.drawIndex = drawIndex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try c.decode(Int.self, forKey: .rulesVersion)
        let seed = try c.decode(UInt64.self, forKey: .seed)
        let version = try c.decode(Int.self, forKey: .randomizerVersion)
        let hole = try c.decode([PrismetPlayingCard].self, forKey: .holeCards)
        let board = try c.decode([PrismetPlayingCard].self, forKey: .visibleBoard)
        let burns = try c.decode([PrismetPlayingCard].self, forKey: .burnedCards)
        let phase = try c.decode(PrismetOmahaHandLabPhase.self, forKey: .phase)
        let result = try c.decodeIfPresent(PrismetOmahaClassification.self, forKey: .classification)
        let deck = try c.decode([PrismetPlayingCard].self, forKey: .shuffledDeck)
        let cursor = try c.decode(Int.self, forKey: .drawIndex)
        try Self.validate(rulesVersion: rulesVersion, seed: seed, version: version, hole: hole, board: board, burns: burns, phase: phase, classification: result, deck: deck, cursor: cursor)
        self.rulesVersion = rulesVersion
        self.seed = seed
        self.randomizerVersion = version
        self.shuffledDeck = deck
        self.phase = phase
        self.holeCards = hole
        self.visibleBoard = board
        self.burnedCards = burns
        self.classification = result
        self.drawIndex = cursor
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rulesVersion, forKey: .rulesVersion)
        try c.encode(seed, forKey: .seed)
        try c.encode(randomizerVersion, forKey: .randomizerVersion)
        try c.encode(holeCards, forKey: .holeCards)
        try c.encode(visibleBoard, forKey: .visibleBoard)
        try c.encode(burnedCards, forKey: .burnedCards)
        try c.encode(phase, forKey: .phase)
        try c.encodeIfPresent(classification, forKey: .classification)
        try c.encode(shuffledDeck, forKey: .shuffledDeck)
        try c.encode(drawIndex, forKey: .drawIndex)
    }

    fileprivate static func validate(rulesVersion: Int, seed: UInt64, version: Int, hole: [PrismetPlayingCard], board: [PrismetPlayingCard], burns: [PrismetPlayingCard], phase: PrismetOmahaHandLabPhase, classification: PrismetOmahaClassification?, deck: [PrismetPlayingCard], cursor: Int) throws {
        guard rulesVersion == Self.rulesVersion else { throw PrismetOmahaHandLabError.unsupportedRulesVersion(rulesVersion) }
        guard version == PrismetDeterministicRandom.algorithmVersion else { throw PrismetOmahaHandLabError.unsupportedRandomizerVersion(version) }
        guard deck == (try PrismetOmahaHandLab.canonicalDeck(seed: seed)) else { throw PrismetOmahaHandLabError.shuffledDeckMismatch }
        guard hole.count == 4 else { throw PrismetOmahaHandLabError.invalidHoleCardCount(hole.count) }
        guard board.count <= 5 else { throw PrismetOmahaHandLabError.invalidBoardCardCount(board.count) }
        let all = hole + board + burns
        guard Set(all).count == all.count else { throw PrismetOmahaHandLabError.duplicateCards }
        let expectedBoardCount: Int
        let expectedBurnCount: Int
        let expectedCursor: Int
        switch phase {
        case .holeCards: expectedBoardCount = 0; expectedBurnCount = 0; expectedCursor = 4
        case .flop: expectedBoardCount = 3; expectedBurnCount = 1; expectedCursor = 8
        case .turn: expectedBoardCount = 4; expectedBurnCount = 2; expectedCursor = 10
        case .river: expectedBoardCount = 5; expectedBurnCount = 3; expectedCursor = 12
        case .complete: expectedBoardCount = 5; expectedBurnCount = 3; expectedCursor = 12
        }
        guard board.count == expectedBoardCount, burns.count == expectedBurnCount else { throw PrismetOmahaHandLabError.cardsDoNotMatchDrawHistory }
        guard cursor == expectedCursor else { throw PrismetOmahaHandLabError.invalidDrawIndex(expected: expectedCursor, actual: cursor) }
        let expectedHole = Array(deck[0..<4])
        var expectedBoard: [PrismetPlayingCard] = []
        var expectedBurns: [PrismetPlayingCard] = []
        if expectedBurnCount >= 1 { expectedBurns.append(deck[4]); expectedBoard += Array(deck[5..<8]) }
        if expectedBurnCount >= 2 { expectedBurns.append(deck[8]); expectedBoard.append(deck[9]) }
        if expectedBurnCount >= 3 { expectedBurns.append(deck[10]); expectedBoard.append(deck[11]) }
        guard hole == expectedHole, board == expectedBoard, burns == expectedBurns else { throw PrismetOmahaHandLabError.cardsDoNotMatchDrawHistory }
        let shouldHaveClassification = phase == .complete
        if shouldHaveClassification {
            guard let classification, classification == (try PrismetOmahaHandLab.classify(holeCards: hole, board: board)) else { throw PrismetOmahaHandLabError.invalidClassification }
        } else if classification != nil { throw PrismetOmahaHandLabError.invalidClassification }
    }
}

public enum PrismetOmahaHandLab {
    public static let legalCandidateCount = 60

    public static func canonicalDeck(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }

    public static func deal(seed: UInt64) throws -> PrismetOmahaHandLabState {
        let deck = try canonicalDeck(seed: seed)
        return PrismetOmahaHandLabState(seed: seed, deck: deck, phase: .holeCards, holeCards: Array(deck[0..<4]), visibleBoard: [], burnedCards: [], classification: nil, drawIndex: 4)
    }

    public static func dealFour(seed: UInt64) throws -> PrismetOmahaHandLabState {
        try deal(seed: seed)
    }

    public static func revealFlop(in state: PrismetOmahaHandLabState) throws -> PrismetOmahaHandLabState {
        try reveal(state, phase: .flop)
    }

    public static func revealTurn(in state: PrismetOmahaHandLabState) throws -> PrismetOmahaHandLabState {
        try reveal(state, phase: .turn)
    }

    public static func revealRiver(in state: PrismetOmahaHandLabState) throws -> PrismetOmahaHandLabState {
        try reveal(state, phase: .river)
    }

    public static func classify(_ state: PrismetOmahaHandLabState) throws -> PrismetOmahaHandLabState {
        guard state.phase == .river else { throw PrismetOmahaHandLabError.invalidPhase(state.phase) }
        let result = try classify(holeCards: state.holeCards, board: state.visibleBoard)
        return PrismetOmahaHandLabState(seed: state.seed, deck: state.shuffledDeck, phase: .complete, holeCards: state.holeCards, visibleBoard: state.visibleBoard, burnedCards: state.burnedCards, classification: result, drawIndex: 12)
    }

    public static func classify(holeCards: [PrismetPlayingCard], board: [PrismetPlayingCard]) throws -> PrismetOmahaClassification {
        guard holeCards.count == 4 else { throw PrismetOmahaHandLabError.invalidHoleCardCount(holeCards.count) }
        guard board.count == 5 else { throw PrismetOmahaHandLabError.invalidBoardCardCount(board.count) }
        guard Set(holeCards + board).count == 9 else { throw PrismetOmahaHandLabError.duplicateCards }
        var best: PrismetPokerCategory = .highCard
        var evaluated = 0
        for first in 0..<3 {
            for second in (first + 1)..<4 {
                for boardFirst in 0..<4 {
                    for boardSecond in (boardFirst + 1)..<5 {
                    for boardThird in (boardSecond + 1)..<5 {
                            let candidate = [holeCards[first], holeCards[second], board[boardFirst], board[boardSecond], board[boardThird]]
                            best = max(best, try PrismetFiveCardPokerEngine.evaluate(candidate))
                            evaluated += 1
                        }
                    }
                }
            }
        }
        return PrismetOmahaClassification(category: best, evaluatedCandidateCount: evaluated)
    }

    private static func reveal(_ state: PrismetOmahaHandLabState, phase: PrismetOmahaHandLabPhase) throws -> PrismetOmahaHandLabState {
        let expected: PrismetOmahaHandLabPhase = state.phase == .holeCards ? .flop : state.phase == .flop ? .turn : .river
        guard phase == expected else { throw PrismetOmahaHandLabError.invalidPhase(state.phase) }
        var board = state.visibleBoard
        var burns = state.burnedCards
        if phase == .flop { burns.append(state.shuffledDeck[4]); board += Array(state.shuffledDeck[5..<8]) }
        if phase == .turn { burns.append(state.shuffledDeck[8]); board.append(state.shuffledDeck[9]) }
        if phase == .river { burns.append(state.shuffledDeck[10]); board.append(state.shuffledDeck[11]) }
        let cursor = phase == .flop ? 8 : phase == .turn ? 10 : 12
        return PrismetOmahaHandLabState(seed: state.seed, deck: state.shuffledDeck, phase: phase, holeCards: state.holeCards, visibleBoard: board, burnedCards: burns, classification: nil, drawIndex: cursor)
    }
}
