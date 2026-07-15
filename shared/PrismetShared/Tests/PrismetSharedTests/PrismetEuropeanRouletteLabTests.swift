import XCTest
@testable import PrismetShared

final class PrismetEuropeanRouletteLabTests: XCTestCase {
    func testWheelIsTheOrderedSingleZeroWheel() {
        XCTAssertEqual(PrismetEuropeanRouletteLab.wheel, [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26])
    }

    func testSpinIsExplicitDeterministicAndReplayable() throws {
        let first = try PrismetEuropeanRouletteLab.spin(seed: 0xCAFE)
        let replay = try PrismetEuropeanRouletteLab.spin(seed: 0xCAFE)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.rulesVersion, 1)
        XCTAssertEqual(first.randomizerVersion, PrismetDeterministicRandom.algorithmVersion)
        XCTAssertEqual(first.seed, 0xCAFE)
        XCTAssertEqual(first.phase, .spun)
        guard let index = first.pocketIndex, let pocket = first.pocket else {
            XCTFail("A spun state must contain an observed pocket.")
            return
        }
        XCTAssertEqual(pocket, PrismetEuropeanRouletteLab.wheel[index])
        XCTAssertEqual(first.color, PrismetEuropeanRouletteLab.color(of: pocket))
        XCTAssertGreaterThanOrEqual(first.randomizerDrawCount, 1)
    }

    func testReadyStateAcceptsOneExplicitSpinAndSpinIsTerminal() throws {
        let ready = PrismetEuropeanRouletteLab.ready(seed: 7)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertNil(ready.pocket)
        XCTAssertEqual(try PrismetEuropeanRouletteLab.spin(in: ready), try PrismetEuropeanRouletteLab.spin(seed: 7))

        let spun = try PrismetEuropeanRouletteLab.spin(seed: 7)
        XCTAssertThrowsError(try PrismetEuropeanRouletteLab.spin(in: spun)) {
            XCTAssertEqual($0 as? PrismetEuropeanRouletteLabError, .invalidPhase(.spun))
        }
    }

    func testEveryPocketAndColorHasExactCombinatorialCount() {
        let red: Set<Int> = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
        XCTAssertEqual(PrismetEuropeanRouletteLab.wheel.count, PrismetEuropeanRouletteLab.exactPocketCount)
        XCTAssertEqual(Set(PrismetEuropeanRouletteLab.wheel).count, PrismetEuropeanRouletteLab.exactPocketCount)
        XCTAssertEqual(PrismetEuropeanRouletteLab.wheel.filter { PrismetEuropeanRouletteLab.color(of: $0) == .green }.count, PrismetEuropeanRouletteLab.exactZeroCount)
        XCTAssertEqual(PrismetEuropeanRouletteLab.wheel.filter { PrismetEuropeanRouletteLab.color(of: $0) == .red }.count, PrismetEuropeanRouletteLab.exactRedCount)
        XCTAssertEqual(PrismetEuropeanRouletteLab.wheel.filter { PrismetEuropeanRouletteLab.color(of: $0) == .black }.count, PrismetEuropeanRouletteLab.exactBlackCount)
        XCTAssertEqual(PrismetEuropeanRouletteLab.wheel.filter { red.contains($0) }.count, 18)
        XCTAssertEqual(PrismetEuropeanRouletteLab.redBlackDisclosure, "Red and black are not 50/50 because zero is neither.")
        XCTAssertNotEqual(PrismetEuropeanRouletteLab.exactRedCount * 2, PrismetEuropeanRouletteLab.exactPocketCount)
        XCTAssertEqual(PrismetEuropeanRouletteLab.color(of: 0), .green)
        XCTAssertEqual(PrismetEuropeanRouletteLab.color(of: 32), .red)
        XCTAssertEqual(PrismetEuropeanRouletteLab.color(of: 33), .black)
    }

    func testDecodeRejectsTamperedDerivedStateAndUnsupportedVersions() throws {
        let state = try PrismetEuropeanRouletteLab.spin(seed: 42)
        var object = try jsonObject(state)
        object["pocket"] = 0
        let tamperedPocket = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetEuropeanRouletteLabState.self, from: tamperedPocket)) {
            XCTAssertEqual($0 as? PrismetEuropeanRouletteLabStateValidationError, .invalidPocket)
        }

        var wrongVersion = try jsonObject(state)
        wrongVersion["rulesVersion"] = 99
        let versionData = try JSONSerialization.data(withJSONObject: wrongVersion)
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetEuropeanRouletteLabState.self, from: versionData)) {
            XCTAssertEqual($0 as? PrismetEuropeanRouletteLabStateValidationError, .unsupportedRulesVersion(99))
        }
    }

    func testEveryPocketIsReachableByASeedFixture() throws {
        var seen = Set<Int>()
        for seed in 0..<10_000 {
            if let pocket = try PrismetEuropeanRouletteLab.spin(seed: UInt64(seed)).pocket {
                seen.insert(pocket)
            }
        }
        XCTAssertEqual(seen, Set(PrismetEuropeanRouletteLab.wheel))
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] else {
            throw TestError.notAnObject
        }
        return object
    }

    private enum TestError: Error { case notAnObject }
}
