import XCTest
@testable import Kaleidoscope

final class SnakeTilePresentationTests: XCTestCase {
    func testClassifiesHeadBodyTailAndApple() {
        let game = SnakeGame(width: 6,
                             height: 6,
                             body: [
                                SnakePoint(row: 2, col: 3),
                                SnakePoint(row: 2, col: 2),
                                SnakePoint(row: 2, col: 1)
                             ],
                             direction: .right,
                             apple: SnakePoint(row: 0, col: 0))

        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 3), in: game).kind, .head)
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 2), in: game).kind, .body)
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 1), in: game).kind, .tail)
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 0, col: 0), in: game).kind, .apple)
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 5, col: 5), in: game).kind, .empty)
    }

    func testUsesOpenSourceSpriteAssetNames() {
        let game = SnakeGame(width: 6,
                             height: 6,
                             body: [
                                SnakePoint(row: 2, col: 3),
                                SnakePoint(row: 2, col: 2),
                                SnakePoint(row: 2, col: 1)
                             ],
                             direction: .right,
                             apple: SnakePoint(row: 0, col: 0))

        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 3), in: game).assetName, "snake_head_right")
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 2), in: game).assetName, "snake_body_horizontal")
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 1), in: game).assetName, "snake_tail_right")
        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 0, col: 0), in: game).assetName, "snake_apple")
    }

    func testCornerBodyUsesCornerSprite() {
        let game = SnakeGame(width: 6,
                             height: 6,
                             body: [
                                SnakePoint(row: 1, col: 2),
                                SnakePoint(row: 2, col: 2),
                                SnakePoint(row: 2, col: 1)
                             ],
                             direction: .up,
                             apple: SnakePoint(row: 0, col: 0))

        XCTAssertEqual(SnakeTilePresentation.presentation(for: SnakePoint(row: 2, col: 2), in: game).assetName, "snake_body_topleft")
    }
}
