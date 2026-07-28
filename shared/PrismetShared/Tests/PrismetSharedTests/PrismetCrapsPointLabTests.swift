import Foundation
import XCTest
@testable import PrismetShared

final class PrismetCrapsPointLabTests: XCTestCase {
    func testComeOutDisclosuresAndExhaustiveThirtySixPairClassificationAreExact() {
        XCTAssertEqual(
            PrismetCrapsPointLabEngine.comeOutDisclosures,
            [
                .init(observation: "Natural", favorableCount: 8, totalCount: 36),
                .init(observation: "Craps", favorableCount: 4, totalCount: 36),
                .init(observation: "Point", favorableCount: 24, totalCount: 36),
            ]
        )

        var counts: [PrismetCrapsPointLabComeOut: Int] = [:]
        for first in 1...6 {
            for second in 1...6 {
                let outcome = PrismetCrapsPointLabEngine.classifyComeOut(
                    .init(first: first, second: second)
                )
                counts[outcome, default: 0] += 1
            }
        }
        XCTAssertEqual(counts[.natural], 8)
        XCTAssertEqual(counts[.craps], 4)
        XCTAssertEqual(counts[.point(4)], 3)
        XCTAssertEqual(counts[.point(5)], 4)
        XCTAssertEqual(counts[.point(6)], 5)
        XCTAssertEqual(counts[.point(8)], 5)
        XCTAssertEqual(counts[.point(9)], 4)
        XCTAssertEqual(counts[.point(10)], 3)
        XCTAssertEqual(counts.values.reduce(0, +), 36)
    }

    func testPointVersusSevenDisclosuresAreExact() {
        let expected = [
            PrismetCrapsPointLabPointResolutionDisclosure(point: 4, pointCount: 3, sevenCount: 6),
            .init(point: 5, pointCount: 4, sevenCount: 6),
            .init(point: 6, pointCount: 5, sevenCount: 6),
            .init(point: 8, pointCount: 5, sevenCount: 6),
            .init(point: 9, pointCount: 4, sevenCount: 6),
            .init(point: 10, pointCount: 3, sevenCount: 6),
        ]
        XCTAssertEqual(PrismetCrapsPointLabEngine.pointResolutionDisclosures, expected)

        for disclosure in expected {
            let pointCount = (1...6).reduce(0) { partial, first in
                partial + (1...6).filter { first + $0 == disclosure.point }.count
            }
            let sevenCount = (1...6).reduce(0) { partial, first in
                partial + (1...6).filter { first + $0 == 7 }.count
            }
            XCTAssertEqual(pointCount, disclosure.pointCount)
            XCTAssertEqual(sevenCount, disclosure.sevenCount)
        }
    }

    func testExplicitSeededRollsReplayAndRetainAnImmutablePointAndAuditHistory() throws {
        let established = try state(from: .ready) { $0.phase == .point }
        let point = try XCTUnwrap(established.point)
        let continued = try PrismetCrapsPointLabEngine.roll(seed: 99, in: established)

        XCTAssertEqual(continued.point, point)
        XCTAssertEqual(continued.audit.rulesVersion, PrismetCrapsPointLabState.rulesVersion)
        XCTAssertEqual(continued.audit.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
        XCTAssertEqual(continued.history.count, 2)
        XCTAssertEqual(continued.history.map(\.seed), [established.history[0].seed, 99])
        XCTAssertEqual(
            continued,
            try PrismetCrapsPointLabEngine.roll(
                seed: 99,
                in: try PrismetCrapsPointLabEngine.roll(seed: established.history[0].seed, in: .ready)
            )
        )
        XCTAssertTrue(continued.observation.range(of: "observe", options: .caseInsensitive) != nil)
    }

    func testTerminalCompletionRejectsFurtherRollsWithTypedPhaseError() throws {
        let complete = try state(from: .ready) { $0.phase == .complete }
        XCTAssertThrowsError(try PrismetCrapsPointLabEngine.roll(seed: 1, in: complete)) {
            XCTAssertEqual($0 as? PrismetCrapsPointLabEngineError, .invalidPhase(.complete))
        }
    }

    func testReadyStateIsCodableAndMalformedCanonicalStateIsRejected() throws {
        XCTAssertEqual(
            try JSONDecoder().decode(
                PrismetCrapsPointLabState.self,
                from: JSONEncoder().encode(PrismetCrapsPointLabState.ready)
            ),
            .ready
        )

        let state = try PrismetCrapsPointLabEngine.roll(seed: 42, in: .ready)
        var object = try encodedObject(state)
        object["phase"] = PrismetCrapsPointLabPhase.complete.rawValue
        let malformed = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetCrapsPointLabState.self, from: malformed)) {
            XCTAssertEqual($0 as? PrismetCrapsPointLabStateValidationError, .invalidCanonicalState)
        }
    }

    private func state(
        from initial: PrismetCrapsPointLabState,
        matching predicate: (PrismetCrapsPointLabState) -> Bool
    ) throws -> PrismetCrapsPointLabState {
        for seed in 0..<10_000 {
            let candidate = try PrismetCrapsPointLabEngine.roll(seed: UInt64(seed), in: initial)
            if predicate(candidate) { return candidate }
        }
        XCTFail("Expected a deterministic fixture")
        throw FixtureError.notFound
    }

    private func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    private enum FixtureError: Error { case notFound }
}
