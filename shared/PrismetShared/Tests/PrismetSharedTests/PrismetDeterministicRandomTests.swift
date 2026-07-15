import XCTest
@testable import PrismetShared

final class PrismetDeterministicRandomTests: XCTestCase {
    func testSplitMix64VersionAndFixture() {
        XCTAssertEqual(PrismetDeterministicRandom.algorithmVersion, 1)
        var rng = PrismetDeterministicRandom(seed: 0x123456789ABCDEF0)
        XCTAssertEqual((0..<5).map { _ in rng.next() }, [
            1592342178222199016, 12499191764280245088, 3819614628928595213,
            4718850641434784223, 11074192720443766454
        ])
        XCTAssertEqual(rng.drawCount, 5)
    }

    func testSameSeedIsReproducibleAndDifferentSeedsDiverge() {
        var first = PrismetDeterministicRandom(seed: 42)
        var second = PrismetDeterministicRandom(seed: 42)
        var different = PrismetDeterministicRandom(seed: 43)

        let firstSequence = (0..<20).map { _ in first.next() }
        let secondSequence = (0..<20).map { _ in second.next() }
        let differentSequence = (0..<20).map { _ in different.next() }

        XCTAssertEqual(firstSequence, secondSequence)
        XCTAssertNotEqual(firstSequence, differentSequence)
        XCTAssertEqual(first.state, second.state)
        XCTAssertEqual(first.drawCount, 20)
        XCTAssertEqual(second.drawCount, 20)
        XCTAssertEqual(different.drawCount, 20)
    }

    func testStateAlwaysMatchesSeedPlusIncrementTimesDrawCount() {
        let increment: UInt64 = 0x9E3779B97F4A7C15
        let seed = UInt64.max - 3
        var rng = PrismetDeterministicRandom(seed: seed)

        for expectedDrawCount in UInt64(1)...128 {
            _ = rng.next()

            XCTAssertEqual(rng.drawCount, expectedDrawCount)
            XCTAssertEqual(rng.state, seed &+ (increment &* expectedDrawCount))
        }
    }

    func testInvalidBoundsDoNotConsumeRandomWords() {
        var rng = PrismetDeterministicRandom(seed: 42)

        XCTAssertThrowsError(try rng.next(upperBound: 0)) { error in
            XCTAssertEqual(error as? PrismetDeterministicRandomError, .invalidUpperBound(0))
        }
        XCTAssertThrowsError(try rng.nextInt(upperBound: 0)) { error in
            XCTAssertEqual(error as? PrismetDeterministicRandomError, .invalidUpperBound(0))
        }
        XCTAssertThrowsError(try rng.nextInt(upperBound: -1)) { error in
            XCTAssertEqual(error as? PrismetDeterministicRandomError, .invalidUpperBound(-1))
        }
        XCTAssertEqual(rng.drawCount, 0)
    }

    func testBoundedDrawRejectsLowBiasedWord() throws {
        var rng = PrismetDeterministicRandom(seed: 3)

        let value = try rng.next(upperBound: 9_223_372_036_854_775_809)

        XCTAssertEqual(value, 3_694_763_184_872_335_752)
        XCTAssertEqual(rng.drawCount, 2)
    }

    func testFisherYatesShuffleHasStableFixtureAndNoTrivialDraws() throws {
        let original = Array(0...9)
        var values = original
        var matchingValues = original
        var rng = PrismetDeterministicRandom(seed: 42)
        var matchingRNG = PrismetDeterministicRandom(seed: 42)

        try rng.shuffle(&values)
        try matchingRNG.shuffle(&matchingValues)

        XCTAssertEqual(values, [0, 9, 5, 8, 6, 4, 7, 2, 1, 3])
        XCTAssertEqual(values, matchingValues)
        XCTAssertEqual(values.sorted(), original)
        XCTAssertEqual(rng.drawCount, 9)
        XCTAssertEqual(matchingRNG.drawCount, 9)

        var empty: [Int] = []
        var one = [1]
        var trivial = PrismetDeterministicRandom(seed: 99)
        try trivial.shuffle(&empty)
        try trivial.shuffle(&one)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(one, [1])
        XCTAssertEqual(trivial.drawCount, 0)
    }

    func testCodableRoundTripContinuesAtTheSameWord() throws {
        var original = PrismetDeterministicRandom(seed: 7)
        _ = original.next()
        _ = original.next()
        let data = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(PrismetDeterministicRandom.self, from: data)

        XCTAssertEqual(original.next(), restored.next())
        XCTAssertEqual(original.drawCount, restored.drawCount)
    }

    func testDecodingRejectsStateThatDoesNotMatchSeedAndDrawCount() throws {
        let impossible = try JSONSerialization.data(withJSONObject: [
            "seed": UInt64(7),
            "state": UInt64(7),
            "drawCount": UInt64(2)
        ])

        XCTAssertThrowsError(
            try JSONDecoder().decode(PrismetDeterministicRandom.self, from: impossible)
        ) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
        }
    }
}
