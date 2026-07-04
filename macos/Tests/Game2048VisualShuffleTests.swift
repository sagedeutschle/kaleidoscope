import XCTest
@testable import Kaleidoscope

final class Game2048VisualShuffleTests: XCTestCase {
    func testVisualShuffleDoesNotChangeGameGridOrScore() {
        let game = Game2048(grid: [
            2, 4, 8, 16,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ], score: 128)

        _ = Game2048VisualShuffle(seed: 9, slotCount: game.grid.count)

        XCTAssertEqual(game.grid, [
            2, 4, 8, 16,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])
        XCTAssertEqual(game.score, 128)
    }

    func testVisualShuffleProducesVisualEffectsForEveryTile() {
        let shuffle = Game2048VisualShuffle(seed: 9, slotCount: 16)

        XCTAssertEqual(shuffle.effectsByTileIndex.count, 16)
        XCTAssertTrue(shuffle.effectsByTileIndex.contains { !$0.isNeutral })
    }

    func testVisualShuffleIsDeterministicForSeed() {
        XCTAssertEqual(
            Game2048VisualShuffle(seed: 9, slotCount: 16),
            Game2048VisualShuffle(seed: 9, slotCount: 16)
        )
    }
}
