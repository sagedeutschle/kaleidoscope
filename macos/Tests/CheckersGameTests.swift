// PRISM: RELEASE Agent-B 2026-06-28 — Checkers model behavior coverage.
import XCTest
@testable import Kaleidoscope

final class CheckersGameTests: XCTestCase {
    func testInitialBoardHasDarkMovingUpAndLightMovingDown() {
        let game = CheckersGame()

        XCTAssertEqual(game.currentPlayer, .dark)
        XCTAssertEqual(game.count(for: .dark), 12)
        XCTAssertEqual(game.count(for: .light), 12)
        XCTAssertEqual(game.piece(row: 5, col: 0), CheckersPiece(player: .dark, kind: .man))
        XCTAssertEqual(game.piece(row: 2, col: 1), CheckersPiece(player: .light, kind: .man))
        XCTAssertTrue(game.legalMoves().contains(CheckersMove(from: CheckersPoint(row: 5, col: 0),
                                                              to: CheckersPoint(row: 4, col: 1))))
    }

    func testMandatoryCaptureSuppressesQuietMoves() {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (5, 0, CheckersPiece(player: .dark, kind: .man)),
            (5, 4, CheckersPiece(player: .dark, kind: .man)),
            (4, 1, CheckersPiece(player: .light, kind: .man))
        ]), currentPlayer: .dark)

        XCTAssertEqual(Set(game.legalMoves()), [
            CheckersMove(from: CheckersPoint(row: 5, col: 0),
                         to: CheckersPoint(row: 3, col: 2),
                         captured: CheckersPoint(row: 4, col: 1))
        ])
    }

    func testMultiJumpContinuationKeepsTurnAndRestrictsOrigin() {
        var game = CheckersGame(board: CheckersGame.board(pieces: [
            (5, 0, CheckersPiece(player: .dark, kind: .man)),
            (4, 1, CheckersPiece(player: .light, kind: .man)),
            (2, 3, CheckersPiece(player: .light, kind: .man))
        ]), currentPlayer: .dark)

        XCTAssertTrue(game.applyMove(CheckersMove(from: CheckersPoint(row: 5, col: 0),
                                                  to: CheckersPoint(row: 3, col: 2),
                                                  captured: CheckersPoint(row: 4, col: 1))))

        XCTAssertEqual(game.currentPlayer, .dark)
        XCTAssertEqual(game.activeJumpOrigin, CheckersPoint(row: 3, col: 2))
        XCTAssertEqual(game.legalMoves(), [
            CheckersMove(from: CheckersPoint(row: 3, col: 2),
                         to: CheckersPoint(row: 1, col: 4),
                         captured: CheckersPoint(row: 2, col: 3))
        ])

        XCTAssertTrue(game.applyMove(CheckersMove(from: CheckersPoint(row: 3, col: 2),
                                                  to: CheckersPoint(row: 1, col: 4),
                                                  captured: CheckersPoint(row: 2, col: 3))))
        XCTAssertNil(game.activeJumpOrigin)
        XCTAssertEqual(game.currentPlayer, .light)
    }

    func testPromotionAndKingsMoveBothDirections() {
        var game = CheckersGame(board: CheckersGame.board(pieces: [
            (1, 2, CheckersPiece(player: .dark, kind: .man))
        ]), currentPlayer: .dark)

        XCTAssertTrue(game.applyMove(CheckersMove(from: CheckersPoint(row: 1, col: 2),
                                                  to: CheckersPoint(row: 0, col: 1))))

        XCTAssertEqual(game.piece(row: 0, col: 1), CheckersPiece(player: .dark, kind: .king))
        XCTAssertEqual(game.currentPlayer, .light)

        let kingGame = CheckersGame(board: CheckersGame.board(pieces: [
            (3, 2, CheckersPiece(player: .dark, kind: .king))
        ]), currentPlayer: .dark)

        XCTAssertEqual(Set(kingGame.legalMoves()), [
            CheckersMove(from: CheckersPoint(row: 3, col: 2), to: CheckersPoint(row: 2, col: 1)),
            CheckersMove(from: CheckersPoint(row: 3, col: 2), to: CheckersPoint(row: 2, col: 3)),
            CheckersMove(from: CheckersPoint(row: 3, col: 2), to: CheckersPoint(row: 4, col: 1)),
            CheckersMove(from: CheckersPoint(row: 3, col: 2), to: CheckersPoint(row: 4, col: 3))
        ])
    }

    func testKingsCaptureBothDirections() {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (3, 2, CheckersPiece(player: .dark, kind: .king)),
            (2, 3, CheckersPiece(player: .light, kind: .man)),
            (4, 3, CheckersPiece(player: .light, kind: .man))
        ]), currentPlayer: .dark)

        XCTAssertEqual(Set(game.legalMoves()), [
            CheckersMove(from: CheckersPoint(row: 3, col: 2),
                         to: CheckersPoint(row: 1, col: 4),
                         captured: CheckersPoint(row: 2, col: 3)),
            CheckersMove(from: CheckersPoint(row: 3, col: 2),
                         to: CheckersPoint(row: 5, col: 4),
                         captured: CheckersPoint(row: 4, col: 3))
        ])
    }

    func testGameOverWinnerWhenCurrentPlayerHasNoLegalMoves() {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (0, 1, CheckersPiece(player: .dark, kind: .man)),
            (1, 0, CheckersPiece(player: .light, kind: .man)),
            (1, 2, CheckersPiece(player: .light, kind: .man))
        ]), currentPlayer: .dark)

        XCTAssertTrue(game.isGameOver)
        XCTAssertEqual(game.winner, .light)
    }

    func testCodableRoundTripPreservesBoardTurnAndJumpContinuation() throws {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (3, 2, CheckersPiece(player: .dark, kind: .man)),
            (2, 3, CheckersPiece(player: .light, kind: .man))
        ]), currentPlayer: .dark, activeJumpOrigin: CheckersPoint(row: 3, col: 2))

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(CheckersGame.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
