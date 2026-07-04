import XCTest
@testable import Kaleidoscope

final class CheckersAITests: XCTestCase {
    func testDifficultyDepthScalesAcrossELO() {
        XCTAssertEqual(CheckersAI.searchDepth(forELO: 600), 1)
        XCTAssertLessThan(CheckersAI.searchDepth(forELO: 900), CheckersAI.searchDepth(forELO: 1700))
        XCTAssertEqual(CheckersAI.searchDepth(forELO: 2400), 4)
        XCTAssertEqual(CheckersAI.searchDepth(forELO: 100), 1)
        XCTAssertEqual(CheckersAI.searchDepth(forELO: 3000), 4)
    }

    func testAIOnlyMovesForConfiguredPlayerTurn() {
        let game = CheckersGame(currentPlayer: .dark)
        let ai = CheckersAI(player: .light)

        XCTAssertNil(ai.move(in: game))
    }

    func testAIChoosesMandatoryCapture() throws {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (2, 1, CheckersPiece(player: .light, kind: .man)),
            (3, 2, CheckersPiece(player: .dark, kind: .man)),
            (5, 4, CheckersPiece(player: .dark, kind: .man))
        ]), currentPlayer: .light)

        let move = try XCTUnwrap(CheckersAI(player: .light).move(in: game))

        XCTAssertEqual(move, CheckersMove(from: CheckersPoint(row: 2, col: 1),
                                          to: CheckersPoint(row: 4, col: 3),
                                          captured: CheckersPoint(row: 3, col: 2)))
    }

    func testELOConfiguredAIChoosesMandatoryCapture() throws {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (2, 1, CheckersPiece(player: .light, kind: .man)),
            (3, 2, CheckersPiece(player: .dark, kind: .man)),
            (5, 4, CheckersPiece(player: .dark, kind: .man))
        ]), currentPlayer: .light)

        let move = try XCTUnwrap(CheckersAI(player: .light, targetELO: 1800).move(in: game))

        XCTAssertEqual(move, CheckersMove(from: CheckersPoint(row: 2, col: 1),
                                          to: CheckersPoint(row: 4, col: 3),
                                          captured: CheckersPoint(row: 3, col: 2)))
    }

    func testAIPrizesPromotionWhenNoCaptureExists() throws {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (0, 1, CheckersPiece(player: .dark, kind: .man)),
            (6, 1, CheckersPiece(player: .light, kind: .man)),
            (2, 5, CheckersPiece(player: .light, kind: .man))
        ]), currentPlayer: .light)

        let move = try XCTUnwrap(CheckersAI(player: .light).move(in: game))

        XCTAssertEqual(move.from, CheckersPoint(row: 6, col: 1))
        XCTAssertEqual(move.to.row, CheckersPlayer.light.promotionRow)
    }

    func testResultScoreUsesPieceMarginAndWinnerKings() {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (0, 1, CheckersPiece(player: .dark, kind: .king)),
            (2, 1, CheckersPiece(player: .dark, kind: .man))
        ]), currentPlayer: .light)

        XCTAssertEqual(game.winner, .dark)
        XCTAssertEqual(game.resultScore(for: .dark), 225)
    }

    func testResultScoreIsNilForNonWinner() {
        let game = CheckersGame()

        XCTAssertNil(game.resultScore(for: .dark))
        XCTAssertNil(game.resultScore(for: .light))
    }
}
