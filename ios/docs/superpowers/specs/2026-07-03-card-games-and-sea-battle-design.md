# Card Games and Sea Battle Design

## Scope

Add three clean-room games to the iOS Kaleidoscope game catalog:

- Spider: one-suit Spider Solitaire, solo only.
- Crazy 8: two-player card game, local and online friend.
- Sea Battle: two-player hidden-grid battle game, local and online friend.

## Architecture

Each game has a pure Swift model under `Sources/Core/Games` and a SwiftUI view under `Sources/Features/Games`. Models are `Codable`, `Equatable`, and `Hashable` so they can use the existing `PersistedGameSession` and online snapshot codec.

Spider stays solo because it is a solitaire game. Crazy 8 and Sea Battle use the same `OnlineGameLobbyView` handoff as Chess, Checkers, Connect Four, Reversi, and Gomoku: the host seeds an initial snapshot, both clients mutate the full snapshot, and each move writes the next serialized state to the online match.

## Behavior

Spider deals ten tableau piles from a deterministic one-suit 104-card deck, supports legal descending run moves, deals stock rows only when no tableau pile is empty, and clears complete King-to-Ace runs.

Crazy 8 deals seven cards to each player, tracks a discard pile/current suit, allows matching rank, matching suit, or eights, lets eights declare a suit, supports drawing one card, and records the winner when a hand empties.

Sea Battle creates deterministic 10x10 fleets for both players, records shots against the opponent board, rejects repeated shots, keeps the turn on a hit, passes on a miss, and ends when all opposing ship cells are hit.

## Testing

Focused tests cover model rules, snapshot round trips, mode catalog coverage, online initial-state decoding, and Home catalog placement. Full simulator build and strict macOS parity gate remain required before completion.
