import Foundation
import XCTest
@testable import PrismetShared

final class PrismetMiniBaccaratLabTests: XCTestCase {
    func testDealtStatePublishesCurrentRulesAndRandomizerVersions() throws {
        let state = try PrismetMiniBaccaratLabEngine.deal(seed: 42)

        XCTAssertEqual(state.rulesVersion, PrismetMiniBaccaratLabState.rulesVersion)
        XCTAssertEqual(state.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
    }

    func testFreshShoeHas416UniqueIdentifiersAndRequiredValueComposition() throws {
        let shoe = try PrismetMiniBaccaratLabEngine.freshShoe(seed: 42)

        XCTAssertEqual(shoe.count, 416)
        XCTAssertEqual(Set(shoe.map(\.id)).count, 416)
        XCTAssertEqual(Dictionary(grouping: shoe, by: \.value).mapValues(\.count), [
            0: 128, 1: 32, 2: 32, 3: 32, 4: 32, 5: 32, 6: 32, 7: 32, 8: 32, 9: 32,
        ])
        XCTAssertEqual(shoe, try PrismetMiniBaccaratLabEngine.freshShoe(seed: 42))
        XCTAssertNotEqual(shoe, try PrismetMiniBaccaratLabEngine.freshShoe(seed: 43))
    }

    func testPublishedOutcomeCountsAreExclusiveAndSumToFreshEightDeckDenominator() {
        let counts = Dictionary(
            uniqueKeysWithValues: PrismetMiniBaccaratLabEngine.exactOutcomeCounts.map { ($0.outcome, $0.count) }
        )

        XCTAssertEqual(counts, [
            .banker: 2_292_252_566_437_888,
            .player: 2_230_518_282_592_256,
            .tie: 475_627_426_473_216,
        ])
        XCTAssertEqual(counts.values.reduce(0, +), PrismetMiniBaccaratLabEngine.exactOutcomeDenominator)
        XCTAssertEqual(PrismetMiniBaccaratLabEngine.exactOutcomeDenominator, 4_998_398_275_503_360)
    }

    func testDealAndExplicitAdvancesFollowTypedLifecycle() throws {
        let initial = try PrismetMiniBaccaratLabEngine.deal(seed: 91)
        XCTAssertEqual(initial.phase, .initialDeal)
        XCTAssertEqual(initial.playerCards.count, 2)
        XCTAssertEqual(initial.bankerCards.count, 2)
        XCTAssertNil(initial.outcome)

        let playerTableau = try PrismetMiniBaccaratLabEngine.advance(initial)
        XCTAssertEqual(playerTableau.phase, .playerTableau)
        let bankerTableau = try PrismetMiniBaccaratLabEngine.advance(playerTableau)
        XCTAssertEqual(bankerTableau.phase, .bankerTableau)
        let complete = try PrismetMiniBaccaratLabEngine.advance(bankerTableau)
        XCTAssertEqual(complete.phase, .complete)
        XCTAssertNotNil(complete.outcome)
    }

    func testNaturalCompletesFromInitialDealWithoutTableauCards() throws {
        let natural = try state(from: { state in
            PrismetMiniBaccaratLabEngine.isNatural(total: state.playerTotal)
                || PrismetMiniBaccaratLabEngine.isNatural(total: state.bankerTotal)
        })

        let complete = try PrismetMiniBaccaratLabEngine.advance(natural)
        XCTAssertEqual(complete.phase, .complete)
        XCTAssertEqual(complete.playerCards.count, 2)
        XCTAssertEqual(complete.bankerCards.count, 2)
        XCTAssertNotNil(complete.outcome)
    }

    func testPlayerTableauStandsOnSixOrSevenAndDrawsOnZeroThroughFive() {
        for total in 0...9 {
            XCTAssertEqual(PrismetMiniBaccaratLabEngine.playerShouldDraw(total: total), total <= 5)
        }
    }

    func testBankerTableauCoversEveryStandardThirdCardCondition() {
        for playerThirdCard in 0...9 {
            XCTAssertTrue(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 0, playerThirdCardValue: playerThirdCard))
            XCTAssertTrue(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 1, playerThirdCardValue: playerThirdCard))
            XCTAssertTrue(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 2, playerThirdCardValue: playerThirdCard))
            XCTAssertEqual(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 3, playerThirdCardValue: playerThirdCard), playerThirdCard != 8)
            XCTAssertEqual(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 4, playerThirdCardValue: playerThirdCard), (2...7).contains(playerThirdCard))
            XCTAssertEqual(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 5, playerThirdCardValue: playerThirdCard), (4...7).contains(playerThirdCard))
            XCTAssertEqual(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 6, playerThirdCardValue: playerThirdCard), playerThirdCard == 6 || playerThirdCard == 7)
            XCTAssertFalse(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: 7, playerThirdCardValue: playerThirdCard))
        }
        for bankerTotal in 0...7 {
            XCTAssertEqual(PrismetMiniBaccaratLabEngine.bankerShouldDraw(bankerTotal: bankerTotal, playerThirdCardValue: nil), bankerTotal <= 5)
        }
    }

    func testAdvancingUsesAutomaticPlayerAndBankerTableauRules() throws {
        let playerDraw = try state(from: { state in
            !PrismetMiniBaccaratLabEngine.isNatural(total: state.playerTotal)
                && !PrismetMiniBaccaratLabEngine.isNatural(total: state.bankerTotal)
                && state.playerTotal <= 5
        })
        let afterPlayer = try PrismetMiniBaccaratLabEngine.advance(playerDraw)
        XCTAssertEqual(afterPlayer.playerCards.count, 3)

        let playerStand = try state(from: { state in
            !PrismetMiniBaccaratLabEngine.isNatural(total: state.playerTotal)
                && !PrismetMiniBaccaratLabEngine.isNatural(total: state.bankerTotal)
                && state.playerTotal >= 6
        })
        XCTAssertEqual(try PrismetMiniBaccaratLabEngine.advance(playerStand).playerCards.count, 2)
    }

    func testDeckConservationHoldsAcrossAllPhases() throws {
        let initial = try PrismetMiniBaccaratLabEngine.deal(seed: 44)
        let states = try advancingToCompletion(from: initial)

        for state in states {
            XCTAssertEqual(state.shoeCardCount, 416)
            XCTAssertEqual(state.remainingShoeCardCount + state.cardsDealt.count, 416)
            XCTAssertEqual(Set(state.cardsDealt.map(\.id)).count, state.cardsDealt.count)
        }
    }

    func testSameSeedAndActionsReplayIdentically() throws {
        let first = try advancingToCompletion(from: PrismetMiniBaccaratLabEngine.deal(seed: 0xBA_CA_0001))
        let replay = try advancingToCompletion(from: PrismetMiniBaccaratLabEngine.deal(seed: 0xBA_CA_0001))
        XCTAssertEqual(first, replay)
    }

    func testInvalidActionsReturnExactPhaseErrors() throws {
        let ready = PrismetMiniBaccaratLabState.ready
        XCTAssertThrowsError(try PrismetMiniBaccaratLabEngine.advance(ready)) {
            XCTAssertEqual($0 as? PrismetMiniBaccaratLabEngineError, .invalidPhase(.ready))
        }

        let complete = try XCTUnwrap(
            advancingToCompletion(from: PrismetMiniBaccaratLabEngine.deal(seed: 9)).last
        )
        XCTAssertThrowsError(try PrismetMiniBaccaratLabEngine.advance(complete)) {
            XCTAssertEqual($0 as? PrismetMiniBaccaratLabEngineError, .invalidPhase(.complete))
        }
    }

    func testValidCodableRoundTripPreservesContinuation() throws {
        let initial = try PrismetMiniBaccaratLabEngine.deal(seed: 80_085)
        let restored = try JSONDecoder().decode(
            PrismetMiniBaccaratLabState.self,
            from: JSONEncoder().encode(initial)
        )

        XCTAssertEqual(restored, initial)
        XCTAssertEqual(
            try advancingToCompletion(from: restored),
            try advancingToCompletion(from: initial)
        )
    }

    func testCodableRejectsTamperedShoeAndInconsistentTableauHistory() throws {
        let initial = try PrismetMiniBaccaratLabEngine.deal(seed: 91)
        let encodedState = try encodedObject(for: initial)
        XCTAssertEqual(encodedState["rulesVersion"] as? Int, PrismetMiniBaccaratLabState.rulesVersion)

        try assertStateDecodingRejected(initial, equals: .unsupportedRulesVersion(99)) {
            $0["rulesVersion"] = 99
        }
        try assertStateDecodingRejected(initial, equals: .unsupportedRulesVersion(-1)) {
            $0.removeValue(forKey: "rulesVersion")
        }

        try assertStateDecodingRejected(initial, equals: .invalidShoeComposition) { object in
            var shoe = try XCTUnwrap(object["shuffledShoe"] as? [[String: Any]])
            shoe.removeLast()
            object["shuffledShoe"] = shoe
        }
        try assertStateDecodingRejected(initial, equals: .shuffledShoeMismatch) { object in
            var shoe = try XCTUnwrap(object["shuffledShoe"] as? [[String: Any]])
            shoe.swapAt(0, 1)
            object["shuffledShoe"] = shoe
        }
        try assertStateDecodingRejected(initial, equals: .cardsDoNotMatchDealHistory) { object in
            var playerCards = try XCTUnwrap(object["playerCards"] as? [[String: Any]])
            playerCards.swapAt(0, 1)
            object["playerCards"] = playerCards
        }

        let natural = try state(from: { state in
            PrismetMiniBaccaratLabEngine.isNatural(total: state.playerTotal)
                || PrismetMiniBaccaratLabEngine.isNatural(total: state.bankerTotal)
        })
        try assertStateDecodingRejected(natural, equals: .invalidPhaseForDealHistory(.playerTableau)) {
            $0["phase"] = PrismetMiniBaccaratPhase.playerTableau.rawValue
        }
    }

    private func state(from predicate: (PrismetMiniBaccaratLabState) -> Bool) throws -> PrismetMiniBaccaratLabState {
        for seed in 0..<10_000 {
            let state = try PrismetMiniBaccaratLabEngine.deal(seed: UInt64(seed))
            if predicate(state) { return state }
        }
        XCTFail("Expected to find a deterministic fixture seed")
        throw FixtureError.notFound
    }

    private func advancingToCompletion(
        from initial: PrismetMiniBaccaratLabState
    ) throws -> [PrismetMiniBaccaratLabState] {
        var states = [initial]
        while let current = states.last, current.phase != .complete {
            states.append(try PrismetMiniBaccaratLabEngine.advance(current))
        }
        return states
    }

    private func encodedObject(for state: PrismetMiniBaccaratLabState) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    }

    private func assertStateDecodingRejected(
        _ state: PrismetMiniBaccaratLabState,
        equals expected: PrismetMiniBaccaratLabStateValidationError,
        mutate: (inout [String: Any]) throws -> Void
    ) throws {
        var object = try encodedObject(for: state)
        try mutate(&object)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetMiniBaccaratLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetMiniBaccaratLabStateValidationError, expected)
        }
    }

    private enum FixtureError: Error { case notFound }
}
