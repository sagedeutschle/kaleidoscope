import XCTest
@testable import PrismetShared

final class PrismetFiveCardPokerTests: XCTestCase {
    func testExactCategoryCountsAreMutuallyExclusiveAndExhaustive() {
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactTotalHandCount, 2_598_960)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCategoryCounts.count, PrismetPokerCategory.allCases.count)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: .royalFlush), 4)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: .straightFlush), 36)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCategoryCounts.map(\.count).reduce(0, +), 2_598_960)
    }

    func testEvaluateRecognizesEveryFiveCardCategory() throws {
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate(cards(.ace, .king, .queen, .jack, .ten, suit: .hearts)), .royalFlush)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate(cards(.nine, .eight, .seven, .six, .five, suit: .spades)), .straightFlush)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.ace, .clubs), card(.ace, .diamonds), card(.ace, .hearts), card(.ace, .spades), card(.two, .clubs)
        ]), .fourOfAKind)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.king, .clubs), card(.king, .diamonds), card(.king, .hearts), card(.two, .spades), card(.two, .clubs)
        ]), .fullHouse)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.ace, .hearts), card(.nine, .hearts), card(.seven, .hearts), card(.four, .hearts), card(.two, .hearts)
        ]), .flush)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.ace, .clubs), card(.two, .diamonds), card(.three, .hearts), card(.four, .spades), card(.five, .clubs)
        ]), .straight)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.queen, .clubs), card(.queen, .diamonds), card(.queen, .hearts), card(.seven, .spades), card(.two, .clubs)
        ]), .threeOfAKind)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.jack, .clubs), card(.jack, .diamonds), card(.four, .hearts), card(.four, .spades), card(.two, .clubs)
        ]), .twoPair)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.ten, .clubs), card(.ten, .diamonds), card(.seven, .hearts), card(.four, .spades), card(.two, .clubs)
        ]), .onePair)
        XCTAssertEqual(try PrismetFiveCardPokerEngine.evaluate([
            card(.ace, .clubs), card(.jack, .diamonds), card(.eight, .hearts), card(.five, .spades), card(.two, .clubs)
        ]), .highCard)
    }

    func testDealIsDeterministicAndContainsFiveUniqueCards() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)

        XCTAssertEqual(initial, try PrismetFiveCardPokerEngine.deal(seed: 91))
        XCTAssertEqual(initial.cards.count, 5)
        XCTAssertEqual(Set(initial.cards).count, 5)
        XCTAssertEqual(initial.phase, .choosingHolds)
        XCTAssertEqual(initial.heldIndices, [])
        XCTAssertNil(initial.category)
        XCTAssertEqual(initial.seed, 91)
        XCTAssertEqual(initial.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
    }

    func testDrawKeepsHeldCardReplacesUnheldCardsAndConservesDeck() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let held = try PrismetFiveCardPokerEngine.togglingHold(at: 0, in: initial)
        let final = try PrismetFiveCardPokerEngine.drawing(held)

        XCTAssertEqual(final.cards[0], initial.cards[0])
        XCTAssertEqual(final.cards.count, 5)
        XCTAssertEqual(Set(final.cards).count, 5)
        XCTAssertEqual(Set(initial.cards).union(final.cards).count, 9)
        XCTAssertEqual(final.phase, .complete)
        XCTAssertNotNil(final.category)
    }

    func testHoldCanBeToggledAndInvalidIndicesAreRejectedWithoutChangingState() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let held = try PrismetFiveCardPokerEngine.togglingHold(at: 2, in: initial)

        XCTAssertEqual(held.heldIndices, [2])
        XCTAssertEqual(try PrismetFiveCardPokerEngine.togglingHold(at: 2, in: held).heldIndices, [])
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.togglingHold(at: -1, in: initial))
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.togglingHold(at: 5, in: initial))
    }

    func testSecondDrawAndHoldingAfterCompletionAreRejected() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let final = try PrismetFiveCardPokerEngine.drawing(initial)

        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.drawing(final))
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.togglingHold(at: 0, in: final))
    }

    private func card(_ rank: PrismetCardRank, _ suit: PrismetCardSuit) -> PrismetPlayingCard {
        PrismetPlayingCard(rank: rank, suit: suit)
    }

    private func cards(
        _ first: PrismetCardRank,
        _ second: PrismetCardRank,
        _ third: PrismetCardRank,
        _ fourth: PrismetCardRank,
        _ fifth: PrismetCardRank,
        suit: PrismetCardSuit
    ) -> [PrismetPlayingCard] {
        [first, second, third, fourth, fifth].map { card($0, suit) }
    }
}
