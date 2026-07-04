import XCTest
@testable import Kaleidoscope

/// Verifies game-end classification (`MoveGenerator.status`) that the UI relies
/// on for "Checkmate / Stalemate / Check" — perft validates move counts but not
/// these terminal verdicts.
final class GameStatusTests: XCTestCase {

    func testDetectsCheckmate() {
        // Fool's mate: 1. f3 e5 2. g4 Qh4#. White is mated, Black wins.
        let pos = Position(fen: "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")!
        XCTAssertEqual(MoveGenerator.status(of: pos), .checkmate(winner: .black))
        XCTAssertTrue(MoveGenerator.status(of: pos).isTerminal)
    }

    func testDetectsStalemate() {
        // Black king h8, White Qf7 + Kg6: Black to move, not in check, no moves.
        let pos = Position(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")!
        XCTAssertEqual(MoveGenerator.status(of: pos), .stalemate)
        XCTAssertTrue(MoveGenerator.status(of: pos).isTerminal)
    }

    func testDetectsCheckThatIsNotMate() {
        // Black king on e8 checked by Re1 down the open e-file, but has escapes.
        let pos = Position(fen: "4k3/8/8/8/8/8/8/4R1K1 b - - 0 1")!
        XCTAssertEqual(MoveGenerator.status(of: pos), .check(.black))
        XCTAssertFalse(MoveGenerator.status(of: pos).isTerminal)
        XCTAssertTrue(MoveGenerator.isInCheck(.black, in: pos))
    }

    func testOngoingPositionIsNotTerminalOrCheck() {
        XCTAssertEqual(MoveGenerator.status(of: .initial), .ongoing)
        XCTAssertFalse(MoveGenerator.isInCheck(.white, in: .initial))
    }
}
