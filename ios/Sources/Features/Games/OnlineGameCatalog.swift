import SwiftUI

// PRISM: RELEASE Agent-Design/Claude 2026-07-12 — reusable online-game registry.
//
// Single source of truth for "which games can be played online and how." Adding a
// game to online play used to require editing five separate CanonicalGameID switches
// (OnlineGameLobbyView.supportedGames, .initialStateJSON, .gameContainer, plus the
// GamePlayMode/GameModeCatalog mode + the HomeView routing gate). Now a game opts in
// with ONE entry here, and OnlineGameLobbyView reads everything off this catalog.
//
// ── TO ADD A GAME TO ONLINE PLAY (next agent — three small steps) ─────────────────
//   1. Add an `OnlineGameDescriptor` to `all` below: a fresh encoded snapshot + a view
//      builder + its seat range. Set `isAvailable: true`.
//   2. Move its `CanonicalGameID` into an online-capable branch of
//      `GameModeCatalog.optionsForCatalog` (ios/Sources/Core/Games/GamePlayMode.swift)
//      so the launch mode picker offers "Online friend".
//   3. Give the game view an `(accountID:playMode:online:)` init and implement the
//      send/receive contract — `ReversiView.sendMove()` + `applyRemoteIfNeeded()` +
//      `.onChange(of: online.match?.moveCount)` is the reference implementation.
// The lobby allowlist, routing gate, and snapshot plumbing all flow from this list —
// no other switches to touch.

/// Everything the online lobby needs to host / join / hand off one game.
struct OnlineGameDescriptor {
    let gameID: CanonicalGameID
    /// Player-seat range. The current Supabase match envelope supports exactly two
    /// seats (host + one guest), so games needing 3+ are registered but left
    /// `isAvailable: false` until the N-seat match model lands (see `notes`).
    let seats: ClosedRange<Int>
    /// Whether online play is live for this game right now (drives the lobby allowlist).
    let isAvailable: Bool
    /// Fresh, encoded starting snapshot — identical to the game's own save format.
    let makeInitialStateJSON: () throws -> String
    /// Builds the live game view around a seated match session.
    let makeGameView: (OnlineMatchSession) -> AnyView
    /// Maintainer notes (e.g. what a not-yet-available game still needs).
    var notes: String = ""
}

enum OnlineGameCatalog {
    static let all: [OnlineGameDescriptor] = [
        OnlineGameDescriptor(
            gameID: .chess, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: {
                try GameSaveCodec.encodeSnapshot(ChessSnapshot(
                    position: .initial, selected: nil, targets: [], status: .ongoing, lastFrom: nil, lastTo: nil))
            },
            makeGameView: { AnyView(ChessView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        OnlineGameDescriptor(
            gameID: .checkers, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(CheckersSnapshot(game: CheckersGame(), selected: nil)) },
            makeGameView: { AnyView(CheckersView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        OnlineGameDescriptor(
            gameID: .connectFour, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(ConnectFourSnapshot(game: ConnectFourGame())) },
            makeGameView: { AnyView(ConnectFourView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        OnlineGameDescriptor(
            gameID: .reversi, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(ReversiSnapshot(game: ReversiGame())) },
            makeGameView: { AnyView(ReversiView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        OnlineGameDescriptor(
            gameID: .gomoku, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(GomokuSnapshot(game: GomokuGame())) },
            makeGameView: { AnyView(GomokuView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        OnlineGameDescriptor(
            gameID: .crazyEight, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(CrazyEightSnapshot(game: CrazyEightGame.newGame(seed: 51), seed: 51)) },
            makeGameView: { AnyView(CrazyEightView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        OnlineGameDescriptor(
            gameID: .seaBattle, seats: 2...2, isAvailable: true,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(SeaBattleSnapshot(game: .deploymentGame, setup: .empty)) },
            makeGameView: { AnyView(SeaBattleView(accountID: nil, playMode: .onlineFriend, online: $0)) }
        ),
        // Catan is registered so the seam knows it exists, but NOT yet available online:
        // the Supabase match envelope is host + one guest (2 seats) and Catan needs 3–4.
        // To turn it on (next agent): (a) extend the match model to N seats — participants
        // array + RLS, backend lane; (b) give CatanView an (accountID:playMode:online:) init
        // and a seat-index→player map (each seated UUID → a CatanGame player index in join
        // order; drive turns off `currentTurnUserID == my seat` instead of a bool; send the
        // full CatanSnapshot as stateJSON on every action, like Reversi); (c) flip
        // `isAvailable: true` here and move `.catan` to an online branch of
        // GameModeCatalog.optionsForCatalog.
        OnlineGameDescriptor(
            gameID: .catan, seats: 3...4, isAvailable: false,
            makeInitialStateJSON: { try GameSaveCodec.encodeSnapshot(CatanSnapshot(game: .newGame(seed: 1))) },
            makeGameView: { _ in AnyView(EmptyView()) },
            notes: "Needs the N-seat match model + a seat-index→CatanGame player mapping before it can go live."
        )
    ]

    static func descriptor(for gameID: CanonicalGameID) -> OnlineGameDescriptor? {
        all.first { $0.gameID == gameID }
    }

    /// Games playable online right now — the lobby allowlist.
    static var availableGameIDs: Set<CanonicalGameID> {
        Set(all.filter(\.isAvailable).map(\.gameID))
    }

    static func supports(_ gameID: CanonicalGameID) -> Bool {
        descriptor(for: gameID)?.isAvailable == true
    }

    static func initialStateJSON(for gameID: CanonicalGameID) throws -> String {
        guard let descriptor = descriptor(for: gameID), descriptor.isAvailable else {
            throw OnlineMatchError.notConfigured
        }
        return try descriptor.makeInitialStateJSON()
    }

    @ViewBuilder
    static func gameView(for gameID: CanonicalGameID, session: OnlineMatchSession) -> some View {
        if let descriptor = descriptor(for: gameID), descriptor.isAvailable {
            descriptor.makeGameView(session)
        } else {
            EmptyView()
        }
    }
}
