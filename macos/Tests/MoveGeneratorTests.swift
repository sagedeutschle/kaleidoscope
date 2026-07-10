import XCTest
@testable import Prismet

final class MoveGeneratorTests: XCTestCase {
    func testInitialPositionHasTwentyLegalMoves() {
        XCTAssertEqual(MoveGenerator.legalMoves(in: .initial).count, 20)
    }

    func testDoublePawnPushMovesPawnAndSetsEnPassantTarget() {
        let move = Move(
            from: Square(file: 4, rank: 1),
            to: Square(file: 4, rank: 3),
            isDoublePawnPush: true
        )

        let next = MoveGenerator.makeMove(move, in: .initial)

        XCTAssertNil(next.piece(at: Square(file: 4, rank: 1)))
        XCTAssertEqual(next.piece(at: Square(file: 4, rank: 3)), Piece(color: .white, type: .pawn))
        XCTAssertEqual(next.enPassant, Square(file: 4, rank: 2))
        XCTAssertEqual(next.sideToMove, .black)
    }
}
