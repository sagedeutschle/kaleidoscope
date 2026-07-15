import Foundation
import XCTest
@testable import PrismetShared

final class PrismetOmahaHandLabTests: XCTestCase {
    func testDealIsDeterministicAndRedactsUndealtCards() throws {
        let first = try PrismetOmahaHandLab.deal(seed: 42)
        let second = try PrismetOmahaHandLab.deal(seed: 42)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.rulesVersion, PrismetOmahaHandLabState.rulesVersion)
        XCTAssertEqual(first.phase, .holeCards)
        XCTAssertEqual(first.holeCards.count, 4)
        XCTAssertEqual(first.visibleBoard, [])
        XCTAssertEqual(first.visibleCards.count, 4)
        XCTAssertEqual(first.burnedCards.count, 0)
        XCTAssertEqual(first.remainingDeckCount, 48)
        XCTAssertEqual(first.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
        XCTAssertEqual(first.candidateCount, 0)
        XCTAssertFalse(first.redactedDescription.contains("shuffledDeck"))
    }

    func testStateSupportsHashableAndEncodesBothVersionContracts() throws {
        let state = try PrismetOmahaHandLab.deal(seed: 42)
        let set: Set<PrismetOmahaHandLabState> = [state]
        XCTAssertEqual(set.count, 1)

        let object = try jsonObject(state)
        XCTAssertEqual(object["rulesVersion"] as? Int, PrismetOmahaHandLabState.rulesVersion)
        XCTAssertEqual(object["randomizerVersion"] as? Int, PrismetDeterministicRandom.algorithmVersion)
    }

    func testStreetActionsBurnAndConserveTheCanonicalDeck() throws {
        let dealt = try PrismetOmahaHandLab.deal(seed: 7)
        let flop = try PrismetOmahaHandLab.revealFlop(in: dealt)
        let turn = try PrismetOmahaHandLab.revealTurn(in: flop)
        let river = try PrismetOmahaHandLab.revealRiver(in: turn)

        XCTAssertEqual(flop.phase, .flop)
        XCTAssertEqual(flop.visibleBoard.count, 3)
        XCTAssertEqual(flop.burnedCards.count, 1)
        XCTAssertEqual(flop.remainingDeckCount, 44)
        XCTAssertEqual(turn.phase, .turn)
        XCTAssertEqual(turn.visibleBoard.count, 4)
        XCTAssertEqual(turn.burnedCards.count, 2)
        XCTAssertEqual(turn.remainingDeckCount, 42)
        XCTAssertEqual(river.phase, .river)
        XCTAssertEqual(river.visibleBoard.count, 5)
        XCTAssertEqual(river.burnedCards.count, 3)
        XCTAssertEqual(river.remainingDeckCount, 40)
        XCTAssertEqual(Set(river.holeCards + river.visibleBoard + river.burnedCards).count, 12)
        XCTAssertEqual(river.visibleCards.count, 9)
        XCTAssertEqual(river.candidateCount, 0)
    }

    func testClassifyUsesExactlyTwoHoleAndThreeBoardCards() throws {
        let hole = [card(.ace, .spades), card(.ace, .hearts), card(.king, .clubs), card(.queen, .diamonds)]
        let board = [card(.ace, .clubs), card(.king, .diamonds), card(.king, .hearts), card(.two, .spades), card(.three, .clubs)]

        let result = try PrismetOmahaHandLab.classify(holeCards: hole, board: board)

        XCTAssertEqual(result.category, .fullHouse)
        XCTAssertEqual(result.evaluatedCandidateCount, 60)
        XCTAssertEqual(result.holeCardCount, 2)
        XCTAssertEqual(result.boardCardCount, 3)
    }

    func testCompletedDealClassifiesOnlyAfterExplicitAction() throws {
        var state = try PrismetOmahaHandLab.deal(seed: 91)
        state = try PrismetOmahaHandLab.revealRiver(in: try PrismetOmahaHandLab.revealTurn(in: try PrismetOmahaHandLab.revealFlop(in: state)))

        XCTAssertNil(state.classification)
        let classified = try PrismetOmahaHandLab.classify(state)
        XCTAssertEqual(classified.phase, .complete)
        XCTAssertNotNil(classified.classification)
        XCTAssertEqual(classified.candidateCount, 60)
        XCTAssertEqual(classified.classification?.category, try PrismetOmahaHandLab.classify(holeCards: classified.holeCards, board: classified.visibleBoard).category)
    }

    func testInvalidActionsDoNotMutateState() throws {
        let dealt = try PrismetOmahaHandLab.deal(seed: 1)
        XCTAssertThrowsError(try PrismetOmahaHandLab.revealTurn(in: dealt)) {
            XCTAssertEqual($0 as? PrismetOmahaHandLabError, .invalidPhase(.holeCards))
        }
        let flop = try PrismetOmahaHandLab.revealFlop(in: dealt)
        XCTAssertThrowsError(try PrismetOmahaHandLab.revealFlop(in: flop)) {
            XCTAssertEqual($0 as? PrismetOmahaHandLabError, .invalidPhase(.flop))
        }
        XCTAssertThrowsError(try PrismetOmahaHandLab.classify(flop)) {
            XCTAssertEqual($0 as? PrismetOmahaHandLabError, .invalidPhase(.flop))
        }
        XCTAssertEqual(dealt.phase, .holeCards)
        XCTAssertEqual(dealt.visibleBoard, [])
    }

