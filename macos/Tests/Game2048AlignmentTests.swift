import Testing
import CoreGraphics
@testable import Prismet

struct Game2048AlignmentTests {
    @Test func boardOutlineMatchesTileMatrix() {
        let layout = Game2048BoardLayout()

        #expect(layout.boardSide(for: 4) == 392)
        #expect(layout.cardSide(for: 4) == layout.boardSide(for: 4))
    }

    @Test func boardFrameHasNoExtraInsetBetweenOutlineAndTiles() {
        let layout = Game2048BoardLayout()
        let boardSide = layout.boardSide(for: 4)
        let cardSide = layout.cardSide(for: 4)

        let inset = (cardSide - boardSide) / 2

        #expect(inset == 0)
    }
}
