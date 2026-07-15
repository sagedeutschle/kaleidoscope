import XCTest
import PrismetShared
@testable import Prismet

@MainActor
final class PracticeCasinoSessionTests: XCTestCase {
    func testEveryCatalogGameCanBeSelectedWithoutStartingARound() {
        let session = PracticeCasinoSession(seedSource: { 7 })

        for game in PrismetPracticeCasinoCatalog.all {
            session.select(game.id)
            XCTAssertEqual(session.selectedGameID, game.id)
            XCTAssertNil(session.roundResult)
            XCTAssertNil(session.pokerState)
        }
    }

    func testCompactRoundRequiresExplicitPlayAndNewRoundDoesNotAutoplay() {
        let session = PracticeCasinoSession(seedSource: { 42 })
        session.select(.coinCall)
        session.toggleChoice("heads")

        XCTAssertNil(session.roundResult)
        session.playRound()
        XCTAssertEqual(session.roundResult?.seed, 42)
        XCTAssertEqual(session.completedRoundCount, 1)

        session.newRound()
        XCTAssertNil(session.roundResult)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testPokerHoldDrawAndResetStaySessionOnly() throws {
        let session = PracticeCasinoSession(seedSource: { 91 })
        session.select(.fiveCardDraw)
        session.dealPoker()
        let opening = try XCTUnwrap(session.pokerState)

        session.togglePokerHold(at: 0)
        session.drawPoker()

        XCTAssertEqual(session.pokerState?.cards[0], opening.cards[0])
        XCTAssertEqual(session.completedRoundCount, 1)

        session.resetSession()
        XCTAssertNil(session.pokerState)
        XCTAssertEqual(session.completedRoundCount, 0)
    }

    func testSwitchingTablesClearsTransientStateWithoutStartingTheNewTable() {
        let session = PracticeCasinoSession(seedSource: { 12 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()

        session.select(.fairWheel)

        XCTAssertEqual(session.selectedGameID, .fairWheel)
        XCTAssertTrue(session.selectedChoiceIDs.isEmpty)
        XCTAssertNil(session.roundResult)
        XCTAssertNil(session.pokerState)
    }

    func testReselectingTheCurrentTablePreservesItsVisitState() {
        let session = PracticeCasinoSession(seedSource: { 12 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        let result = session.roundResult

        session.select(.coinCall)

        XCTAssertEqual(session.roundResult, result)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testHigherLowerPreviewConsumesOneSeedAndRevealReusesIt() throws {
        var seeds: [UInt64] = [41, 99]
        let session = PracticeCasinoSession(seedSource: { seeds.removeFirst() })
        session.select(.higherLower)

        session.showHigherLowerCard()
        let preview = try XCTUnwrap(session.higherLowerPreview)
        XCTAssertEqual(preview.seed, 41)
        XCTAssertEqual(seeds, [99])
        XCTAssertNil(session.roundResult)

        session.toggleChoice("higher")
        session.revealHigherLower()
        XCTAssertEqual(session.roundResult?.seed, 41)
        XCTAssertEqual(seeds, [99])
    }

    func testHigherLowerRejectsChoicesUntilThePreviewExists() {
        let session = PracticeCasinoSession(seedSource: { 41 })
        session.select(.higherLower)

        session.toggleChoice("higher")
        XCTAssertTrue(session.selectedChoiceIDs.isEmpty)

        session.showHigherLowerCard()
        session.toggleChoice("higher")
        XCTAssertEqual(session.selectedChoiceIDs, ["higher"])
    }

    func testChoiceLimitsReplaceSingleChoiceAndCapNumberDrawAtThree() {
        let session = PracticeCasinoSession(seedSource: { 7 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.toggleChoice("tails")
        XCTAssertEqual(session.selectedChoiceIDs, ["tails"])

        session.select(.numberDraw)
        ["1", "2", "3", "4"].forEach(session.toggleChoice)
        XCTAssertEqual(session.selectedChoiceIDs, ["1", "2", "3"])
    }

    func testInvalidAndRepeatedActionsDoNotConsumeSeeds() {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 50
        })
        session.select(.coinCall)

        session.playRound()
        XCTAssertEqual(seedCalls, 0)

        session.toggleChoice("heads")
        session.playRound()
        session.playRound()
        XCTAssertEqual(seedCalls, 1)

        session.newRound()
        session.select(.higherLower)
        session.revealHigherLower()
        XCTAssertEqual(seedCalls, 1)
    }

    func testPokerCannotDrawTwiceWithoutNewRound() {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 73
        })
        session.select(.fiveCardDraw)
        session.dealPoker()
        session.drawPoker()
        let terminalState = session.pokerState

        session.drawPoker()
        session.dealPoker()

        XCTAssertEqual(session.pokerState, terminalState)
        XCTAssertEqual(seedCalls, 1)
    }

    func testInvalidPokerHoldPreservesTheValidHand() throws {
        let session = PracticeCasinoSession(seedSource: { 73 })
        session.select(.fiveCardDraw)
        session.dealPoker()
        let opening = try XCTUnwrap(session.pokerState)

        session.togglePokerHold(at: 99)

        XCTAssertEqual(session.pokerState, opening)
    }
}