    func testReplayAndCodableRoundTripPreserveContinuation() throws {
        let first = try PrismetOmahaHandLab.revealFlop(in: try PrismetOmahaHandLab.deal(seed: 0xCA51_0042))
        let restored = try JSONDecoder().decode(PrismetOmahaHandLabState.self, from: JSONEncoder().encode(first))
        XCTAssertEqual(restored, first)
        XCTAssertEqual(try PrismetOmahaHandLab.revealTurn(in: restored), try PrismetOmahaHandLab.revealTurn(in: first))
    }

    func testTamperedStateIsRejectedWithoutTrapping() throws {
        let state = try PrismetOmahaHandLab.deal(seed: 11)
        var object = try jsonObject(state)
        object["rulesVersion"] = PrismetOmahaHandLabState.rulesVersion + 1
        XCTAssertThrowsError(try decode(object)) {
            XCTAssertEqual($0 as? PrismetOmahaHandLabError, .unsupportedRulesVersion(PrismetOmahaHandLabState.rulesVersion + 1))
        }

        object = try jsonObject(state)
        object.removeValue(forKey: "rulesVersion")
        XCTAssertThrowsError(try decode(object))

        object = try jsonObject(state)
        object["randomizerVersion"] = PrismetDeterministicRandom.algorithmVersion + 1
        XCTAssertThrowsError(try decode(object)) {
            XCTAssertEqual($0 as? PrismetOmahaHandLabError, .unsupportedRandomizerVersion(PrismetDeterministicRandom.algorithmVersion + 1))
        }

        object = try jsonObject(state)
        object["seed"] = 12
        XCTAssertThrowsError(try decode(object))

        object = try jsonObject(state)
        object["drawIndex"] = 5
        XCTAssertThrowsError(try decode(object))

        object = try jsonObject(state)
        object["visibleBoard"] = [["rank": 14, "suit": "spades"]]
        XCTAssertThrowsError(try decode(object))
    }

    func testEveryPokerCategoryCanBeClassifiedThroughTheOmahaRule() throws {
        let cases: [(PrismetPokerCategory, [PrismetPlayingCard], [PrismetPlayingCard])] = [
            (.royalFlush, [card(.ace, .spades), card(.king, .spades), card(.two, .clubs), card(.three, .diamonds)], [card(.queen, .spades), card(.jack, .spades), card(.ten, .spades), card(.four, .hearts), card(.five, .clubs)]),
            (.straightFlush, [card(.nine, .spades), card(.eight, .spades), card(.two, .clubs), card(.three, .diamonds)], [card(.seven, .spades), card(.six, .spades), card(.five, .spades), card(.king, .hearts), card(.ace, .clubs)]),
            (.fourOfAKind, [card(.ace, .spades), card(.ace, .hearts), card(.two, .clubs), card(.three, .diamonds)], [card(.ace, .clubs), card(.ace, .diamonds), card(.king, .spades), card(.queen, .hearts), card(.jack, .clubs)]),
            (.fullHouse, [card(.ace, .spades), card(.ace, .hearts), card(.king, .clubs), card(.two, .diamonds)], [card(.ace, .clubs), card(.king, .diamonds), card(.king, .hearts), card(.three, .spades), card(.four, .clubs)]),
            (.flush, [card(.ace, .spades), card(.nine, .spades), card(.two, .clubs), card(.three, .diamonds)], [card(.seven, .spades), card(.four, .spades), card(.jack, .spades), card(.king, .hearts), card(.queen, .clubs)]),
            (.straight, [card(.ace, .spades), card(.two, .hearts), card(.king, .diamonds), card(.queen, .clubs)], [card(.three, .clubs), card(.four, .spades), card(.five, .hearts), card(.nine, .clubs), card(.jack, .clubs)]),
            (.threeOfAKind, [card(.ace, .spades), card(.ace, .hearts), card(.two, .clubs), card(.three, .diamonds)], [card(.ace, .clubs), card(.king, .diamonds), card(.queen, .hearts), card(.jack, .spades), card(.nine, .clubs)]),
            (.twoPair, [card(.ace, .spades), card(.ace, .hearts), card(.king, .clubs), card(.king, .diamonds)], [card(.two, .spades), card(.two, .hearts), card(.three, .clubs), card(.four, .diamonds), card(.five, .spades)]),
            (.onePair, [card(.ace, .spades), card(.ace, .hearts), card(.king, .clubs), card(.queen, .diamonds)], [card(.two, .spades), card(.three, .hearts), card(.four, .clubs), card(.five, .diamonds), card(.six, .spades)]),
            (.highCard, [card(.ace, .spades), card(.king, .hearts), card(.two, .clubs), card(.three, .diamonds)], [card(.nine, .spades), card(.seven, .hearts), card(.four, .clubs), card(.jack, .diamonds), card(.eight, .spades)])
        ]

        for (category, hole, board) in cases {
            XCTAssertEqual(try PrismetOmahaHandLab.classify(holeCards: hole, board: board).category, category)
        }
    }

    private func card(_ rank: PrismetCardRank, _ suit: PrismetCardSuit) -> PrismetPlayingCard {
        PrismetPlayingCard(rank: rank, suit: suit)
    }

    private func jsonObject(_ state: PrismetOmahaHandLabState) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> PrismetOmahaHandLabState {
        try JSONDecoder().decode(PrismetOmahaHandLabState.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
