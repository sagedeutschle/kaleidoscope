import SwiftUI

// Maps a GameCard id to its custom, hand-drawn app-icon glyph.
// Glyph views live in GameGlyphs+Arcade / +GridPuzzles / +Board / +CardsMisc.
@ViewBuilder
func gameGlyph(for id: String) -> some View {
    switch id {
    case "2048": Glyph2048()
    case "snake": GlyphSnake()
    case "sliding": GlyphSliding()
    case "lightsout": GlyphLightsOut()
    case "sudoku": GlyphSudoku()
    case "nonogram": GlyphNonogram()
    case "minesweeper": GlyphMinesweeper()
    case "rubiks": GlyphRubiks()
    case "chess": GlyphChess()
    case "checkers": GlyphCheckers()
    case "reversi": GlyphReversi()
    case "connectfour": GlyphConnectFour()
    case "solitaire": GlyphSolitaire()
    case "brickbench": GlyphBrickBench()
    case "oracle": GlyphOracle()
    case "debtclock": GlyphDebtClock()
    case "wordle": GlyphWordgame()
    default: EmptyView()
    }
}

// Cards whose id has a full-color tile_<id> asset in GameIcons.
let gameTileImageIDs: Set<String> = [
    "2048", "snake", "sliding", "lightsout", "sudoku", "nonogram", "minesweeper", "rubiks",
    "chess", "checkers", "reversi", "connectfour", "solitaire", "brickbench", "oracle",
    "debtclock", "wordle", "gomoku", "spider", "crazyeight", "seabattle", "steamrewind"
]
