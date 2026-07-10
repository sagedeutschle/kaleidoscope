import XCTest
@testable import Prismet

final class MinesweeperTilePresentationTests: XCTestCase {
    func testHiddenFlaggedTileUsesFlagSymbol() {
        var game = MinesweeperGame(width: 2, height: 2, mines: [0])

        game.toggleFlag(row: 0, col: 0)

        let tile = MinesweeperTilePresentation(game: game, row: 0, col: 0)
        XCTAssertEqual(tile.kind, .flagged)
        XCTAssertEqual(tile.symbol, "⚑")
    }

    func testRevealedMineUsesMineSymbol() {
        var game = MinesweeperGame(width: 2, height: 2, mines: [0])

        game.reveal(row: 0, col: 0)

        let tile = MinesweeperTilePresentation(game: game, row: 0, col: 0)
        XCTAssertEqual(tile.kind, .mine)
        XCTAssertEqual(tile.symbol, "●")
    }

    func testRevealedNumberUsesClassicNumberColor() {
        var game = MinesweeperGame(width: 3, height: 3, mines: [0])

        game.reveal(row: 1, col: 1)

        let tile = MinesweeperTilePresentation(game: game, row: 1, col: 1)
        XCTAssertEqual(tile.kind, .revealed)
        XCTAssertEqual(tile.symbol, "1")
        XCTAssertEqual(tile.textColorName, "blue")
    }
}
