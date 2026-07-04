import XCTest
@testable import Kaleidoscope

/// Guards the 2048 tile palette against the "low tiles are hard to read" regression:
/// every value must pair its number with a high-contrast background, and the 2 and 4
/// tiles specifically must use dark ink on a light background.
final class Game2048TileColorTests: XCTestCase {
    private let darkInk = Game2048TilePalette.RGB(red: 0.16, green: 0.11, blue: 0.07)
    private let lightInk = Game2048TilePalette.RGB(red: 1.0, green: 1.0, blue: 1.0)

    func testTwoTileUsesDarkInkOnLightBackground() {
        let style = Game2048TilePalette.style(for: 2)
        XCTAssertEqual(style.foreground, darkInk)
        XCTAssertGreaterThan(style.background.relativeLuminance, style.foreground.relativeLuminance)
        XCTAssertGreaterThanOrEqual(style.contrastRatio, 7.0)
    }

    func testFourTileUsesDarkInkOnLightHighContrastBackground() {
        let style = Game2048TilePalette.style(for: 4)
        XCTAssertEqual(style.foreground, darkInk)
        XCTAssertGreaterThan(style.background.relativeLuminance, style.foreground.relativeLuminance)
        // The tester flagged the 4 as hard to see; hold it to AAA-level contrast.
        XCTAssertGreaterThanOrEqual(style.contrastRatio, 7.0)
    }

    func testTwoAndFourTilesAreVisuallyDistinct() {
        let two = Game2048TilePalette.style(for: 2)
        let four = Game2048TilePalette.style(for: 4)
        XCTAssertNotEqual(two.background, four.background)
    }

    func testEveryTileValueIsLegible() {
        // Covers 2…2048, plus a 4096+ value that hits the `default` branch.
        let values = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        for value in values {
            let style = Game2048TilePalette.style(for: value)
            XCTAssertGreaterThanOrEqual(
                style.contrastRatio, 4.5,
                "Tile \(value) has weak text/background contrast (\(style.contrastRatio))."
            )
        }
    }

    func testAllTileBackgroundsAreDistinct() {
        let values = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
        let backgrounds = values.map { Game2048TilePalette.style(for: $0).background }
        for i in backgrounds.indices {
            for j in backgrounds.indices where j > i {
                XCTAssertNotEqual(
                    backgrounds[i], backgrounds[j],
                    "Tiles \(values[i]) and \(values[j]) share a background color."
                )
            }
        }
    }
}
