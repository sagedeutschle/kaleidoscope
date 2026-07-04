import XCTest
@testable import Kaleidoscope

final class MinesweeperInteractionModeTests: XCTestCase {
    func testLeftClickChoosesCell() {
        XCTAssertEqual(MinesweeperInteractionMode.mode(forMouseButton: 0), .choose)
    }

    func testRightClickFlagsCell() {
        XCTAssertEqual(MinesweeperInteractionMode.mode(forMouseButton: 1), .flag)
    }
}
