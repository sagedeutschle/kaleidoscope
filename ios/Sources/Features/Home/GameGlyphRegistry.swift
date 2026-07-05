// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — leaderboards/identity pass does not touch tile art.
// This app now renders tile-backed cards only from image assets listed below.
// Cards whose id has a full-color tile_<id> asset in GameIcons.
let gameTileImageIDs: Set<String> = [
    "2048", "snake", "sliding", "lightsout", "sudoku", "nonogram", "minesweeper", "rubiks",
    "chess", "checkers", "reversi", "connectfour", "solitaire", "brickbench", "oracle",
    "debtclock", "wordle", "gomoku", "spider", "crazyeight", "seabattle", "steamrewind"
]
