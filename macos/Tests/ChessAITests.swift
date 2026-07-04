import XCTest
@testable import Kaleidoscope

final class ChessAITests: XCTestCase {

    // White pawn on e4 can capture an undefended black queen on d5 (exd5).
    // Everything else leaves White down a queen, so exd5 is the unique best move.
    private let freeQueenFEN = "4k3/8/8/3q4/4P3/8/8/4K3 w - - 0 1"

    private let e4 = Square(file: 4, rank: 3)
    private let d5 = Square(file: 3, rank: 4)

    func testScoredRootMovesCoversEveryLegalMove() {
        let pos = Position(fen: freeQueenFEN)!
        let legal = MoveGenerator.legalMoves(in: pos)
        let scored = MinimaxAI.scoredRootMoves(pos, depth: 2)
        XCTAssertEqual(scored.count, legal.count)
    }

    func testFullStrengthTakesTheFreeQueen() {
        let pos = Position(fen: freeQueenFEN)!
        // slack 0 = strongest: the difficulty pool collapses to the single best move.
        let move = MinimaxAI.searchRoot(pos, depth: 2, slack: 0)
        XCTAssertEqual(move?.from, e4)
        XCTAssertEqual(move?.to, d5)
    }

    func testCaptureScoresStrictlyAboveEveryQuietMove() {
        let pos = Position(fen: freeQueenFEN)!
        let scored = MinimaxAI.scoredRootMoves(pos, depth: 2)
        guard let capture = scored.first(where: { $0.move.to == d5 }) else {
            return XCTFail("expected the exd5 capture among scored root moves")
        }
        let bestNonCapture = scored.filter { $0.move.to != d5 }.map(\.score).max() ?? Int.min
        // Exact full-window scores: winning the queen must beat every alternative.
        XCTAssertGreaterThan(capture.score, bestNonCapture)
    }
}
