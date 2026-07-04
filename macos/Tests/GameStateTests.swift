import XCTest
@testable import Kaleidoscope

/// End-to-end interaction tests for the shared `GameState` (the object both
/// boards drive via `tap`). Runs human-vs-human so no AI task interferes.
@MainActor
final class GameStateTests: XCTestCase {

    private func play(_ game: GameState, _ from: Square, _ to: Square) {
        game.tap(from)   // select
        game.tap(to)     // move
    }

    func testThreefoldRepetitionDeclaresDraw() {
        let game = GameState()
        game.vsComputer = false

        let g1 = Square(file: 6, rank: 0), f3 = Square(file: 5, rank: 2)
        let g8 = Square(file: 6, rank: 7), f6 = Square(file: 5, rank: 5)

        // Each "knight dance" returns to the start position; after two dances the
        // start position has occurred three times → draw by repetition.
        for _ in 0..<2 {
            play(game, g1, f3)   // Nf3
            play(game, g8, f6)   // Nf6
            play(game, f3, g1)   // Ng1
            play(game, f6, g8)   // Ng8
        }

        XCTAssertEqual(game.status, .draw)
    }

    func testNotYetThreefoldAfterOneDance() {
        let game = GameState()
        game.vsComputer = false
        play(game, Square(file: 6, rank: 0), Square(file: 5, rank: 2)) // Nf3
        play(game, Square(file: 6, rank: 7), Square(file: 5, rank: 5)) // Nf6
        play(game, Square(file: 5, rank: 2), Square(file: 6, rank: 0)) // Ng1
        play(game, Square(file: 5, rank: 5), Square(file: 6, rank: 7)) // Ng8
        XCTAssertNotEqual(game.status, .draw)   // start has occurred only twice
    }

    func testUndoRewindsPositionAndHistory() {
        let game = GameState()
        game.vsComputer = false
        play(game, Square(file: 6, rank: 0), Square(file: 5, rank: 2)) // Nf3
        game.undo()
        XCTAssertEqual(game.position, .initial)
        XCTAssertEqual(game.status, .ongoing)
    }
}
