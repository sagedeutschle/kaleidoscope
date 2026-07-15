import Foundation
import XCTest
@testable import PrismetShared

final class PrismetHoldemHandLabTests: XCTestCase {
    func testDealtStatePublishesCurrentRulesAndRandomizerVersions() throws {
        let state = try PrismetHoldemHandLabEngine.deal(seed: 73)

        XCTAssertEqual(state.rulesVersion, PrismetHoldemHandLabState.rulesVersion)
        XCTAssertEqual(state.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
    }

    func testExactSevenCardCategoryCountsAreMutuallyExclusiveAndTotalAllHands() {
        let expected: [PrismetPokerCategory: Int] = [
            .highCard: 23_294_460,
            .onePair: 58_627_800,
            .twoPair: 31_433_400,
            .threeOfAKind: 6_461_620,
            .straight: 6_180_020,
            .flush: 4_047_644,
            .fullHouse: 3_473_184,
            .fourOfAKind: 224_848,
            .straightFlush: 37_260,
            .royalFlush: 4_324,
        ]

        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: PrismetHoldemHandLabEngine.exactCategoryCounts.map { ($0.category, $0.count) }),
            expected
        )
        XCTAssertEqual(PrismetHoldemHandLabEngine.exactTotalHandCount, 133_784_560)
        XCTAssertEqual(PrismetHoldemHandLabEngine.exactCategoryCounts.map(\.count).reduce(0, +), 133_784_560)
        for category in PrismetPokerCategory.allCases {
            XCTAssertEqual(PrismetHoldemHandLabEngine.exactCount(for: category), expected[category])
        }
    }

    func testBestFiveClassificationRecognizesEveryCategory() throws {
        let fixtures: [(PrismetPokerCategory, [PrismetPlayingCard])] = [
            (.royalFlush, cards(.ace, .king, .queen, .jack, .ten, suit: .hearts) + [card(.two, .clubs), card(.three, .diamonds)]),
            (.straightFlush, cards(.nine, .eight, .seven, .six, .five, suit: .spades) + [card(.two, .clubs), card(.three, .diamonds)]),
            (.fourOfAKind, [card(.ace, .clubs), card(.ace, .diamonds), card(.ace, .hearts), card(.ace, .spades), card(.two, .clubs), card(.three, .diamonds), card(.four, .hearts)]),
            (.fullHouse, [card(.king, .clubs), card(.king, .diamonds), card(.king, .hearts), card(.two, .spades), card(.two, .clubs), card(.four, .hearts), card(.five, .diamonds)]),
            (.flush, [card(.ace, .hearts), card(.nine, .hearts), card(.seven, .hearts), card(.four, .hearts), card(.two, .hearts), card(.king, .clubs), card(.queen, .diamonds)]),
            (.straight, [card(.nine, .clubs), card(.eight, .diamonds), card(.seven, .hearts), card(.six, .spades), card(.five, .clubs), card(.king, .diamonds), card(.two, .hearts)]),
            (.threeOfAKind, [card(.queen, .clubs), card(.queen, .diamonds), card(.queen, .hearts), card(.seven, .spades), card(.two, .clubs), card(.nine, .diamonds), card(.four, .hearts)]),
            (.twoPair, [card(.jack, .clubs), card(.jack, .diamonds), card(.four, .hearts), card(.four, .spades), card(.two, .clubs), card(.nine, .diamonds), card(.king, .hearts)]),
            (.onePair, [card(.ten, .clubs), card(.ten, .diamonds), card(.seven, .hearts), card(.four, .spades), card(.two, .clubs), card(.king, .diamonds), card(.nine, .hearts)]),
            (.highCard, [card(.ace, .clubs), card(.jack, .diamonds), card(.eight, .hearts), card(.five, .spades), card(.two, .clubs), card(.king, .diamonds), card(.nine, .hearts)]),
        ]

        for (expected, hand) in fixtures {
            XCTAssertEqual(try PrismetHoldemHandLabEngine.bestCategory(for: hand), expected)
        }
    }

    func testDealAndRevealsFollowFixedOrderWithoutExposingFutureCards() throws {
        let dealt = try PrismetHoldemHandLabEngine.deal(seed: 73)
        XCTAssertEqual(dealt.phase, .holeCards)
        XCTAssertEqual(dealt.holeCards.count, 2)
        XCTAssertTrue(dealt.communityCards.isEmpty)
        XCTAssertEqual(dealt.burnedCardCount, 0)
        XCTAssertNil(dealt.bestCategory)

        let flop = try PrismetHoldemHandLabEngine.revealFlop(in: dealt)
        XCTAssertEqual(flop.phase, .flop)
        XCTAssertEqual(flop.holeCards, dealt.holeCards)
        XCTAssertEqual(flop.communityCards.count, 3)
        XCTAssertEqual(flop.burnedCardCount, 1)

        let turn = try PrismetHoldemHandLabEngine.revealTurn(in: flop)
        XCTAssertEqual(turn.phase, .turn)
        XCTAssertEqual(turn.communityCards.count, 4)
        XCTAssertEqual(turn.burnedCardCount, 2)

        let river = try PrismetHoldemHandLabEngine.revealRiver(in: turn)
        XCTAssertEqual(river.phase, .river)
        XCTAssertEqual(river.communityCards.count, 5)
        XCTAssertEqual(river.burnedCardCount, 3)
        XCTAssertEqual(Set(river.holeCards + river.communityCards).count, 7)

        let complete = try PrismetHoldemHandLabEngine.complete(river)
        XCTAssertEqual(complete.phase, .complete)
        XCTAssertEqual(complete.bestCategory, try PrismetHoldemHandLabEngine.bestCategory(for: complete.holeCards + complete.communityCards))
    }

    func testInvalidPhaseDoesNotAdvanceState() throws {
        let ready = PrismetHoldemHandLabState.ready
        XCTAssertThrowsError(try PrismetHoldemHandLabEngine.revealFlop(in: ready)) {
            XCTAssertEqual($0 as? PrismetHoldemHandLabEngineError, .invalidPhase(expected: .holeCards, actual: .ready))
        }

        let dealt = try PrismetHoldemHandLabEngine.deal(seed: 8)
        XCTAssertThrowsError(try PrismetHoldemHandLabEngine.revealTurn(in: dealt)) {
            XCTAssertEqual($0 as? PrismetHoldemHandLabEngineError, .invalidPhase(expected: .flop, actual: .holeCards))
        }
        XCTAssertEqual(dealt.phase, .holeCards)
    }

    func testDeterministicReplayAndCodableStateValidation() throws {
        let dealt = try PrismetHoldemHandLabEngine.deal(seed: 191)
        let first = try PrismetHoldemHandLabEngine.complete(
            PrismetHoldemHandLabEngine.revealRiver(in: try PrismetHoldemHandLabEngine.revealTurn(in: try PrismetHoldemHandLabEngine.revealFlop(in: dealt)))
        )
        let second = try PrismetHoldemHandLabEngine.complete(
            PrismetHoldemHandLabEngine.revealRiver(in: try PrismetHoldemHandLabEngine.revealTurn(in: try PrismetHoldemHandLabEngine.revealFlop(in: try PrismetHoldemHandLabEngine.deal(seed: 191))))
        )
        XCTAssertEqual(first, second)

        let encoded = try JSONEncoder().encode(try PrismetHoldemHandLabEngine.revealFlop(in: dealt))
        let json = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(json.contains("shuffledDeck"))
        XCTAssertEqual(try JSONDecoder().decode(PrismetHoldemHandLabState.self, from: encoded), try PrismetHoldemHandLabEngine.revealFlop(in: dealt))

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["rulesVersion"] as? Int, PrismetHoldemHandLabState.rulesVersion)
        object["burnedCardCount"] = 99
        let malformed = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetHoldemHandLabState.self, from: malformed)) {
            XCTAssertEqual($0 as? PrismetHoldemHandLabStateValidationError, .invalidBurnedCardCount(expected: 1, actual: 99))
        }

        var wrongRulesVersion = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        wrongRulesVersion["rulesVersion"] = 99
        let wrongRulesData = try JSONSerialization.data(withJSONObject: wrongRulesVersion)
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetHoldemHandLabState.self, from: wrongRulesData)) {
            XCTAssertEqual($0 as? PrismetHoldemHandLabStateValidationError, .unsupportedRulesVersion(99))
        }

        var missingRulesVersion = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        missingRulesVersion.removeValue(forKey: "rulesVersion")
        let missingRulesData = try JSONSerialization.data(withJSONObject: missingRulesVersion)
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetHoldemHandLabState.self, from: missingRulesData)) {
            XCTAssertEqual($0 as? PrismetHoldemHandLabStateValidationError, .unsupportedRulesVersion(-1))
        }
    }

    private func cards(_ ranks: PrismetCardRank..., suit: PrismetCardSuit) -> [PrismetPlayingCard] {
        ranks.map { card($0, suit) }
    }

    private func card(_ rank: PrismetCardRank, _ suit: PrismetCardSuit) -> PrismetPlayingCard {
        PrismetPlayingCard(rank: rank, suit: suit)
    }
}
