import XCTest
@testable import Prismet

final class GomokuAITests: XCTestCase {
    func testDifficultyDepthScalesAcrossELO() {
        XCTAssertEqual(GomokuAI.searchDepth(forELO: 600), 1)
        XCTAssertLessThan(GomokuAI.searchDepth(forELO: 900), GomokuAI.searchDepth(forELO: 1800))
        XCTAssertEqual(GomokuAI.searchDepth(forELO: 2400), 4)
        XCTAssertEqual(GomokuAI.searchDepth(forELO: 100), 1)
        XCTAssertEqual(GomokuAI.searchDepth(forELO: 3000), 4)
    }

    func testBotOpensInCenter() {
        let move = GomokuAI(player: .black, targetELO: 1200).move(in: GomokuGame())

        XCTAssertEqual(move, GomokuPoint(row: 7, col: 7))
    }

    func testBotTakesImmediateWin() {
        let game = GomokuGame(
            board: board([
                (7, 4, .white),
                (7, 5, .white),
                (7, 6, .white),
                (7, 7, .white),
                (7, 3, .black),
                (0, 0, .black),
                (1, 0, .black),
                (2, 0, .black)
            ]),
            currentPlayer: .white
        )

        XCTAssertEqual(GomokuAI(player: .white, targetELO: 1600).move(in: game), GomokuPoint(row: 7, col: 8))
    }

    func testBotBlocksImmediateOpponentWin() {
        let game = GomokuGame(
            board: board([
                (7, 4, .black),
                (7, 5, .black),
                (7, 6, .black),
                (7, 7, .black),
                (7, 3, .white),
                (0, 0, .white),
                (1, 0, .white),
                (2, 0, .white)
            ]),
            currentPlayer: .white
        )

        XCTAssertEqual(GomokuAI(player: .white, targetELO: 1200).move(in: game), GomokuPoint(row: 7, col: 8))
    }

    private func board(_ stones: [(Int, Int, GomokuPlayer)]) -> [GomokuPlayer?] {
        var board = Array<GomokuPlayer?>(repeating: nil, count: GomokuGame.size * GomokuGame.size)
        for stone in stones {
            board[stone.0 * GomokuGame.size + stone.1] = stone.2
        }
        return board
    }
}
