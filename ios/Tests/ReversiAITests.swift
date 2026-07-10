import XCTest
@testable import Prismet

final class ReversiAITests: XCTestCase {
    func testDifficultyDepthScalesAcrossELO() {
        XCTAssertEqual(ReversiAI.searchDepth(forELO: 600), 1)
        XCTAssertLessThan(ReversiAI.searchDepth(forELO: 900), ReversiAI.searchDepth(forELO: 1700))
        XCTAssertEqual(ReversiAI.searchDepth(forELO: 2400), 5)
        XCTAssertEqual(ReversiAI.searchDepth(forELO: 100), 1)
        XCTAssertEqual(ReversiAI.searchDepth(forELO: 3000), 5)
    }

    func testBotTakesCornerWhenAvailable() {
        var board = Array<ReversiPiece?>(repeating: nil, count: ReversiGame.size * ReversiGame.size)
        board[index(row: 0, col: 1)] = .white
        board[index(row: 0, col: 2)] = .black
        board[index(row: 1, col: 0)] = .white
        board[index(row: 2, col: 0)] = .black
        board[index(row: 3, col: 3)] = .white
        board[index(row: 3, col: 4)] = .black
        let game = ReversiGame(board: board, currentPlayer: .black)

        XCTAssertEqual(ReversiAI(player: .black, targetELO: 1800).move(in: game), ReversiMove(row: 0, col: 0))
    }

    func testBotReturnsOnlyLegalMoves() {
        let game = ReversiGame()
        let move = ReversiAI(player: .black, targetELO: 1200).move(in: game)

        XCTAssertNotNil(move)
        XCTAssertTrue(game.legalMoves(for: .black).contains(move!))
    }

    private func index(row: Int, col: Int) -> Int {
        row * ReversiGame.size + col
    }
}
