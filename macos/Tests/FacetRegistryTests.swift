import XCTest
@testable import Prismet

final class FacetRegistryTests: XCTestCase {
    func testCategoryOrderMatchesLaunchGrouping() {
        XCTAssertEqual(FacetCategory.allCases.map(\.rawValue),
                       ["Daily", "Puzzles", "Board", "Cards", "Oracle"])
    }

    func testReadyFacetIDsMatchWave1() {
        XCTAssertEqual(FacetRegistry.ready.map(\.id),
                       ["chess", "brick-bench", "wordle", "oracle", "debt-clock", "rubiks-cube", "2048", "lights-out", "minesweeper", "snake", "sudoku", "sliding-15", "nonogram", "reversi", "connect-four", "checkers", "solitaire"])
        XCTAssertEqual(FacetRegistry.descriptor(for: "wordle")?.title, "Wordgame")
    }

    func testReadyFacetsUseRequestedLaunchCategories() {
        XCTAssertEqual(FacetRegistry.descriptor(for: "wordle")?.category.rawValue, "Daily")
        XCTAssertEqual(FacetRegistry.descriptor(for: "2048")?.category.rawValue, "Puzzles")
        XCTAssertEqual(FacetRegistry.descriptor(for: "snake")?.category.rawValue, "Puzzles")
        XCTAssertEqual(FacetRegistry.descriptor(for: "rubiks-cube")?.category.rawValue, "Puzzles")
        XCTAssertEqual(FacetRegistry.descriptor(for: "chess")?.category.rawValue, "Board")
        XCTAssertEqual(FacetRegistry.descriptor(for: "checkers")?.category.rawValue, "Board")
        XCTAssertEqual(FacetRegistry.descriptor(for: "solitaire")?.category.rawValue, "Cards")
        XCTAssertEqual(FacetRegistry.descriptor(for: "brick-bench")?.category.rawValue, "Oracle")
        XCTAssertEqual(FacetRegistry.descriptor(for: "oracle")?.category.rawValue, "Oracle")
        XCTAssertEqual(FacetRegistry.descriptor(for: "debt-clock")?.category.rawValue, "Oracle")
    }

    func testFormerComingSoonFacetsAreReady() {
        let comingSoonIDs = FacetRegistry.all
            .filter { $0.status == .comingSoon }
            .map(\.id)

        XCTAssertFalse(comingSoonIDs.contains("rubiks-cube"), "Rubik's Cube ships in Wave 1 and should be ready")
        XCTAssertFalse(comingSoonIDs.contains("minesweeper"), "Minesweeper ships in Wave 2 and should be ready")
        XCTAssertFalse(comingSoonIDs.contains("snake"), "Snake ships in Wave 2 and should be ready")
        XCTAssertFalse(comingSoonIDs.contains("sliding-15"), "Sliding-15 ships in Wave 2 and should be ready")
        XCTAssertFalse(comingSoonIDs.contains("sudoku"), "Sudoku is now playable")
        XCTAssertFalse(comingSoonIDs.contains("nonogram"), "Nonogram is now playable")
        XCTAssertFalse(comingSoonIDs.contains("reversi"), "Reversi is now playable")
        XCTAssertFalse(comingSoonIDs.contains("connect-four"), "Connect Four is now playable")
        XCTAssertFalse(comingSoonIDs.contains("checkers"), "Checkers is now playable")
    }
}
