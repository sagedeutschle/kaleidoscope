import XCTest
import PrismetShared
@testable import Prismet

@MainActor
final class PracticeCasinoSessionTests: XCTestCase {
    func testMacSessionRoutesEverySharedCatalogEntry() {
        let session = PracticeCasinoSession(seedSource: { 12 })

        for descriptor in PrismetPracticeCasinoCatalog.all {
            session.select(descriptor.id)
            XCTAssertEqual(session.selectedGameID, descriptor.id)
            XCTAssertNil(session.roundResult)
        }
    }

    func testMacNewRoundAndResetNeverCreateAnOutcome() {
        let session = PracticeCasinoSession(seedSource: { 12 })
        session.select(.oddEven)
        session.toggleChoice("odd")
        session.playRound()
        XCTAssertNotNil(session.roundResult)

        session.newRound()
        XCTAssertNil(session.roundResult)

        XCTAssertFalse(session.resetSession())
        XCTAssertNil(session.roundResult)
        XCTAssertTrue(session.resetSession(confirming: true))
        XCTAssertNil(session.roundResult)
        XCTAssertEqual(session.completedRoundCount, 0)
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

    func testHigherLowerUsesTypedPreviewThenResolvesTheSameShownCard() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 42
        })
        session.select(.higherLower)

        XCTAssertNil(session.higherLowerPreview)
        session.showHigherLowerCard()
        let preview = try XCTUnwrap(session.higherLowerPreview)
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(preview.shownCard, try PrismetFairChanceEngine.previewHigherLower(seed: 42).shownCard)

        session.toggleChoice("higher")
        session.playRound()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.roundResult?.tokens.first, Optional(preview.shownCard))
    }

    func testInvalidAndRepeatedActionsConsumeNoSeeds() {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 7
        })
        session.select(.coinCall)
        session.toggleChoice("not-a-choice")
        session.playRound()
        XCTAssertEqual(seedCalls, 0)

        session.toggleChoice("heads")
        session.playRound()
        XCTAssertEqual(seedCalls, 1)
        session.playRound()
        session.toggleChoice("tails")
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.roundResult?.seed, 7)
    }

    func testMacPokerRequiresExplicitDealHoldAndDraw() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 91
        })
        session.select(.fiveCardDraw)
        XCTAssertNil(session.pokerState)

        session.dealPoker()
        let opening = try XCTUnwrap(session.pokerState)
        XCTAssertEqual(opening.phase, .choosingHolds)
        XCTAssertEqual(seedCalls, 1)

        session.togglePokerHold(at: 0)
        session.drawPoker()

        XCTAssertEqual(session.pokerState?.phase, .complete)
        XCTAssertEqual(session.pokerState?.cards[0], opening.cards[0])
        XCTAssertEqual(session.completedRoundCount, 1)

        session.drawPoker()
        session.dealPoker()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testResetConfirmationOnlyClearsCompactAndPokerVisitState() {
        let session = PracticeCasinoSession(seedSource: { 91 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        XCTAssertFalse(session.resetSession())
        XCTAssertNotNil(session.roundResult)
        XCTAssertTrue(session.resetSession(confirming: true))
        XCTAssertNil(session.roundResult)
        XCTAssertNil(session.pokerState)
    }

    func testPokerCountsAreCompleteAndMutuallyExclusive() {
        let counts = PrismetFiveCardPokerEngine.exactCategoryCounts
        XCTAssertEqual(counts.count, PrismetPokerCategory.allCases.count)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: .royalFlush), 4)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: .straightFlush), 36)
        XCTAssertEqual(counts.reduce(0) { $0 + $1.count }, PrismetFiveCardPokerEngine.exactTotalHandCount)
    }

    func testSelectingAnotherTableClearsUnfinishedTableState() {
        let session = PracticeCasinoSession(seedSource: { 7 })
        session.select(.fiveCardDraw)
        session.dealPoker()
        XCTAssertNotNil(session.pokerState)

        session.select(.coinCall)
        XCTAssertNil(session.pokerState)
        XCTAssertNil(session.roundResult)
    }

    func testReselectingTheCurrentTablePreservesItsVisitState() {
        let session = PracticeCasinoSession(seedSource: { 7 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        let result = session.roundResult

        session.select(.coinCall)

        XCTAssertEqual(session.roundResult, result)
        XCTAssertEqual(session.completedRoundCount, 1)
    }
}
