import XCTest
@testable import Prismet

final class GomokuGameTests: XCTestCase {
    func testBlackMovesFirstAndPlayersAlternate() {
        var game = GomokuGame()

        XCTAssertEqual(game.currentPlayer, .black)
        XCTAssertTrue(game.placeStone(row: 7, col: 7))
        XCTAssertEqual(game.stone(row: 7, col: 7), .black)
        XCTAssertEqual(game.currentPlayer, .white)
        XCTAssertTrue(game.placeStone(row: 7, col: 8))
        XCTAssertEqual(game.stone(row: 7, col: 8), .white)
        XCTAssertEqual(game.currentPlayer, .black)
    }

    func testCannotPlayOutsideBoardOrOnOccupiedPoint() {
        var game = GomokuGame()

        XCTAssertFalse(game.placeStone(row: -1, col: 0))
        XCTAssertFalse(game.placeStone(row: GomokuGame.size, col: 0))
        XCTAssertTrue(game.placeStone(row: 0, col: 0))
        XCTAssertFalse(game.placeStone(row: 0, col: 0))
        XCTAssertEqual(game.stone(row: 0, col: 0), .black)
        XCTAssertEqual(game.currentPlayer, .white)
    }

    func testFiveHorizontalStonesWin() {
        var game = GomokuGame()

        XCTAssertTrue(game.placeStone(row: 4, col: 2)) // B
        XCTAssertTrue(game.placeStone(row: 0, col: 0)) // W
        XCTAssertTrue(game.placeStone(row: 4, col: 3))
        XCTAssertTrue(game.placeStone(row: 0, col: 1))
        XCTAssertTrue(game.placeStone(row: 4, col: 4))
        XCTAssertTrue(game.placeStone(row: 0, col: 2))
        XCTAssertTrue(game.placeStone(row: 4, col: 5))
        XCTAssertTrue(game.placeStone(row: 0, col: 3))
        XCTAssertTrue(game.placeStone(row: 4, col: 6))

        XCTAssertEqual(game.winner, .black)
        XCTAssertTrue(game.isGameOver)
        XCTAssertFalse(game.placeStone(row: 5, col: 6))
    }

    func testFiveVerticalStonesWin() {
        var game = GomokuGame()

        XCTAssertTrue(game.placeStone(row: 2, col: 9)) // B
        XCTAssertTrue(game.placeStone(row: 0, col: 0)) // W
        XCTAssertTrue(game.placeStone(row: 3, col: 9))
        XCTAssertTrue(game.placeStone(row: 0, col: 1))
        XCTAssertTrue(game.placeStone(row: 4, col: 9))
        XCTAssertTrue(game.placeStone(row: 0, col: 2))
        XCTAssertTrue(game.placeStone(row: 5, col: 9))
        XCTAssertTrue(game.placeStone(row: 0, col: 3))
        XCTAssertTrue(game.placeStone(row: 6, col: 9))

        XCTAssertEqual(game.winner, .black)
    }

    func testFiveDiagonalStonesWin() {
        var game = GomokuGame()

        XCTAssertTrue(game.placeStone(row: 1, col: 1)) // B
        XCTAssertTrue(game.placeStone(row: 0, col: 4)) // W
        XCTAssertTrue(game.placeStone(row: 2, col: 2))
        XCTAssertTrue(game.placeStone(row: 0, col: 5))
        XCTAssertTrue(game.placeStone(row: 3, col: 3))
        XCTAssertTrue(game.placeStone(row: 0, col: 6))
        XCTAssertTrue(game.placeStone(row: 4, col: 4))
        XCTAssertTrue(game.placeStone(row: 0, col: 7))
        XCTAssertTrue(game.placeStone(row: 5, col: 5))

        XCTAssertEqual(game.winner, .black)
    }

    func testFullBoardWithoutFiveInARowIsDraw() {
        var game = GomokuGame(
            board: Self.drawBoard(),
            currentPlayer: .black,
            winner: nil
        )

        XCTAssertTrue(game.isDraw)
        XCTAssertTrue(game.isGameOver)
        XCTAssertFalse(game.placeStone(row: 0, col: 0))
    }

    private static func drawBoard() -> [GomokuPlayer?] {
        var board = Array<GomokuPlayer?>(repeating: nil, count: GomokuGame.size * GomokuGame.size)
        for row in 0..<GomokuGame.size {
            for col in 0..<GomokuGame.size {
                let pairRow = row / 2
                let player: GomokuPlayer = (pairRow + col).isMultiple(of: 2) ? .black : .white
                board[row * GomokuGame.size + col] = player
            }
        }
        return board
    }
}
