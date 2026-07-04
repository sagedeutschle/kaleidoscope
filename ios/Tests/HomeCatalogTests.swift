import XCTest
@testable import Kaleidoscope

final class HomeCatalogTests: XCTestCase {
    func testHomeCategoryOrderMatchesLaunchGrouping() {
        // v10: "Oracle" catch-all split into Workshop (builders) + Lenses (live data),
        // per outside design feedback — Sage-approved 2026-07-03.
        XCTAssertEqual(GameCard.categoryOrder, ["Daily", "Puzzles", "Board", "Cards", "Workshop", "Lenses"])
    }

    func testHomeCardsUseRequestedLaunchCategories() throws {
        let cardsByID = Dictionary(uniqueKeysWithValues: GameCard.all.map { ($0.id, $0) })

        XCTAssertEqual(cardsByID["2048"]?.category, "Puzzles")
        XCTAssertEqual(cardsByID["snake"]?.category, "Puzzles")
        XCTAssertEqual(cardsByID["gomoku"]?.category, "Board")
        XCTAssertEqual(cardsByID["seabattle"]?.category, "Board")
        XCTAssertEqual(cardsByID["solitaire"]?.category, "Cards")
        XCTAssertEqual(cardsByID["spider"]?.category, "Cards")
        XCTAssertEqual(cardsByID["crazyeight"]?.category, "Cards")
        XCTAssertEqual(cardsByID["brickbench"]?.category, "Workshop")
        XCTAssertEqual(cardsByID["oracle"]?.category, "Lenses")
        XCTAssertEqual(cardsByID[GameCard.debtClockID]?.category, "Lenses")

        let categories = Set(GameCard.all.map(\.category))
        XCTAssertFalse(categories.contains("Arcade"))
        XCTAssertFalse(categories.contains("Build"))
    }
}
