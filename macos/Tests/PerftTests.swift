import XCTest
@testable import Prismet

/// Perft (performance test): count the number of leaf nodes in the legal-move
/// tree to a given depth. The reference node counts below are the canonical,
/// independently-verified values from the Chess Programming Wiki. Matching them
/// is strong evidence the move generator handles castling, en passant,
/// promotion, pins, and check evasion correctly.
final class PerftTests: XCTestCase {

    private func perft(_ pos: Position, _ depth: Int) -> Int {
        let moves = MoveGenerator.legalMoves(in: pos)
        if depth <= 1 { return moves.count }
        var nodes = 0
        for m in moves {
            nodes += perft(MoveGenerator.makeMove(m, in: pos), depth - 1)
        }
        return nodes
    }

    private func assertPerft(_ fen: String, _ expected: [Int],
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let pos = Position(fen: fen) else {
            XCTFail("invalid FEN: \(fen)", file: file, line: line)
            return
        }
        for (i, count) in expected.enumerated() {
            let depth = i + 1
            XCTAssertEqual(perft(pos, depth), count,
                           "perft(\(depth)) mismatch for \(fen)", file: file, line: line)
        }
    }

    func testPerftInitialPosition() {
        assertPerft("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                    [20, 400, 8902, 197281])
    }

    func testPerftKiwipete() {
        // Dense middlegame: castling both sides, many captures, pins.
        assertPerft("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -",
                    [48, 2039, 97862])
    }

    func testPerftEnPassantHeavyPosition() {
        // Position 3 — exercises en passant and tricky pawn/rook interplay.
        assertPerft("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -",
                    [14, 191, 2812, 43238])
    }

    func testPerftPromotionPosition() {
        // Position 4 — promotions, including under-promotion, and castling.
        assertPerft("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -",
                    [6, 264, 9467])
    }

    func testPerftMiddlegamePosition() {
        // Position 5 — another independent middlegame reference.
        assertPerft("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -",
                    [44, 1486, 62379])
    }
}
