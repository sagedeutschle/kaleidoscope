import XCTest
@testable import Kaleidoscope

final class Game2048ShufflePowerUpsTests: XCTestCase {
    func testDefaultShufflePowerUpCanBeUsedOncePerGame() {
        var powerUps = Game2048ShufflePowerUps()

        XCTAssertEqual(powerUps.remainingUses, 1)
        XCTAssertTrue(powerUps.use())
        XCTAssertEqual(powerUps.remainingUses, 0)
        XCTAssertFalse(powerUps.use())
    }

    func testConfiguredUsesAreClamped() {
        XCTAssertEqual(Game2048ShufflePowerUps(usesPerGame: -2).usesPerGame, 0)
        XCTAssertEqual(Game2048ShufflePowerUps(usesPerGame: 99).usesPerGame, Game2048ShufflePowerUps.maxUsesPerGame)
    }

    func testResetRestoresConfiguredUsesForNewGame() {
        var powerUps = Game2048ShufflePowerUps(usesPerGame: 3)
        XCTAssertTrue(powerUps.use())
        XCTAssertEqual(powerUps.remainingUses, 2)

        powerUps.resetForNewGame()

        XCTAssertEqual(powerUps.remainingUses, 3)
    }
}
