// PRISM: RELEASE Agent-B 2026-06-28 — Connect Four model coverage.

import XCTest
@testable import Prismet

final class ConnectFourGameTests: XCTestCase {
    func testInitialGameExposesStandardBoardAndRedToMove() {
        let game = ConnectFourGame()

        XCTAssertEqual(game.rows, 6)
        XCTAssertEqual(game.columns, 7)
        XCTAssertEqual(game.currentPlayer, .red)
        XCTAssertNil(game.winner)
        XCTAssertFalse(game.isDraw)
        XCTAssertEqual(game.moveCount, 0)
        XCTAssertEqual(game.legalColumns, Array(0..<7))
    }

    func testDropTokenUsesGravityAndAlternatesPlayers() {
        var game = ConnectFourGame()

        XCTAssertTrue(game.dropToken(in: 3))
        XCTAssertEqual(game.token(row: 5, column: 3), .red)
        XCTAssertEqual(game.currentPlayer, .yellow)

        XCTAssertTrue(game.dropToken(in: 3))
        XCTAssertEqual(game.token(row: 4, column: 3), .yellow)
        XCTAssertEqual(game.currentPlayer, .red)
        XCTAssertEqual(game.moveCount, 2)
    }

    func testRejectsInvalidAndFullColumnMoves() {
        var game = ConnectFourGame()

        XCTAssertFalse(game.dropToken(in: -1))
        XCTAssertFalse(game.dropToken(in: 7))

        for _ in 0..<6 {
            XCTAssertTrue(game.dropToken(in: 0))
        }

        XCTAssertFalse(game.legalColumns.contains(0))
        XCTAssertFalse(game.dropToken(in: 0))
        XCTAssertEqual(game.moveCount, 6)
    }

    func testDetectsHorizontalWin() {
        var game = ConnectFourGame()

        for column in [0, 0, 1, 1, 2, 2, 3] {
            XCTAssertTrue(game.dropToken(in: column))
        }

        XCTAssertEqual(game.winner, .red)
        XCTAssertFalse(game.isDraw)
        XCTAssertTrue(game.legalColumns.isEmpty)
        XCTAssertFalse(game.dropToken(in: 4))
    }

    func testDetectsVerticalWin() {
        var game = ConnectFourGame()

        for column in [0, 1, 0, 1, 0, 1, 0] {
            XCTAssertTrue(game.dropToken(in: column))
        }

        XCTAssertEqual(game.winner, .red)
        XCTAssertEqual(game.tokenCount(for: .red), 4)
        XCTAssertEqual(game.tokenCount(for: .yellow), 3)
    }

    func testDetectsDiagonalUpWin() {
        var game = ConnectFourGame()

        for column in [0, 1, 1, 2, 4, 2, 2, 3, 5, 3, 6, 3, 3] {
            XCTAssertTrue(game.dropToken(in: column))
        }

        XCTAssertEqual(game.winner, .red)
        XCTAssertEqual(game.token(row: 5, column: 0), .red)
        XCTAssertEqual(game.token(row: 4, column: 1), .red)
        XCTAssertEqual(game.token(row: 3, column: 2), .red)
        XCTAssertEqual(game.token(row: 2, column: 3), .red)
    }

    func testDetectsDiagonalDownWinFromBoardState() {
        let game = ConnectFourGame(board: board([
            [.empty, .empty, .empty, .empty, .empty, .empty, .empty],
            [.empty, .empty, .empty, .empty, .empty, .empty, .empty],
            [.red,   .empty, .empty, .empty, .empty, .empty, .empty],
            [.yellow, .red,  .empty, .empty, .empty, .empty, .empty],
            [.yellow, .yellow, .red, .empty, .empty, .empty, .empty],
            [.yellow, .yellow, .yellow, .red, .empty, .empty, .empty]
        ]))

        XCTAssertEqual(game.winner, .red)
        XCTAssertFalse(game.isDraw)
    }

    func testDetectsDrawForFullBoardWithoutWinner() {
        let game = ConnectFourGame(board: board([
            [.yellow, .yellow, .red, .red, .yellow, .yellow, .red],
            [.red, .red, .yellow, .yellow, .red, .red, .yellow],
            [.yellow, .yellow, .red, .red, .yellow, .yellow, .red],
            [.red, .red, .yellow, .yellow, .red, .red, .yellow],
            [.yellow, .yellow, .red, .red, .yellow, .yellow, .red],
            [.red, .red, .yellow, .yellow, .red, .red, .yellow]
        ]))

        XCTAssertNil(game.winner)
        XCTAssertTrue(game.isDraw)
        XCTAssertTrue(game.legalColumns.isEmpty)
        XCTAssertEqual(game.moveCount, 42)
    }

    func testResetRestoresEmptyBoardAndRedTurn() {
        var game = ConnectFourGame()
        _ = game.dropToken(in: 0)
        _ = game.dropToken(in: 1)

        game.reset()

        XCTAssertEqual(game.currentPlayer, .red)
        XCTAssertNil(game.winner)
        XCTAssertFalse(game.isDraw)
        XCTAssertEqual(game.moveCount, 0)
        XCTAssertEqual(game.legalColumns, Array(0..<7))
        XCTAssertNil(game.token(row: 5, column: 0))
    }

    private enum Cell {
        case empty
        case red
        case yellow
    }

    private func board(_ rows: [[Cell]]) -> [ConnectFourPlayer?] {
        rows.flatMap { row in
            row.map { cell in
                switch cell {
                case .empty: return nil
                case .red: return .red
                case .yellow: return .yellow
                }
            }
        }
    }
}
