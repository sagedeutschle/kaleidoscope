import XCTest
@testable import PrismetShared

final class PrismetCasinoWarLabTests: XCTestCase {
    func testDealIsDeterministicAndDealsLearnerBeforeReference() throws {
        let first = try PrismetCasinoWarLab.deal(seed: 0xCA51_0052)
        let replay = try PrismetCasinoWarLab.deal(seed: 0xCA51_0052)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.auditHistory, [.dealt(seed: first.seed)])
        XCTAssertEqual(first.rulesVersion, 1)
        XCTAssertEqual(first.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
    }

    func testNonTieIsImmediatelyTerminalAndComparesRankOnly() throws {
        let state = try fixture(initialLearner: .ace, initialReference: .king)

        XCTAssertEqual(state.phase, .complete)
        XCTAssertEqual(state.outcome, .learnerHigher)
        XCTAssertEqual(state.cardsConsumed, 2)
        XCTAssertThrowsError(try PrismetCasinoWarLab.revealWar(in: state)) {
            XCTAssertEqual($0 as? PrismetCasinoWarLabError, .invalidPhase(.complete))
        }
    }

    func testTieRevealRedactsHiddenCardsConsumesTenCardsAndIsTerminal() throws {
        let deal = try tieFixture()
        XCTAssertEqual(deal.phase, .warReady)
        XCTAssertEqual(deal.outcome, nil)
        XCTAssertEqual(deal.cardsConsumed, 2)
        XCTAssertEqual(deal.auditHistory, [.dealt(seed: deal.seed)])
        XCTAssertTrue(deal.learnerWarCards.allSatisfy { $0.card == nil })
        XCTAssertTrue(deal.referenceWarCards.allSatisfy { $0.card == nil })

        let revealed = try PrismetCasinoWarLab.revealWar(in: deal)
        XCTAssertEqual(revealed.phase, .complete)
        XCTAssertEqual(revealed.cardsConsumed, 10)
        XCTAssertEqual(revealed.learnerWarCards.filter { $0.card == nil }.count, 3)
        XCTAssertEqual(revealed.referenceWarCards.filter { $0.card == nil }.count, 3)
        XCTAssertNotNil(revealed.learnerWarCards.last?.card)
        XCTAssertNotNil(revealed.referenceWarCards.last?.card)
        XCTAssertEqual(revealed.auditHistory.count, 2)
        XCTAssertThrowsError(try PrismetCasinoWarLab.revealWar(in: revealed)) {
            XCTAssertEqual($0 as? PrismetCasinoWarLabError, .invalidPhase(.complete))
        }
    }

    func testRevealIsReplayableAndSecondEqualityIsNeutralWithoutRecursion() throws {
        let tie = try warTieFixture()
        let replay = try PrismetCasinoWarLab.revealWar(in: tie)
        XCTAssertEqual(replay, try PrismetCasinoWarLab.revealWar(in: tie))
        XCTAssertEqual(replay.outcome, .neutral)
        XCTAssertEqual(replay.cardsConsumed, 10)
        XCTAssertEqual(replay.auditHistory, [.dealt(seed: tie.seed), .revealWar(seed: tie.seed)])

        XCTAssertThrowsError(try PrismetCasinoWarLab.revealWar(in: replay)) {
            XCTAssertEqual($0 as? PrismetCasinoWarLabError, .invalidPhase(.complete))
        }
    }

    func testCodableRoundTripPreservesAuditedTerminalState() throws {
        let state = try PrismetCasinoWarLab.revealWar(in: tieFixture())
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(PrismetCasinoWarLabState.self, from: data), state)
    }

    func testInvalidDecodeStateIsRejected() throws {
        var object = try jsonObject(try tieFixture())
        object["cursor"] = 9
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetCasinoWarLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetCasinoWarLabStateValidationError, .invalidCursor(expected: 2, actual: 9))
        }
    }

    func testCodableValidationRequiresWarReadyForAnUnrevealedTie() throws {
        var object = try jsonObject(tieFixture())
        object["phase"] = PrismetCasinoWarLabPhase.dealt.rawValue
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertThrowsError(try JSONDecoder().decode(PrismetCasinoWarLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetCasinoWarLabStateValidationError, .invalidPhase)
        }
    }

    func testCodableValidationRejectsRevealAuditForANonTie() throws {
        var object = try jsonObject(try fixture(initialLearner: .ace, initialReference: .king))
        object["auditHistory"] = [
            ["action": PrismetCasinoWarAuditAction.dealt.rawValue, "seed": object["seed"] as Any, "randomizerVersion": PrismetDeterministicRandom.algorithmVersion],
            ["action": PrismetCasinoWarAuditAction.revealWar.rawValue, "seed": object["seed"] as Any, "randomizerVersion": PrismetDeterministicRandom.algorithmVersion]
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertThrowsError(try JSONDecoder().decode(PrismetCasinoWarLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetCasinoWarLabStateValidationError, .invalidAuditHistory)
        }
    }

    func testExactOutcomeFrequenciesArePublished() {
        XCTAssertEqual(PrismetCasinoWarLab.exactOutcomeCounts[.learnerHigher], 10_376)
        XCTAssertEqual(PrismetCasinoWarLab.exactOutcomeCounts[.referenceHigher], 10_376)
        XCTAssertEqual(PrismetCasinoWarLab.exactOutcomeCounts[.neutral], 73)
        XCTAssertEqual(PrismetCasinoWarLab.exactOutcomeSampleCount, 20_825)
    }

    private func tieFixture() throws -> PrismetCasinoWarLabState {
        for seed in UInt64(0)..<100_000 {
            let state = try PrismetCasinoWarLab.deal(seed: seed)
            if state.learnerCard.rank == state.referenceCard.rank {
                return state
            }
        }
        throw FixtureError.notFound
    }

    private func warTieFixture() throws -> PrismetCasinoWarLabState {
        for seed in UInt64(0)..<100_000 {
            let state = try PrismetCasinoWarLab.deal(seed: seed)
            guard state.phase == .warReady else { continue }
            let revealed = try PrismetCasinoWarLab.revealWar(in: state)
            if revealed.outcome == .neutral {
                return state
            }
        }
        throw FixtureError.notFound
    }

    private func fixture(initialLearner: PrismetCardRank, initialReference: PrismetCardRank) throws -> PrismetCasinoWarLabState {
        for seed in UInt64(0)..<100_000 {
            let state = try PrismetCasinoWarLab.deal(seed: seed)
            if state.learnerCard.rank == initialLearner, state.referenceCard.rank == initialReference {
                return state
            }
        }
        throw FixtureError.notFound
    }

    private enum FixtureError: Error { case notFound }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
}
