import XCTest
@testable import Prismet

/// Tests for parsing Forsyth–Edwards Notation into a `Position`.
final class FENTests: XCTestCase {
    private let initialFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    func testParsesInitialPositionEqualToBuiltInInitial() {
        let pos = Position(fen: initialFEN)
        XCTAssertEqual(pos, .initial)
    }

    func testParsesSideToMove() {
        let black = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")
        XCTAssertEqual(black?.sideToMove, .black)
    }

    func testParsesPartialCastlingRights() {
        let pos = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w Kq - 0 1")
        XCTAssertEqual(pos?.castling.whiteKingside, true)
        XCTAssertEqual(pos?.castling.whiteQueenside, false)
        XCTAssertEqual(pos?.castling.blackKingside, false)
        XCTAssertEqual(pos?.castling.blackQueenside, true)
    }

    func testParsesNoCastlingRights() {
        let pos = Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1")
        XCTAssertEqual(pos?.castling, CastlingRights(whiteKingside: false, whiteQueenside: false,
                                                     blackKingside: false, blackQueenside: false))
    }

    func testParsesEnPassantSquare() {
        // After 1. e4 the EP target is e3 = file 4, rank 2.
        let pos = Position(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
        XCTAssertEqual(pos?.enPassant, Square(file: 4, rank: 2))
    }

    func testParsesNoEnPassantSquare() {
        let pos = Position(fen: initialFEN)
        XCTAssertNil(pos?.enPassant)
    }

    func testParsesPiecePlacementRankOrder() {
        // FEN lists rank 8 first; a black rook must land on a8 (file 0, rank 7),
        // a white rook on a1 (file 0, rank 0).
        let pos = Position(fen: initialFEN)
        XCTAssertEqual(pos?.piece(at: Square(file: 0, rank: 7)), Piece(color: .black, type: .rook))
        XCTAssertEqual(pos?.piece(at: Square(file: 0, rank: 0)), Piece(color: .white, type: .rook))
        XCTAssertEqual(pos?.piece(at: Square(file: 4, rank: 7)), Piece(color: .black, type: .king))
    }

    func testParsesWithoutHalfmoveAndFullmoveFields() {
        // Many perft FENs omit the trailing clock fields.
        let pos = Position(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -")
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.sideToMove, .white)
    }

    func testRejectsFenWithWrongRankCount() {
        XCTAssertNil(Position(fen: "rnbqkbnr/pppppppp/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
    }

    func testRejectsGarbageFen() {
        XCTAssertNil(Position(fen: "not a fen"))
        XCTAssertNil(Position(fen: ""))
    }
}
