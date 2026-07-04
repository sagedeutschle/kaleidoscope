import XCTest
@testable import Kaleidoscope

final class MinesweeperGameTests: XCTestCase {
    func testFirstRevealNeverPlacesMineOnClickedCell() {
        var game = MinesweeperGame(width: 4, height: 4, mineCount: 6, seed: 11)

        game.reveal(row: 0, col: 0)

        XCTAssertFalse(game.hasMine(row: 0, col: 0))
        XCTAssertTrue(game.isRevealed(row: 0, col: 0))
        XCTAssertEqual(game.status, .playing)
    }

    func testAdjacentMineCountUsesEightNeighbors() {
        let game = MinesweeperGame(width: 3, height: 3, mines: [0, 2, 6])

        XCTAssertEqual(game.adjacentMineCount(row: 1, col: 1), 3)
        XCTAssertEqual(game.adjacentMineCount(row: 0, col: 1), 2)
    }

    func testFlaggedCellDoesNotReveal() {
        var game = MinesweeperGame(width: 2, height: 2, mines: [0])

        game.toggleFlag(row: 0, col: 0)
        game.reveal(row: 0, col: 0)

        XCTAssertTrue(game.isFlagged(row: 0, col: 0))
        XCTAssertFalse(game.isRevealed(row: 0, col: 0))
        XCTAssertEqual(game.status, .playing)
    }

    func testRevealingMineLoses() {
        var game = MinesweeperGame(width: 2, height: 2, mines: [0])

        game.reveal(row: 0, col: 0)

        XCTAssertEqual(game.status, .lost)
    }

    func testRevealingAllSafeCellsWins() {
        var game = MinesweeperGame(width: 2, height: 2, mines: [0])

        game.reveal(row: 0, col: 1)
        game.reveal(row: 1, col: 0)
        game.reveal(row: 1, col: 1)

        XCTAssertEqual(game.status, .won)
    }

    func testMinesweeperGameRoundTripsAfterPlay() throws {
        var game = MinesweeperGame(width: 4, height: 3, mineCount: 3, seed: 9)

        game.reveal(row: 0, col: 0)
        game.toggleFlag(row: 2, col: 3)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(MinesweeperGame.self, from: data)

        XCTAssertEqual(restored, game)
    }

    func testCustomSettingsClampMineDensityAndFieldSize() {
        let settings = MinesweeperSettings(width: 2, height: 99, mineDensity: 0.95).clamped()

        XCTAssertEqual(settings.width, MinesweeperSettings.minWidth)
        XCTAssertEqual(settings.height, MinesweeperSettings.maxHeight)
        XCTAssertEqual(settings.mineDensity, MinesweeperSettings.maxMineDensity)
        XCTAssertLessThan(settings.mineCount, settings.width * settings.height)
    }

    func testExpertDifficultyMatchesIOSThirtyByThirtyPreset() throws {
        let preset = try XCTUnwrap(MinesweeperDifficulty.expert.preset)

        XCTAssertEqual(preset.width, 30)
        XCTAssertEqual(preset.height, 30)
        XCTAssertEqual(preset.mineCount, 186)
    }

    func testMinesweeperDifficultyOffersPresetsPlusCustom() {
        XCTAssertEqual(MinesweeperDifficulty.allCases, [.beginner, .intermediate, .expert, .custom])
        XCTAssertNil(MinesweeperDifficulty.custom.preset)
    }
}
