import XCTest
@testable import Kaleidoscope

final class Game2048BoardLayoutTests: XCTestCase {
    func testDefaultLayoutUsesClassicTileScale() {
        let layout = Game2048BoardLayout()

        XCTAssertEqual(layout.tileSize, 92)
        XCTAssertEqual(layout.gap, 8)
    }

    func testTileSizeIsClampedToUsableRange() {
        XCTAssertEqual(Game2048BoardLayout(tileSize: 12).tileSize, Game2048BoardLayout.minTileSize)
        XCTAssertEqual(Game2048BoardLayout(tileSize: 200).tileSize, Game2048BoardLayout.maxTileSize)
    }

    func testFontSizesScaleWithTileSize() {
        let small = Game2048BoardLayout(tileSize: 60)
        let large = Game2048BoardLayout(tileSize: 120)

        XCTAssertLessThan(small.regularTileFontSize, large.regularTileFontSize)
        XCTAssertLessThan(small.largeTileFontSize, large.largeTileFontSize)
        XCTAssertLessThan(large.largeTileFontSize, large.regularTileFontSize)
    }

    func testBoardSideUsesTileCountAndGapCount() {
        let layout = Game2048BoardLayout(tileSize: 72, gap: 8)

        XCTAssertEqual(layout.boardSide(for: 5), 392)
        XCTAssertEqual(layout.cardSide(for: 5), 392)
    }

    func testTileOriginIsRelativeToCenteredBoardInterior() {
        let layout = Game2048BoardLayout(tileSize: 60, gap: 8)

        XCTAssertEqual(layout.tileOrigin(for: 0, boardSize: 6), Game2048BoardLayout.Point(x: 0, y: 0))
        XCTAssertEqual(layout.tileOrigin(for: 35, boardSize: 6), Game2048BoardLayout.Point(x: 340, y: 340))
    }

    func testTileCenterPositionsFillBoardFromOutlineToOutline() {
        let layout = Game2048BoardLayout()

        XCTAssertEqual(layout.tileCenter(for: 0, boardSize: 4), Game2048BoardLayout.Point(x: 46, y: 46))
        XCTAssertEqual(layout.tileCenter(for: 15, boardSize: 4), Game2048BoardLayout.Point(x: 346, y: 346))
    }
}
