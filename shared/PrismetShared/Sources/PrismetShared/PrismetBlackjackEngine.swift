public enum PrismetBlackjackDisplayedCard: Codable, Hashable, Sendable {
    case faceUp(PrismetPlayingCard)
    case faceDown
}

public struct PrismetBlackjackObservation: Codable, Hashable, Sendable {
    public let playerCards: [PrismetPlayingCard]
    public let dealerCards: [PrismetBlackjackDisplayedCard]
    public let playerValue: PrismetBlackjackHandValue
    public let dealerVisibleValue: PrismetBlackjackHandValue
    public let dealerFinalValue: PrismetBlackjackHandValue?
    public let legalCommands: [PrismetBlackjackCommand]
    public let canEndHand: Bool
    public let hitOdds: PrismetBlackjackHitOdds?
    public let phase: PrismetBlackjackPhase
    public let resolution: PrismetBlackjackResolution?

    public init(
        playerCards: [PrismetPlayingCard],
        dealerCards: [PrismetBlackjackDisplayedCard],
        playerValue: PrismetBlackjackHandValue,
        dealerVisibleValue: PrismetBlackjackHandValue,
        dealerFinalValue: PrismetBlackjackHandValue?,
        legalCommands: [PrismetBlackjackCommand],
        canEndHand: Bool,
        hitOdds: PrismetBlackjackHitOdds?,
        phase: PrismetBlackjackPhase,
        resolution: PrismetBlackjackResolution?
    ) {
        self.playerCards = playerCards
        self.dealerCards = dealerCards
        self.playerValue = playerValue
        self.dealerVisibleValue = dealerVisibleValue
        self.dealerFinalValue = dealerFinalValue
        self.legalCommands = legalCommands
        self.canEndHand = canEndHand
        self.hitOdds = hitOdds
        self.phase = phase
        self.resolution = resolution
    }
}

public enum PrismetBlackjackEvent: Codable, Hashable, Sendable {
    case handStarted
    case playerHit
    case playerStood
    case dealerHit
    case handCompleted(PrismetBlackjackResolution)
    case handAbandoned
}

public struct PrismetBlackjackState: Codable, Hashable, Sendable {
    let seed: UInt64
    let shuffledDeck: [PrismetPlayingCard]
    var drawIndex: Int
    var playerCards: [PrismetPlayingCard]
    var dealerCards: [PrismetPlayingCard]
    var phase: PrismetBlackjackPhase
    var resolution: PrismetBlackjackResolution?
}

public struct PrismetBlackjackTransition: Hashable, Sendable {
    public let state: PrismetBlackjackState
    public let events: [PrismetBlackjackEvent]

    public init(state: PrismetBlackjackState, events: [PrismetBlackjackEvent]) {
        self.state = state
        self.events = events
    }
}

public enum PrismetBlackjackEngineError: Error, Equatable {
    case invalidDeck
    case deckExhausted
    case illegalCommand(command: PrismetBlackjackCommand, phase: PrismetBlackjackPhase)
    case cannotEndHand(phase: PrismetBlackjackPhase)
}

public enum PrismetBlackjackEngine {
    public static func start(seed: UInt64) throws -> PrismetBlackjackTransition {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return try start(seed: seed, shuffledDeck: deck)
    }

    static func start(
        seed: UInt64,
        shuffledDeck: [PrismetPlayingCard]
    ) throws -> PrismetBlackjackTransition {
        guard shuffledDeck.count == 52,
              Set(shuffledDeck) == Set(PrismetDeckFactory.standard52()) else {
            throw PrismetBlackjackEngineError.invalidDeck
        }

        var state = PrismetBlackjackState(
            seed: seed,
            shuffledDeck: shuffledDeck,
            drawIndex: 0,
            playerCards: [],
            dealerCards: [],
            phase: .playerTurn,
            resolution: nil
        )
        state.playerCards.append(try draw(from: &state))
        state.dealerCards.append(try draw(from: &state))
        state.playerCards.append(try draw(from: &state))
        state.dealerCards.append(try draw(from: &state))

        var events: [PrismetBlackjackEvent] = [.handStarted]
        let playerValue = PrismetBlackjackHandValue(cards: state.playerCards)
        let dealerValue = PrismetBlackjackHandValue(cards: state.dealerCards)
        if playerValue.isNatural || dealerValue.isNatural {
            let resolution = PrismetBlackjackResolution.resolve(
                playerCards: state.playerCards,
                dealerCards: state.dealerCards
            )
            state.phase = .completed
            state.resolution = resolution
            events.append(.handCompleted(resolution))
        }

        return PrismetBlackjackTransition(state: state, events: events)
    }

