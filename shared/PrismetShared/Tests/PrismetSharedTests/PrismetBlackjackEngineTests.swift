import XCTest
@testable import PrismetShared

final class PrismetBlackjackEngineTests: XCTestCase {
    func testFixtureDealsPlayerDealerPlayerDealer() throws {
        let playerFirst = PrismetBlackjackFixtures.card(.ten, .clubs)
        let dealerUp = PrismetBlackjackFixtures.card(.five, .diamonds)
        let playerSecond = PrismetBlackjackFixtures.card(.six, .hearts)
        let dealerHole = PrismetBlackjackFixtures.card(.king, .spades)
        let transition = try start([
            playerFirst, dealerUp, playerSecond, dealerHole
        ])
        let observation = PrismetBlackjackEngine.observation(for: transition.state)

        XCTAssertEqual(observation.playerCards, [playerFirst, playerSecond])
        XCTAssertEqual(observation.dealerCards, [.faceUp(dealerUp), .faceDown])
        XCTAssertEqual(observation.phase, .playerTurn)
        XCTAssertEqual(observation.legalCommands, [.hit, .stand])
        XCTAssertTrue(observation.canEndHand)
        XCTAssertNil(observation.resolution)
    }

    func testInitialNaturalsResolveWithoutPlayerCommand() throws {
        let playerNatural = try start(PrismetBlackjackFixtures.cards(.ace, .ten, .king, .nine))
        let playerObservation = PrismetBlackjackEngine.observation(for: playerNatural.state)

        XCTAssertEqual(playerObservation.phase, .completed)
        XCTAssertEqual(playerObservation.resolution?.outcome, .playerWins)
        XCTAssertEqual(playerObservation.resolution?.reason, .playerNatural)
        XCTAssertEqual(playerObservation.legalCommands, [])

        let dealerNatural = try start(PrismetBlackjackFixtures.cards(.ten, .ace, .nine, .king))
        let dealerObservation = PrismetBlackjackEngine.observation(for: dealerNatural.state)
        XCTAssertEqual(dealerObservation.resolution?.outcome, .dealerWins)
        XCTAssertEqual(dealerObservation.resolution?.reason, .dealerNatural)
    }

    func testHitCanResolvePlayerBust() throws {
        let started = try start(PrismetBlackjackFixtures.cards(.king, .five, .queen, .ten, .two))

        let hit = try PrismetBlackjackEngine.applying(.hit, to: started.state)
        let observation = PrismetBlackjackEngine.observation(for: hit.state)

        XCTAssertEqual(observation.playerValue.total, 22)
        XCTAssertEqual(observation.phase, .completed)
        XCTAssertEqual(observation.resolution?.outcome, .dealerWins)
        XCTAssertEqual(observation.resolution?.reason, .playerBust)
        XCTAssertEqual(hit.events.last, .handCompleted(try XCTUnwrap(observation.resolution)))
    }

    func testStandDrivesDealerUntilHardThresholdAndCanBust() throws {
        let started = try start(PrismetBlackjackFixtures.cards(.ten, .ten, .six, .six, .king))

        let stood = try PrismetBlackjackEngine.applying(.stand, to: started.state)
        let observation = PrismetBlackjackEngine.observation(for: stood.state)

        XCTAssertEqual(observation.phase, .completed)
        XCTAssertEqual(observation.dealerFinalValue?.total, 26)
        XCTAssertEqual(observation.resolution?.outcome, .playerWins)
        XCTAssertEqual(observation.resolution?.reason, .dealerBust)
        XCTAssertTrue(stood.events.contains(.dealerHit))
    }

    func testDealerStandsOnSoftSeventeen() throws {
        let started = try start(PrismetBlackjackFixtures.cards(.ten, .ace, .eight, .six, .king))

        let stood = try PrismetBlackjackEngine.applying(.stand, to: started.state)
        let observation = PrismetBlackjackEngine.observation(for: stood.state)

        XCTAssertEqual(observation.dealerFinalValue?.total, 17)
        XCTAssertEqual(observation.dealerFinalValue?.isSoft, true)
        XCTAssertFalse(stood.events.contains(.dealerHit))
        XCTAssertEqual(observation.resolution?.outcome, .playerWins)
    }

    func testDealerHitsSoftSixteen() throws {
        let started = try start(PrismetBlackjackFixtures.cards(.ten, .ace, .eight, .five, .two))

        let stood = try PrismetBlackjackEngine.applying(.stand, to: started.state)
        let observation = PrismetBlackjackEngine.observation(for: stood.state)

        XCTAssertTrue(stood.events.contains(.dealerHit))
        XCTAssertEqual(observation.dealerFinalValue?.total, 18)
        XCTAssertEqual(observation.dealerFinalValue?.isSoft, true)
        XCTAssertEqual(observation.resolution?.outcome, .tie)
    }

    func testHigherTotalsAndEqualTotalsResolveDeterministically() throws {
        let playerHigher = try start(PrismetBlackjackFixtures.cards(.ten, .ten, .nine, .eight))
        let playerWon = try PrismetBlackjackEngine.applying(.stand, to: playerHigher.state)
        XCTAssertEqual(
            PrismetBlackjackEngine.observation(for: playerWon.state).resolution?.reason,
            .playerHigherTotal
        )

        let equal = try start(PrismetBlackjackFixtures.cards(.ten, .queen, .eight, .eight))
        let tied = try PrismetBlackjackEngine.applying(.stand, to: equal.state)
        XCTAssertEqual(
            PrismetBlackjackEngine.observation(for: tied.state).resolution?.outcome,
            .tie
        )
    }

    func testIllegalCommandDoesNotMutateTerminalState() throws {
        let started = try start(PrismetBlackjackFixtures.cards(.ace, .ten, .king, .nine))
        let original = started.state

        XCTAssertThrowsError(try PrismetBlackjackEngine.applying(.hit, to: original)) {
            XCTAssertEqual(
                $0 as? PrismetBlackjackEngineError,
                .illegalCommand(command: .hit, phase: .completed)
            )
        }
        XCTAssertEqual(started.state, original)
    }

    func testEndingHandIsNeutralAndNoTransitionStartsAnotherHand() throws {
        let started = try start(PrismetBlackjackFixtures.cards(.ten, .five, .six, .king))
        let ended = try PrismetBlackjackEngine.endHand(started.state)
        let observation = PrismetBlackjackEngine.observation(for: ended.state)

        XCTAssertEqual(observation.phase, .abandoned)
        XCTAssertEqual(observation.resolution?.outcome, .abandoned)
        XCTAssertEqual(observation.resolution?.reason, .endedByPlayer)
        XCTAssertEqual(observation.legalCommands, [])
        XCTAssertFalse(observation.canEndHand)
        XCTAssertEqual(ended.events, [.handAbandoned])
        XCTAssertThrowsError(try PrismetBlackjackEngine.endHand(ended.state))
    }

    func testSameSeedProducesEquivalentStateAndEvents() throws {
        let first = try PrismetBlackjackEngine.start(seed: 0xCA51_0001)
        let second = try PrismetBlackjackEngine.start(seed: 0xCA51_0001)

        XCTAssertEqual(first, second)
    }

    private func start(_ drawOrder: [PrismetPlayingCard]) throws -> PrismetBlackjackTransition {
        try PrismetBlackjackEngine.start(
            seed: 99,
            shuffledDeck: PrismetBlackjackFixtures.deck(drawing: drawOrder)
        )
    }
}
