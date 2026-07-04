// PRISM: RELEASE Agent-Design(shell) 2026-07-03 — v10 design pass
#if DEBUG
import SwiftUI

/// Launch-flag screenshot harness — **DEBUG only**, so it is compiled out of the
/// Release (App Store) build entirely and can never ship.
///
/// When the process is launched with the env var `KALEIDO_SHOT` set to a screen
/// name, `RootView` renders this instead of the auth gate, dropping straight into
/// a single game view. That lets App Store screenshots be captured headlessly on a
/// simulator (no phone-OTP sign-in needed):
///
///   SIMCTL_CHILD_KALEIDO_SHOT=chess3d xcrun simctl launch <dev> com.spocksclub.kaleidoscope
///   xcrun simctl io <dev> screenshot chess3d.png
struct ShotHarness: View {
    let screen: String

    init(screen: String) {
        self.screen = screen
        // Force the chess board dimension so the 2D and 3D variants can both be shot.
        switch screen {
        case "chess2d": UserDefaults.standard.set(false, forKey: "chess.is3D")
        case "chess3d": UserDefaults.standard.set(true, forKey: "chess.is3D")
        default: break
        }
    }

    var body: some View {
        NavigationStack { content }
            .tint(Kaleido.gold)
    }

    @ViewBuilder private var content: some View {
        switch screen {
        case "chess3d", "chess2d": ChessView(accountID: nil, playMode: .soloBot)
        case "2048":               Game2048View()
        case "wordle":             WordleView()
        case "minesweeper":        MinesweeperView()
        case "minesweeper30":      MinesweeperView(initialGame: MinesweeperGame(width: 30, height: 30, mineCount: 120, seed: 7))
        case "solitaire":          SolitaireView()
        case "sudoku":             SudokuView()
        case "rubiks":             RubiksCubeView()
        case "brickbench":         BrickBenchView()
        case "snake":              SnakeView()
        case "nonogram":           NonogramView()
        case "reversi":            ReversiView()
        case "checkers":           CheckersView(accountID: nil, playMode: .soloBot)
        case "gomoku":             GomokuView(accountID: nil, playMode: .soloBot)
        case "spider":             SpiderView()
        case "crazyeight":         CrazyEightView(accountID: nil, playMode: .soloBot)
        case "seabattle":          SeaBattleView(accountID: nil, playMode: .soloBot)
        case "oracle":             OracleView()
        case "debtclock":          DebtClockStatsView()
        case "moguls":             MogulBoardView()   // The Moguls board, direct
        case "steamrewind":        SteamRewindView()  // Steam Rewind lens (demo library)
        case "moguldetail":        // First bundled mogul's full bench discourse
            if let mogul = MogulSource.loadBundled()?.ranked.first {
                MogulDetailSheet(mogul: mogul)
            } else {
                Text("no bundled moguls")
            }
        case "settings":           SettingsView()
        case "glyphs":             AllGlyphsGrid()
        default:                   ChessView(accountID: nil, playMode: .soloBot)
        }
    }
}

/// DEBUG-only grid of every custom game glyph, for one-shot visual verification.
struct AllGlyphsGrid: View {
    let items: [(String, String)] = [
        ("2048", "2048"), ("snake", "Snake"), ("sliding", "Sliding"), ("lightsout", "Lights Out"),
        ("sudoku", "Sudoku"), ("nonogram", "Nonogram"), ("minesweeper", "Mines"), ("rubiks", "Rubik's"),
        ("chess", "Chess"), ("checkers", "Checkers"), ("reversi", "Reversi"), ("connectfour", "Connect 4"),
        ("solitaire", "Solitaire"), ("brickbench", "Brick"), ("oracle", "Oracle"), ("debtclock", "Debt"),
        ("wordle", "Word"), ("gomoku", "Gomoku"), ("seabattle", "Sea Battle"), ("spider", "Spider"),
        ("crazyeight", "Crazy 8")
    ]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 14)], spacing: 18) {
                ForEach(items, id: \.0) { item in
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Color(white: 0.22))
                            if gameTileImageIDs.contains(item.0) {
                                Image("tile_\(item.0)")
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFill()
                                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            } else {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 74, height: 74)
                        Text(item.1).font(.caption2)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Glyphs")
    }
}
#endif
