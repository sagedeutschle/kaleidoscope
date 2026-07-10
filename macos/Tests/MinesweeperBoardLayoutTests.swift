import XCTest
@testable import Prismet

final class MinesweeperBoardLayoutTests: XCTestCase {
    func testTightLayoutKeepsCellsDenselyPacked() {
        let layout = MinesweeperBoardLayout.tight

        XCTAssertLessThanOrEqual(layout.cellSize, 32)
        XCTAssertLessThanOrEqual(layout.cellSpacing, 2)
        XCTAssertLessThanOrEqual(layout.boardPadding, 8)
    }

    func testContentSizesFitInsideCompactCells() {
        let layout = MinesweeperBoardLayout.tight

        XCTAssertLessThan(layout.numberFontSize, layout.cellSize)
        XCTAssertLessThan(layout.symbolFontSize, layout.cellSize)
    }

    func testZoomedLayoutScalesCellsAndContent() {
        let normal = MinesweeperBoardLayout.tight
        let zoomed = normal.scaled(by: 1.4)

        XCTAssertGreaterThan(zoomed.cellSize, normal.cellSize)
        XCTAssertGreaterThan(zoomed.numberFontSize, normal.numberFontSize)
        XCTAssertGreaterThan(zoomed.symbolFontSize, normal.symbolFontSize)
        XCTAssertLessThanOrEqual(zoomed.cellSpacing, 3)
    }

    func testZoomedLayoutClampsToUsableRange() {
        let tiny = MinesweeperBoardLayout.tight.scaled(by: 0.1)
        let huge = MinesweeperBoardLayout.tight.scaled(by: 9)

        XCTAssertEqual(tiny.cellSize, MinesweeperBoardLayout.minCellSize)
        XCTAssertEqual(huge.cellSize, MinesweeperBoardLayout.maxCellSize)
    }
}
