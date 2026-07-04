import XCTest
@testable import Kaleidoscope

final class RubiksCubeTests: XCTestCase {
    func testNewCubeIsSolved() {
        XCTAssertTrue(RubiksCube().isSolved)
    }

    func testSingleQuarterTurnIsNotSolved() {
        var cube = RubiksCube()
        cube.apply(.R)
        XCTAssertFalse(cube.isSolved)
    }

    func testQuarterTurnHasOrderFour() {
        for move in [RubiksMove.U, .D, .L, .R, .F, .B] {
            var cube = RubiksCube()
            for _ in 0..<4 { cube.apply(move) }
            XCTAssertEqual(cube, RubiksCube(), "\(move.rawValue) applied four times should restore the solved cube")
        }
    }

    func testMoveThenInverseRestoresSolved() {
        for move in RubiksMove.allCases {
            var cube = RubiksCube()
            cube.apply(move)
            cube.apply(move.inverse)
            XCTAssertEqual(cube, RubiksCube(),
                           "\(move.rawValue) then \(move.inverse.rawValue) should restore the solved cube")
        }
    }

    func testDoubleMoveEqualsTwoQuarterTurns() {
        var doubleCube = RubiksCube()
        doubleCube.apply(.R2)

        var twiceCube = RubiksCube()
        twiceCube.apply(.R)
        twiceCube.apply(.R)

        XCTAssertEqual(doubleCube, twiceCube)
    }

    /// The "sexy move" (R U R' U') has order 6 on a real cube: six repetitions
    /// return to the solved state. This catches almost any error in the face-turn
    /// permutations that the simpler tests would miss.
    func testSexyMoveHasOrderSix() {
        var cube = RubiksCube()
        let sexy: [RubiksMove] = [.R, .U, .Rprime, .Uprime]
        for _ in 0..<6 {
            for move in sexy { cube.apply(move) }
        }
        XCTAssertTrue(cube.isSolved)
        XCTAssertEqual(cube, RubiksCube())
    }

    func testSexyMoveOnceIsNotSolved() {
        let cube = RubiksCube().applying([.R, .U, .Rprime, .Uprime])
        XCTAssertFalse(cube.isSolved)
    }

    func testSeededScrambleIsNotSolved() {
        var cube = RubiksCube()
        _ = cube.scramble(seed: 42)
        XCTAssertFalse(cube.isSolved)
    }

    func testScrambleInverseRestoresSolved() {
        var cube = RubiksCube()
        let scramble = cube.scramble(seed: 7)
        XCTAssertFalse(cube.isSolved)

        let undo = scramble.reversed().map { $0.inverse }
        let restored = cube.applying(undo)

        XCTAssertTrue(restored.isSolved)
        XCTAssertEqual(restored, RubiksCube())
    }

    func testScrambleIsDeterministicForSeed() {
        var a = RubiksCube()
        var b = RubiksCube()
        let movesA = a.scramble(seed: 99)
        let movesB = b.scramble(seed: 99)
        XCTAssertEqual(movesA, movesB)
        XCTAssertEqual(a, b)
    }

    /// Generalises the order-6 sexy-move relation to every adjacent face pair. A
    /// permutation or sign error confined to a single face (invisible to the
    /// R/U-only test) is caught here.
    func testSexyMoveHasOrderSixForEveryAdjacentFacePair() {
        let adjacency: [(CubeFace, CubeFace)] = [
            (.R, .U), (.R, .F), (.R, .D), (.R, .B),
            (.L, .U), (.L, .F), (.L, .D), (.L, .B),
            (.U, .F), (.U, .B), (.D, .F), (.D, .B)
        ]
        for (a, b) in adjacency {
            var cube = RubiksCube()
            let sexy: [RubiksMove] = [.move(face: a, quarters: 1), .move(face: b, quarters: 1),
                                      .move(face: a, quarters: 3), .move(face: b, quarters: 3)]
            for _ in 0..<6 {
                for move in sexy { cube.apply(move) }
            }
            XCTAssertEqual(cube, RubiksCube(),
                           "(\(a.rawValue) \(b.rawValue) \(a.rawValue)' \(b.rawValue)') x6 should solve")
        }
    }

    /// The checkerboard pattern is all six 180° turns; it has order 2.
    func testCheckerboardPatternHasOrderTwo() {
        let checker: [RubiksMove] = [.U2, .D2, .F2, .B2, .L2, .R2]
        let once = RubiksCube().applying(checker)
        XCTAssertFalse(once.isSolved)
        XCTAssertEqual(once.applying(checker), RubiksCube())
    }

    /// Any scramble must preserve exactly nine stickers of each of the six colours
    /// (8·3 + 12·2 + 6·1 = 54 facelets total) — a guard against sticker bookkeeping bugs.
    func testColorConservationAcrossScrambles() {
        for seed in UInt64(1)...30 {
            var cube = RubiksCube()
            _ = cube.scramble(seed: seed, moveCount: 50)

            var counts = [Int: Int]()
            for cubie in cube.cubies {
                for direction in RubiksCube.faceDirections {
                    if let colour = cube.colourIndex(at: cubie, worldDirection: direction) {
                        counts[colour, default: 0] += 1
                    }
                }
            }

            XCTAssertEqual(counts.values.reduce(0, +), 54, "seed \(seed) total facelets")
            XCTAssertEqual(Set(counts.values), [9], "seed \(seed) should have 9 of each colour")
        }
    }

    func testRubiksCubeCodableRoundTripPreservesCubies() throws {
        var cube = RubiksCube()
        _ = cube.scramble(seed: 7)

        let data = try JSONEncoder().encode(cube)
        let restored = try JSONDecoder().decode(RubiksCube.self, from: data)

        XCTAssertEqual(restored, cube)
    }
}
