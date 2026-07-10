import XCTest
@testable import Prismet

final class Game2048ShufflePowerUpsTests: XCTestCase {
    func testUsesPerGameClampsToSupportedRange() {
        XCTAssertEqual(Game2048ShufflePowerUps(usesPerGame: -2).usesPerGame, 0)
        XCTAssertEqual(Game2048ShufflePowerUps(usesPerGame: 3).usesPerGame, 3)
        XCTAssertEqual(Game2048ShufflePowerUps(usesPerGame: 99).usesPerGame, Game2048ShufflePowerUps.maxUsesPerGame)
    }

    func testUseConsumesRemainingUsesAndResetRestoresConfiguredUses() {
        var powerUps = Game2048ShufflePowerUps(usesPerGame: 2)

        XCTAssertTrue(powerUps.use())
        XCTAssertEqual(powerUps.remainingUses, 1)
        XCTAssertTrue(powerUps.use())
        XCTAssertEqual(powerUps.remainingUses, 0)
        XCTAssertFalse(powerUps.use())

        powerUps.resetForNewGame()
        XCTAssertEqual(powerUps.remainingUses, 2)
    }
}
