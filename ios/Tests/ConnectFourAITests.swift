import XCTest
@testable import Kaleidoscope

final class ConnectFourAITests: XCTestCase {
    func testDifficultyDepthScalesAcrossELO() {
        XCTAssertEqual(ConnectFourAI.searchDepth(forELO: 600), 1)
        XCTAssertLessThan(ConnectFourAI.searchDepth(forELO: 900), ConnectFourAI.searchDepth(forELO: 1700))
        XCTAssertEqual(ConnectFourAI.searchDepth(forELO: 2400), 6)
        XCTAssertEqual(ConnectFourAI.searchDepth(forELO: 100), 1)
        XCTAssertEqual(ConnectFourAI.searchDepth(forELO: 3000), 6)
    }

    func testBotTakesImmediateWin() {
        var board = Array<ConnectFourPlayer?>(repeating: nil, count: ConnectFourGame.rowCount * ConnectFourGame.columnCount)
        board[index(row: 5, column: 0)] = .red
        board[index(row: 5, column: 1)] = .red
        board[index(row: 5, column: 2)] = .red
        board[index(row: 4, column: 0)] = .yellow
        board[index(row: 4, column: 1)] = .yellow
        let game = ConnectFourGame(board: board, currentPlayer: .red)

        XCTAssertEqual(ConnectFourAI(player: .red, targetELO: 1600).move(in: game), 3)
    }

    func testBotBlocksImmediateOpponentWin() {
        var board = Array<ConnectFourPlayer?>(repeating: nil, count: ConnectFourGame.rowCount * ConnectFourGame.columnCount)
        board[index(row: 5, column: 0)] = .yellow
        board[index(row: 5, column: 1)] = .yellow
        board[index(row: 5, column: 2)] = .yellow
        board[index(row: 4, column: 0)] = .red
        board[index(row: 4, column: 1)] = .red
        let game = ConnectFourGame(board: board, currentPlayer: .red)

        XCTAssertEqual(ConnectFourAI(player: .red, targetELO: 1200).move(in: game), 3)
    }

    private func index(row: Int, column: Int) -> Int {
        row * ConnectFourGame.columnCount + column
    }
}
