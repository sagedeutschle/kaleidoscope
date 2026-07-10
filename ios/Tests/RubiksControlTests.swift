import XCTest
@testable import Prismet

/// Pins the pure move-notation -> face/direction mapping that drives the
/// Rubik's control pad labels, accessibility labels, and the "How to play"
/// legend. These are the strings the user reads, so a regression here is a
/// usability regression — exactly what this test guards.
final class RubiksControlTests: XCTestCase {

    // MARK: - Face plain names (legend + per-row labels)

    func testEveryFaceHasADistinctPlainName() {
        let names = CubeFace.allCases.map(\.plainName)
        XCTAssertEqual(Set(names).count, CubeFace.allCases.count,
                       "Face plain names must be unique so the legend is unambiguous")
    }

    func testFacePlainNamesNameTheirDirection() {
        XCTAssertEqual(CubeFace.U.plainName, "Up (top)")
        XCTAssertEqual(CubeFace.D.plainName, "Down (bottom)")
        XCTAssertEqual(CubeFace.L.plainName, "Left")
        XCTAssertEqual(CubeFace.R.plainName, "Right")
        XCTAssertEqual(CubeFace.F.plainName, "Front")
        XCTAssertEqual(CubeFace.B.plainName, "Back")
    }

    // MARK: - Prime detection

    func testPrimeFlagMatchesTheApostropheNotation() {
        for move in RubiksMove.allCases {
            XCTAssertEqual(move.isPrime, move.rawValue.hasSuffix("'"),
                           "isPrime must agree with the ' in \(move.rawValue)")
        }
    }

    // MARK: - Direction wording

    func testDirectionDescriptionMatchesQuarterTurns() {
        XCTAssertEqual(RubiksMove.R.directionDescription, "clockwise")       // 1 quarter
        XCTAssertEqual(RubiksMove.Rprime.directionDescription, "counter-clockwise") // 3 quarters
        XCTAssertEqual(RubiksMove.R2.directionDescription, "half turn")      // 2 quarters
    }

    func testPlainMovesAreClockwiseAndPrimesAreCounterClockwise() {
        for row in RubiksMove.mobileControlRows {
            XCTAssertEqual(row.turn.directionDescription, "clockwise")
            XCTAssertEqual(row.inverse.directionDescription, "counter-clockwise")
        }
    }

    // MARK: - Spoken description (accessibility labels)

    func testSpokenDescriptionCombinesFaceNameAndDirection() {
        XCTAssertEqual(RubiksMove.R.spokenDescription, "Right face, clockwise")
        XCTAssertEqual(RubiksMove.Rprime.spokenDescription, "Right face, counter-clockwise")
        XCTAssertEqual(RubiksMove.Uprime.spokenDescription, "Up (top) face, counter-clockwise")
        XCTAssertEqual(RubiksMove.D2.spokenDescription, "Down (bottom) face, half turn")
    }

    func testEverySpokenDescriptionIsUnique() {
        let spoken = RubiksMove.allCases.map(\.spokenDescription)
        XCTAssertEqual(Set(spoken).count, RubiksMove.allCases.count,
                       "Each move must read distinctly for VoiceOver")
    }

    // MARK: - Control-pad wiring (notation -> face + inverse mapping)

    func testControlRowsCoverEveryFaceExactlyOnce() {
        let faces = RubiksMove.mobileControlRows.map(\.face)
        XCTAssertEqual(faces, CubeFace.allCases,
                       "Pad must expose all six faces in U,D,L,R,F,B order")
    }

    func testControlRowTurnAndInverseTargetTheirOwnFace() {
        for row in RubiksMove.mobileControlRows {
            XCTAssertEqual(row.turn.face, row.face)
            XCTAssertEqual(row.inverse.face, row.face)
        }
    }

    func testControlRowInverseUndoesTheTurn() {
        // The CCW button must be the exact inverse of the CW button so tapping
        // both is a no-op — the property that makes the labels trustworthy.
        for row in RubiksMove.mobileControlRows {
            XCTAssertEqual(row.turn.inverse, row.inverse)
            XCTAssertFalse(row.turn.isPrime)
            XCTAssertTrue(row.inverse.isPrime)

            let solved = RubiksCube()
            let there = solved.applying([row.turn])
            XCTAssertFalse(there.isSolved, "A single quarter turn must disturb the cube")
            let back = there.applying([row.inverse])
            XCTAssertTrue(back.isSolved, "CW then CCW on \(row.face) must return to solved")
        }
    }

    func testRubiksViewExposesFullscreenCubeMode() throws {
        let viewPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Games/RubiksCubeView.swift")
        let source = try String(contentsOf: viewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("fullScreenCover"), "Rubik's Cube needs an iPhone/iPad fullscreen presentation")
        XCTAssertTrue(source.contains("arrow.up.left.and.arrow.down.right"), "Rubik's Cube needs a recognizable fullscreen icon")
        XCTAssertTrue(source.contains("showFullscreenCube"), "Fullscreen state should be explicit and testable")
    }
}
