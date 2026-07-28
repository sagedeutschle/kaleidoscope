import Foundation
import XCTest
@testable import PrismetShared

final class PrismetSicBoOutcomeLabTests: XCTestCase {
    func testAllTwoHundredSixteenOrderedTriplesHavePublishedTotalsAndPatterns() throws {
        var totalCounts = Array(repeating: 0, count: 16)
        var patternCounts: [PrismetSicBoPattern: Int] = [:]

        for first in 1...6 {
            for second in 1...6 {
                for third in 1...6 {
                    let outcome = try PrismetSicBoOutcome(dice: [first, second, third])
                    totalCounts[outcome.total - 3] += 1
                    patternCounts[outcome.pattern, default: 0] += 1
                }
            }
        }

        XCTAssertEqual(totalCounts, [1, 3, 6, 10, 15, 21, 25, 27, 27, 25, 21, 15, 10, 6, 3, 1])
        XCTAssertEqual(patternCounts, [.allDistinct: 120, .onePair: 90, .triple: 6])
        XCTAssertEqual(PrismetSicBoOutcomeLab.exactTotalCounts, totalCounts)
        XCTAssertEqual(PrismetSicBoOutcomeLab.exactPatternCounts, patternCounts)
        XCTAssertEqual(totalCounts.reduce(0, +), 216)
        XCTAssertEqual(patternCounts.values.reduce(0, +), 216)
    }

    func testRollIsSeededFairAndReplayable() throws {
        let ready = PrismetSicBoOutcomeLabState.ready
        let rolled = try PrismetSicBoOutcomeLab.roll(ready, seed: 0x51C_B0)

        XCTAssertEqual(rolled, try PrismetSicBoOutcomeLab.roll(.ready, seed: 0x51C_B0))
        XCTAssertEqual(rolled.phase, .complete)
        XCTAssertEqual(rolled.dice.count, 3)
        XCTAssertTrue(rolled.dice.allSatisfy { (1...6).contains($0) })
        XCTAssertEqual(rolled.total, rolled.dice.reduce(0, +))
        XCTAssertEqual(rolled.pattern, try PrismetSicBoPattern.classify(rolled.dice))
        XCTAssertEqual(rolled.seed, 0x51C_B0)
        XCTAssertEqual(rolled.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
        XCTAssertEqual(rolled.history, [.init(sequence: 1, action: .roll, seed: 0x51C_B0)])
        XCTAssertNotEqual(rolled, try PrismetSicBoOutcomeLab.roll(.ready, seed: 0x51C_B1))
    }

    func testOnlyTheReadyPhaseAcceptsTheExplicitRollAction() throws {
        let complete = try PrismetSicBoOutcomeLab.roll(.ready, seed: 7)

        XCTAssertThrowsError(try PrismetSicBoOutcomeLab.roll(complete, seed: 8)) {
            XCTAssertEqual($0 as? PrismetSicBoOutcomeLabError, .invalidPhase(.complete))
        }
    }

    func testInvalidDiceAreTypedErrors() {
        XCTAssertThrowsError(try PrismetSicBoOutcome(dice: [1, 2])) {
            XCTAssertEqual($0 as? PrismetSicBoOutcomeLabError, .invalidDice([1, 2]))
        }
        XCTAssertThrowsError(try PrismetSicBoOutcome(dice: [1, 2, 7])) {
            XCTAssertEqual($0 as? PrismetSicBoOutcomeLabError, .invalidDice([1, 2, 7]))
        }
    }

    func testCodableRoundTripAndTamperRejectionPreserveCanonicalDecklessState() throws {
        let state = try PrismetSicBoOutcomeLab.roll(.ready, seed: 0xD1CE)
        XCTAssertEqual(
            try JSONDecoder().decode(PrismetSicBoOutcomeLabState.self, from: JSONEncoder().encode(state)),
            state
        )

        let alteredTotal = try XCTUnwrap(state.total) + 1
        try assertStateDecodingRejected(state, equals: .diceMismatch) { $0["dice"] = [7, 7, 7] }
        try assertStateDecodingRejected(state, equals: .totalMismatch) { $0["total"] = alteredTotal }
        let alteredPattern: PrismetSicBoPattern = state.pattern == .triple ? .onePair : .triple
        try assertStateDecodingRejected(state, equals: .patternMismatch) { $0["pattern"] = alteredPattern.rawValue }
        try assertStateDecodingRejected(state, equals: .invalidHistory) { $0["history"] = [] }
        try assertStateDecodingRejected(state, equals: .unsupportedRulesVersion(99)) { $0["rulesVersion"] = 99 }
        try assertStateDecodingRejected(state, equals: .unsupportedRandomizerVersion(99)) { $0["randomizerVersion"] = 99 }
    }

    func testReadyStateRejectsInjectedOutcomeFields() throws {
        var object = try encodedObject(for: .ready)
        object["seed"] = 1
        object["dice"] = [1, 2, 3]
        object["total"] = 6
        object["pattern"] = PrismetSicBoPattern.allDistinct.rawValue
        object["history"] = [["sequence": 1, "action": PrismetSicBoAuditAction.roll.rawValue, "seed": 1]]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertThrowsError(try JSONDecoder().decode(PrismetSicBoOutcomeLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetSicBoOutcomeLabStateValidationError, .invalidReadyState)
        }
    }

    func testSourceUsesObservationOnlyLanguage() throws {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let source = testDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrismetShared/PrismetSicBoOutcomeLab.swift")
        let text = try String(contentsOf: source, encoding: .utf8).lowercased()
        let prohibited = ["mon" + "ey", "wag" + "er", "ch" + "ip", "pay" + "out", "pr" + "ize", "rew" + "ard", "cash" + "out", "purch" + "ase", "tim" + "er", "near" + " miss"]

        for term in prohibited {
            XCTAssertFalse(text.contains(term), "Unexpected non-observation term: \(term)")
        }
    }

    private func encodedObject(for state: PrismetSicBoOutcomeLabState) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    }

    private func assertStateDecodingRejected(
        _ state: PrismetSicBoOutcomeLabState,
        equals expected: PrismetSicBoOutcomeLabStateValidationError,
        mutate: (inout [String: Any]) -> Void
    ) throws {
        var object = try encodedObject(for: state)
        mutate(&object)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetSicBoOutcomeLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetSicBoOutcomeLabStateValidationError, expected)
        }
    }
}
