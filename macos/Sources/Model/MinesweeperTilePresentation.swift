import Foundation

struct MinesweeperTilePresentation: Equatable {
    enum Kind: Equatable {
        case hidden
        case flagged
        case revealed
        case mine
    }

    let kind: Kind
    let symbol: String
    let textColorName: String

    init(game: MinesweeperGame, row: Int, col: Int) {
        if game.isFlagged(row: row, col: col) {
            kind = .flagged
            symbol = "⚑"
            textColorName = "red"
            return
        }

        guard game.isRevealed(row: row, col: col) else {
            kind = .hidden
            symbol = ""
            textColorName = "clear"
            return
        }

        if game.hasMine(row: row, col: col) {
            kind = .mine
            symbol = "●"
            textColorName = "black"
            return
        }

        kind = .revealed
        let count = game.adjacentMineCount(row: row, col: col)
        symbol = count == 0 ? "" : "\(count)"
        textColorName = Self.colorName(forAdjacentMineCount: count)
    }

    private static func colorName(forAdjacentMineCount count: Int) -> String {
        switch count {
        case 1: return "blue"
        case 2: return "green"
        case 3: return "red"
        case 4: return "navy"
        case 5: return "maroon"
        case 6: return "teal"
        case 7: return "black"
        case 8: return "gray"
        default: return "clear"
        }
    }
}
