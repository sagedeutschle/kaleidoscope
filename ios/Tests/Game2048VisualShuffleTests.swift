import XCTest
@testable import Prismet

final class Game2048VisualShuffleTests: XCTestCase {
    func testVisualShuffleIsDeterministicForSeedAndSlotCount() {
        let first = Game2048VisualShuffle(seed: 7, slotCount: 16)
        let second = Game2048VisualShuffle(seed: 7, slotCount: 16)
        let different = Game2048VisualShuffle(seed: 8, slotCount: 16)

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
        XCTAssertEqual(first.effectsByTileIndex.count, 16)
    }

    func testEffectsStayInCompactPhoneFriendlyRange() {
        let shuffle = Game2048VisualShuffle(seed: 12, slotCount: 16)

        XCTAssertTrue(shuffle.effectsByTileIndex.allSatisfy { effect in
            (-3.0...3.0).contains(effect.xOffset)
                && (-3.0...3.0).contains(effect.yOffset)
                && (-7.0...7.0).contains(effect.rotationDegrees)
                && (0.96...1.04).contains(effect.scale)
        })
        XCTAssertTrue(shuffle.effectsByTileIndex.contains { !$0.isNeutral })
    }

    func testFourTileUsesReadableHighContrastPalette() {
        let style = Game2048TilePalette.style(for: 4)
        let twoStyle = Game2048TilePalette.style(for: 2)

        XCTAssertGreaterThanOrEqual(style.contrastRatio, 7.0)
        XCTAssertNotEqual(style.background, twoStyle.background)
    }
}