    public static func observation(
        for state: PrismetBlackjackState
    ) -> PrismetBlackjackObservation {
        let terminal = state.phase == .completed || state.phase == .abandoned
        let displayedDealerCards: [PrismetBlackjackDisplayedCard]
        let visibleDealerCards: [PrismetPlayingCard]
        if terminal {
            displayedDealerCards = state.dealerCards.map { .faceUp($0) }
            visibleDealerCards = state.dealerCards
        } else {
            displayedDealerCards = state.dealerCards.enumerated().map { index, card in
                index == 0 ? .faceUp(card) : .faceDown
            }
            visibleDealerCards = Array(state.dealerCards.prefix(1))
        }

        let legalCommands = legalCommands(in: state)
        let hitOdds: PrismetBlackjackHitOdds?
        if legalCommands.contains(.hit), let dealerFaceUpCard = state.dealerCards.first {
            hitOdds = PrismetBlackjackHitOdds(
                playerCards: state.playerCards,
                dealerFaceUpCard: dealerFaceUpCard
            )
        } else {
            hitOdds = nil
        }

        return PrismetBlackjackObservation(
            playerCards: state.playerCards,
            dealerCards: displayedDealerCards,
            playerValue: PrismetBlackjackHandValue(cards: state.playerCards),
            dealerVisibleValue: PrismetBlackjackHandValue(cards: visibleDealerCards),
            dealerFinalValue: terminal
                ? PrismetBlackjackHandValue(cards: state.dealerCards)
                : nil,
            legalCommands: legalCommands,
            canEndHand: state.phase == .playerTurn,
            hitOdds: hitOdds,
            phase: state.phase,
            resolution: state.resolution
        )
    }

    public static func legalCommands(
        in state: PrismetBlackjackState
    ) -> [PrismetBlackjackCommand] {
        state.phase == .playerTurn ? [.hit, .stand] : []
    }

    public static func applying(
        _ command: PrismetBlackjackCommand,
        to state: PrismetBlackjackState
    ) throws -> PrismetBlackjackTransition {
        guard legalCommands(in: state).contains(command) else {
            throw PrismetBlackjackEngineError.illegalCommand(
                command: command,
                phase: state.phase
            )
        }

        switch command {
        case .hit:
            return try applyHit(to: state)
        case .stand:
            return try applyStand(to: state)
        }
    }

    public static func endHand(
        _ state: PrismetBlackjackState
    ) throws -> PrismetBlackjackTransition {
        guard state.phase == .playerTurn else {
            throw PrismetBlackjackEngineError.cannotEndHand(phase: state.phase)
        }

        var ended = state
        ended.phase = .abandoned
        ended.resolution = PrismetBlackjackResolution(
            outcome: .abandoned,
            reason: .endedByPlayer,
            playerValue: PrismetBlackjackHandValue(cards: state.playerCards),
            dealerValue: PrismetBlackjackHandValue(cards: state.dealerCards)
        )
        return PrismetBlackjackTransition(state: ended, events: [.handAbandoned])
    }

    private static func applyHit(
        to state: PrismetBlackjackState
    ) throws -> PrismetBlackjackTransition {
        var next = state
        next.playerCards.append(try draw(from: &next))
        var events: [PrismetBlackjackEvent] = [.playerHit]

        if PrismetBlackjackHandValue(cards: next.playerCards).isBust {
            let resolution = PrismetBlackjackResolution.resolve(
                playerCards: next.playerCards,
                dealerCards: next.dealerCards
            )
            next.phase = .completed
            next.resolution = resolution
            events.append(.handCompleted(resolution))
        }

        return PrismetBlackjackTransition(state: next, events: events)
    }

    private static func applyStand(
        to state: PrismetBlackjackState
    ) throws -> PrismetBlackjackTransition {
        var next = state
        next.phase = .dealerTurn
        var events: [PrismetBlackjackEvent] = [.playerStood]

        while PrismetBlackjackHandValue(cards: next.dealerCards).total < 17 {
            next.dealerCards.append(try draw(from: &next))
            events.append(.dealerHit)
        }

        let resolution = PrismetBlackjackResolution.resolve(
            playerCards: next.playerCards,
            dealerCards: next.dealerCards
        )
        next.phase = .completed
        next.resolution = resolution
        events.append(.handCompleted(resolution))
        return PrismetBlackjackTransition(state: next, events: events)
    }

    private static func draw(
        from state: inout PrismetBlackjackState
    ) throws -> PrismetPlayingCard {
        guard state.drawIndex < state.shuffledDeck.count else {
            throw PrismetBlackjackEngineError.deckExhausted
        }
        let card = state.shuffledDeck[state.drawIndex]
        state.drawIndex += 1
        return card
    }
}
