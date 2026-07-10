import XCTest
@testable import Prismet

final class MinesweeperInteractionTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func minesweeperSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("Sources/Features/Games/MinesweeperView.swift"))
    }

    func testCellsUseHighPriorityLongPressForFlagging() throws {
        let source = try minesweeperSource()

        XCTAssertTrue(source.contains(".highPriorityGesture("))
        XCTAssertTrue(source.contains("LongPressGesture(minimumDuration: 0.3)"))
        XCTAssertTrue(source.contains("flag(row: row, col: col)"))
    }

    func testPinchZoomDoesNotRelayoutEveryGestureFrame() throws {
        let source = try minesweeperSource()

        XCTAssertTrue(source.contains("@GestureState private var pinchScale"))
        XCTAssertTrue(source.contains(".updating($pinchScale)"))
        XCTAssertTrue(source.contains(".scaleEffect(liveZoomScale"))
        XCTAssertFalse(source.contains(".onChanged { value in\n                        if pinchStartZoom"))
    }

    func testExpertPresetDefaultsToThirtyByThirty() throws {
        let preset = try XCTUnwrap(MinesweeperDifficulty.expert.preset)

        XCTAssertEqual(preset.width, 30)
        XCTAssertEqual(preset.height, 30)
        XCTAssertEqual(preset.mineCount, 186)
    }
}
