import Foundation
import XCTest
@testable import PrismetShared

final class PrismetFiveCardPokerTests: XCTestCase {
    func testExactCategoryCountsHaveEveryUniqueCategoryAndExactCount() {
        let expectedCounts: [PrismetPokerCategory: Int] = [
            .highCard: 1_302_540,
            .onePair: 1_098_240,
            .twoPair: 123_552,
            .threeOfAKind: 54_912,
            .straight: 10_200,
            .flush: 5_108,
            .fullHouse: 3_744,
            .fourOfAKind: 624,
            .straightFlush: 36,
            .royalFlush: 4,
        ]
        let groupedCounts = Dictionary(
            grouping: PrismetFiveCardPokerEngine.exactCategoryCounts,
            by: \.category
        )

        XCTAssertEqual(Set(groupedCounts.keys), Set(PrismetPokerCategory.allCases))
        XCTAssertTrue(groupedCounts.values.allSatisfy { $0.count == 1 })
        XCTAssertEqual(groupedCounts.mapValues { $0[0].count }, expectedCounts)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCategoryCounts.map(\.count).reduce(0, +), 2_598_960)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactTotalHandCount, 2_598_960)

        for category in PrismetPokerCategory.allCases {
            XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: category), expectedCounts[category])
        }
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

    func testEvaluateRejectsInvalidHandsWithExactErrors() {
        let fourCards = [
            card(.ace, .clubs), card(.king, .diamonds), card(.queen, .hearts), card(.jack, .spades)
        ]
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.evaluate(fourCards)) {
            XCTAssertEqual($0 as? PrismetFiveCardPokerEngineError, .invalidCardCount(4))
        }

        let duplicate = card(.ace, .clubs)
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.evaluate([
            duplicate, duplicate, card(.king, .diamonds), card(.queen, .hearts), card(.jack, .spades)
        ])) {
            XCTAssertEqual($0 as? PrismetFiveCardPokerEngineError, .duplicateCards)
        }
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

    func testAllHeldAndNoHeldDrawsUseExactCursorBoundaries() throws {
        let seed: UInt64 = 9_191
        let initial = try PrismetFiveCardPokerEngine.deal(seed: seed)
        let deck = try canonicalDeck(seed: seed)

        let noHeld = try PrismetFiveCardPokerEngine.drawing(initial)
        XCTAssertEqual(noHeld.cards, Array(deck[5..<10]))
        XCTAssertTrue(Set(initial.cards).isDisjoint(with: noHeld.cards))
        XCTAssertEqual(noHeld.category, try PrismetFiveCardPokerEngine.evaluate(noHeld.cards))
        XCTAssertEqual(try encodedInt("drawIndex", in: noHeld), 10)

        var allHeld = initial
        for index in 0..<5 {
            allHeld = try PrismetFiveCardPokerEngine.togglingHold(at: index, in: allHeld)
        }
        let unchanged = try PrismetFiveCardPokerEngine.drawing(allHeld)
        XCTAssertEqual(unchanged.cards, initial.cards)
        XCTAssertEqual(unchanged.heldIndices, Set(0..<5))
        XCTAssertEqual(unchanged.category, try PrismetFiveCardPokerEngine.evaluate(initial.cards))
        XCTAssertEqual(try encodedInt("drawIndex", in: unchanged), 5)
    }

    func testDrawReplayIsDeterministicForSeedAndHolds() throws {
        var first = try PrismetFiveCardPokerEngine.deal(seed: 0xCA51_0042)
        for index in [0, 3] {
            first = try PrismetFiveCardPokerEngine.togglingHold(at: index, in: first)
        }

        var replay = try PrismetFiveCardPokerEngine.deal(seed: 0xCA51_0042)
        for index in [3, 0] {
            replay = try PrismetFiveCardPokerEngine.togglingHold(at: index, in: replay)
        }

        XCTAssertEqual(
            try PrismetFiveCardPokerEngine.drawing(first),
            try PrismetFiveCardPokerEngine.drawing(replay)
        )
    }

    func testHoldCanBeToggledAndInvalidIndicesReturnExactErrors() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let held = try PrismetFiveCardPokerEngine.togglingHold(at: 2, in: initial)

        XCTAssertEqual(held.heldIndices, [2])
        XCTAssertEqual(try PrismetFiveCardPokerEngine.togglingHold(at: 2, in: held).heldIndices, [])
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.togglingHold(at: -1, in: initial)) {
            XCTAssertEqual($0 as? PrismetFiveCardPokerEngineError, .invalidHoldIndex(-1))
        }
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.togglingHold(at: 5, in: initial)) {
            XCTAssertEqual($0 as? PrismetFiveCardPokerEngineError, .invalidHoldIndex(5))
        }
    }

    func testSecondDrawAndHoldingAfterCompletionReturnExactPhaseErrors() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let final = try PrismetFiveCardPokerEngine.drawing(initial)

        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.drawing(final)) {
            XCTAssertEqual($0 as? PrismetFiveCardPokerEngineError, .invalidPhase(.complete))
        }
        XCTAssertThrowsError(try PrismetFiveCardPokerEngine.togglingHold(at: 0, in: final)) {
            XCTAssertEqual($0 as? PrismetFiveCardPokerEngineError, .invalidPhase(.complete))
        }
    }

    func testValidCodableRoundTripPreservesDrawContinuation() throws {
        var held = try PrismetFiveCardPokerEngine.deal(seed: 80_085)
        for index in [1, 4] {
            held = try PrismetFiveCardPokerEngine.togglingHold(at: index, in: held)
        }

        let restored = try JSONDecoder().decode(
            PrismetFiveCardPokerState.self,
            from: JSONEncoder().encode(held)
        )
        XCTAssertEqual(restored, held)

        let originalFinal = try PrismetFiveCardPokerEngine.drawing(held)
        let restoredFinal = try PrismetFiveCardPokerEngine.drawing(restored)
        XCTAssertEqual(restoredFinal, originalFinal)
        XCTAssertEqual(
            try JSONDecoder().decode(
                PrismetFiveCardPokerState.self,
                from: JSONEncoder().encode(originalFinal)
            ),
            originalFinal
        )
    }

    func testDecodingRejectsUnsupportedRandomizerAndNonCanonicalDecksWithExactErrors() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)

        try assertStateDecodingRejected(initial, equals: .unsupportedRandomizerVersion(2)) {
            $0["randomizerVersion"] = 2
        }
        try assertStateDecodingRejected(initial, equals: .shuffledDeckMismatch) {
            $0["seed"] = 92
        }
        try assertStateDecodingRejected(initial, equals: .shuffledDeckMismatch) { object in
            var deck = try XCTUnwrap(object["shuffledDeck"] as? [[String: Any]])
            deck.swapAt(0, 1)
            object["shuffledDeck"] = deck
        }
        try assertStateDecodingRejected(initial, equals: .shuffledDeckMismatch) { object in
            var deck = try XCTUnwrap(object["shuffledDeck"] as? [[String: Any]])
            deck.removeLast()
            object["shuffledDeck"] = deck
        }
        try assertStateDecodingRejected(initial, equals: .shuffledDeckMismatch) { object in
            var deck = try XCTUnwrap(object["shuffledDeck"] as? [[String: Any]])
            deck[1] = deck[0]
            object["shuffledDeck"] = deck
        }
    }

    func testDecodingRejectsInvalidCardsAndHeldIndicesWithExactErrors() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)

        try assertStateDecodingRejected(initial, equals: .invalidCardCount(4)) { object in
            var cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
            cards.removeLast()
            object["cards"] = cards
        }
        try assertStateDecodingRejected(initial, equals: .duplicateCards) { object in
            var cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
            cards[1] = cards[0]
            object["cards"] = cards
        }
        try assertStateDecodingRejected(initial, equals: .invalidHoldIndex(-1)) {
            $0["heldIndices"] = [-1]
        }
        try assertStateDecodingRejected(initial, equals: .invalidHoldIndex(5)) {
            $0["heldIndices"] = [5]
        }
    }

    func testDecodingRejectsNegativeAndPhaseInconsistentDrawIndicesWithoutTrapping() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let complete = try PrismetFiveCardPokerEngine.drawing(initial)

        try assertStateDecodingRejected(initial, equals: .invalidDrawIndex(expected: 5, actual: -1)) {
            $0["drawIndex"] = -1
        }
        try assertStateDecodingRejected(initial, equals: .invalidDrawIndex(expected: 5, actual: 53)) {
            $0["drawIndex"] = 53
        }
        try assertStateDecodingRejected(initial, equals: .invalidDrawIndex(expected: 5, actual: 6)) {
            $0["drawIndex"] = 6
        }
        try assertStateDecodingRejected(complete, equals: .invalidDrawIndex(expected: 10, actual: 9)) {
            $0["drawIndex"] = 9
        }
    }

    func testDecodingRejectsCardsAndCategoriesThatDisagreeWithPhaseHistory() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
        let complete = try PrismetFiveCardPokerEngine.drawing(initial)
        let completeCategory = try XCTUnwrap(complete.category)
        let wrongCategory: PrismetPokerCategory = completeCategory == .royalFlush ? .highCard : .royalFlush

        try assertStateDecodingRejected(initial, equals: .cardsDoNotMatchDrawHistory) { object in
            var cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
            let deck = try XCTUnwrap(object["shuffledDeck"] as? [[String: Any]])
            cards[0] = deck[5]
            object["cards"] = cards
        }
        try assertStateDecodingRejected(initial, equals: .invalidCategory(expected: nil, actual: .highCard)) {
            $0["category"] = PrismetPokerCategory.highCard.rawValue
        }
        try assertStateDecodingRejected(complete, equals: .cardsDoNotMatchDrawHistory) { object in
            var cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
            cards.swapAt(0, 1)
            object["cards"] = cards
        }
        try assertStateDecodingRejected(
            complete,
            equals: .invalidCategory(expected: completeCategory, actual: nil)
        ) {
            $0.removeValue(forKey: "category")
        }
        try assertStateDecodingRejected(
            complete,
            equals: .invalidCategory(expected: completeCategory, actual: wrongCategory)
        ) {
            $0["category"] = wrongCategory.rawValue
        }
    }

    func testDecodingRejectsUnknownPhaseAndCategoryRawValues() throws {
        let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)

        let invalidPhase = try mutatedEncoding(of: initial) {
            $0["phase"] = "dealing"
        }
        assertDataCorrupted(
            tryDecode: { try JSONDecoder().decode(PrismetFiveCardPokerState.self, from: invalidPhase) }
        )

        let invalidCategory = try mutatedEncoding(of: initial) {
            $0["category"] = 99
        }
        assertDataCorrupted(
            tryDecode: { try JSONDecoder().decode(PrismetFiveCardPokerState.self, from: invalidCategory) }
        )
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

    private func canonicalDeck(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return deck
    }

    private func encodedObject(
        for state: PrismetFiveCardPokerState
    ) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        return try XCTUnwrap(object as? [String: Any])
    }

    private func encodedInt(
        _ key: String,
        in state: PrismetFiveCardPokerState
    ) throws -> Int {
        try XCTUnwrap(try encodedObject(for: state)[key] as? Int)
    }

    private func mutatedEncoding(
        of state: PrismetFiveCardPokerState,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> Data {
        var object = try encodedObject(for: state)
        try mutate(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func assertStateDecodingRejected(
        _ state: PrismetFiveCardPokerState,
        equals expected: PrismetFiveCardPokerStateValidationError,
        mutate: (inout [String: Any]) throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let data = try mutatedEncoding(of: state, mutate: mutate)
        XCTAssertThrowsError(
            try JSONDecoder().decode(PrismetFiveCardPokerState.self, from: data),
            file: file,
            line: line
        ) {
            XCTAssertEqual(
                $0 as? PrismetFiveCardPokerStateValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }

    private func assertDataCorrupted(
        tryDecode: () throws -> PrismetFiveCardPokerState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try tryDecode(), file: file, line: line) {
            guard case DecodingError.dataCorrupted = $0 else {
                return XCTFail("Expected DecodingError.dataCorrupted, got \($0)", file: file, line: line)
            }
        }
    }
}
