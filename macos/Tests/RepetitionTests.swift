import XCTest
@testable import Prismet

/// The pure repetition-key + threefold-detection logic that `GameState` uses to
/// declare a draw by repetition.
final class RepetitionTests: XCTestCase {

    private let initialFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    func testRepetitionKeyIgnoresMoveClocks() {
        let a = Position(fen: initialFEN)!
        let b = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 25 40")!
        XCTAssertEqual(a.repetitionKey, b.repetitionKey)
    }

    func testRepetitionKeyDistinguishesSideToMove() {
        let w = Position(fen: initialFEN)!
        let b = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")!
        XCTAssertNotEqual(w.repetitionKey, b.repetitionKey)
    }

    func testRepetitionKeyDistinguishesCastlingRights() {
        let full = Position(fen: initialFEN)!
        let none = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1")!
        XCTAssertNotEqual(full.repetitionKey, none.repetitionKey)
    }

    func testThreefoldDetectedWhenLatestPositionOccursThrice() {
        let p = Position.initial
        XCTAssertTrue(MoveGenerator.isThreefoldRepetition(history: [p, p, p]))
    }

    func testTwoOccurrencesIsNotThreefold() {
        let p = Position.initial
        XCTAssertFalse(MoveGenerator.isThreefoldRepetition(history: [p, p]))
    }

    func testThreefoldChecksTheLatestPositionOnly() {
        let a = Position.initial
        let b = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")!
        // `a` occurs 3x but is not last; the last position `b` occurs once.
        XCTAssertFalse(MoveGenerator.isThreefoldRepetition(history: [a, a, a, b]))
    }
}
