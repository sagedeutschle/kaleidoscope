import XCTest
@testable import Prismet

final class ReversiGameTests: XCTestCase {
    func testInitialBoardHasFourLegalBlackMoves() {
        let game = ReversiGame()

        XCTAssertEqual(Set(game.legalMoves()), Set([
            ReversiMove(row: 2, col: 3),
            ReversiMove(row: 3, col: 2),
            ReversiMove(row: 4, col: 5),
            ReversiMove(row: 5, col: 4)
        ]))
    }

    func testApplyingMoveFlipsBracketedPiecesAndChangesTurn() {
        var game = ReversiGame()

        XCTAssertTrue(game.applyMove(row: 2, col: 3))

        XCTAssertEqual(game.piece(row: 2, col: 3), .black)
        XCTAssertEqual(game.piece(row: 3, col: 3), .black)
        XCTAssertEqual(game.currentPlayer, .white)
        XCTAssertEqual(game.count(for: .black), 4)
        XCTAssertEqual(game.count(for: .white), 1)
    }

    func testIllegalMoveDoesNothing() {
        var game = ReversiGame()

        XCTAssertFalse(game.applyMove(row: 0, col: 0))
        XCTAssertEqual(game.currentPlayer, .black)
        XCTAssertEqual(game.count(for: .black), 2)
        XCTAssertEqual(game.count(for: .white), 2)
    }

    func testReversiCodableRoundTripPreservesBoardAndTurn() throws {
        var game = ReversiGame()
        _ = game.applyMove(row: 2, col: 3)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(ReversiGame.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
