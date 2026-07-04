import XCTest
@testable import Kaleidoscope

final class GameResultExtractorTests: XCTestCase {

    func testGame2048ReturnsNilWhileInProgress() {
        let game = Game2048.newGame(seed: 1)

        XCTAssertNil(GameResultExtractor.result(for: game, completedAt: fixedDate))
    }

    func testGame2048ExtractsWinningScore() throws {
        let game = Game2048(grid: [
            2048, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ], score: 4096)

        let result = try XCTUnwrap(GameResultExtractor.result(for: game, completedAt: fixedDate))

        XCTAssertEqual(result.facetID, "2048")
        XCTAssertEqual(result.mode, "standard")
        XCTAssertEqual(result.outcome, .won)
        XCTAssertEqual(result.score, 4096)
        XCTAssertEqual(result.completedAt, fixedDate)
        XCTAssertEqual(result.metadata["boardSize"], "4")
        XCTAssertEqual(result.metadata["maxTile"], "2048")
    }

    func testGame2048ExtractsGameOverScore() throws {
        let game = Game2048(grid: [
            2, 4, 2, 4,
            4, 2, 4, 2,
            2, 4, 2, 4,
            4, 2, 4, 2
        ], score: 128)

        let result = try XCTUnwrap(GameResultExtractor.result(for: game, completedAt: fixedDate))

        XCTAssertEqual(result.outcome, .lost)
        XCTAssertEqual(result.score, 128)
    }

    func testSnakeReturnsNilWhilePlaying() {
        let game = SnakeGame()

        XCTAssertNil(GameResultExtractor.result(for: game, completedAt: fixedDate))
    }

    func testSnakeExtractsLostScore() throws {
        let game = SnakeGame(width: 6,
                             height: 6,
                             body: [
                                SnakePoint(row: 2, col: 2),
                                SnakePoint(row: 2, col: 1),
                                SnakePoint(row: 2, col: 0)
                             ],
                             direction: .right,
                             apple: SnakePoint(row: 4, col: 4),
                             score: 7,
                             status: .lost)

        let result = try XCTUnwrap(GameResultExtractor.result(for: game, completedAt: fixedDate))

        XCTAssertEqual(result.facetID, "snake")
        XCTAssertEqual(result.mode, "standard")
        XCTAssertEqual(result.outcome, .lost)
        XCTAssertEqual(result.score, 7)
        XCTAssertEqual(result.metadata["length"], "3")
        XCTAssertEqual(result.metadata["board"], "6x6")
    }

    func testConnectFourExtractsWinnerScore() throws {
        var game = ConnectFourGame()
        for column in [0, 0, 1, 1, 2, 2, 3] {
            XCTAssertTrue(game.dropToken(in: column))
        }

        let result = try XCTUnwrap(GameResultExtractor.result(for: game, completedAt: fixedDate))

        XCTAssertEqual(result.facetID, "connect-four")
        XCTAssertEqual(result.mode, "standard")
        XCTAssertEqual(result.outcome, .won)
        XCTAssertEqual(result.score, 135)
        XCTAssertEqual(result.moveCount, 7)
        XCTAssertEqual(result.metadata["winner"], "Red")
        XCTAssertEqual(result.metadata["redTokens"], "4")
        XCTAssertEqual(result.metadata["yellowTokens"], "3")
    }

    func testCheckersExtractsWinnerScore() throws {
        let game = CheckersGame(board: CheckersGame.board(pieces: [
            (0, 1, CheckersPiece(player: .dark, kind: .king))
        ]), currentPlayer: .light)

        let result = try XCTUnwrap(GameResultExtractor.result(for: game, completedAt: fixedDate))

        XCTAssertEqual(result.facetID, "checkers")
        XCTAssertEqual(result.mode, "standard")
        XCTAssertEqual(result.outcome, .won)
        XCTAssertEqual(result.score, 125)
        XCTAssertEqual(result.metadata["winner"], "Dark")
        XCTAssertEqual(result.metadata["darkPieces"], "1")
        XCTAssertEqual(result.metadata["lightPieces"], "0")
        XCTAssertEqual(result.metadata["darkKings"], "1")
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_800_000_100)
    }
}
