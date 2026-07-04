# Kaleidoscope — Rebrand + Fidget Shell (Wave 1)

Date: 2026-06-27
Status: Design — pending user review

## Vision

`ChessHotSwap` has outgrown its name. It is now a single window you flip between a
pile of little games, fidgets, and the Wizard King's Decree. Rename it
**Kaleidoscope** and rebuild the shell around that idea: a home screen that *is* the
lens, and every tool is a colorful **facet**. Turn the lens, a new game/fidget/prophecy
snaps into view.

Tagline: *"turn the lens."*

## Scope of this spec (Wave 1)

This spec covers exactly three things:

1. **Rebrand** `ChessHotSwap` → `Kaleidoscope` (project, bundle id, module, app entry, window
   title, persistence directory, all test imports).
2. **New shell**: a Home "lens" launcher grid + a `Facet` abstraction that replaces the
   segmented workspace picker (which does not scale past ~12 tools).
3. **Three new facets** that prove the pattern end to end: **3D Rubik's Cube**, **2048**,
   **Lights Out**.

Everything else is explicitly out of scope (see Non-Goals) and lands in later waves.

## Goals

- The app launches to a Home grid of facet tiles, grouped by category, and you enter/leave
  facets with a visible "lens turn" transition.
- Adding a future game costs *one descriptor + its view/model* — no shell surgery.
- The four existing tools (Chess, Brick Bench, Wordle, Oracle) all work unchanged behind
  the new shell, including the chess toolbar.
- Three new playable facets ship: Rubik's Cube (SceneKit), 2048, Lights Out.
- The existing 91 tests stay green after the rename; new model logic is unit-tested.

## Non-Goals (deferred to later waves / lanes)

- The remaining games — **Sudoku, Minesweeper, Sliding-15, Nonogram, 3D Reversi** — are
  Waves 2–3, their own specs.
- App-wide lane: stats/streaks "Trophy Room", command palette, iCloud sync, menu-bar mode,
  unified theming overhaul.
- Deepen-Chess lane: move-list, eval bar, PGN, puzzles.
- Finish-in-flight lane: BrickLink live API, Oracle live data, Wordle remote endpoint.
- Rubik's Cube **solver/hint** is a stretch, not required for Wave 1 (scramble + turn +
  solve-detection + timer is the bar).

## Build order (the whole game set, in waves)

| Wave | Contents |
|------|----------|
| **1 (this spec)** | Rebrand + Home/Facet shell + 🧩 3D Rubik's Cube + 🟦 2048 + 💡 Lights Out |
| 2 | 🔢 Sudoku (generator+solver) · 💣 Minesweeper · 🔀 Sliding-15 |
| 3 | ▦ Nonogram/Picross · ⚫ 3D Reversi (with AI) |

Each wave is its own spec → plan → build. Not-yet-built games appear as greyed
"coming soon" tiles on the Home grid.

## Design

### 1. Rebrand

Module name follows `PRODUCT_NAME`, so renaming the product renames the Swift module;
every `@testable import` must follow.

- **`project.yml`**: `name`, target `ChessHotSwap`, `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER`
  (`com.gtrktscrb.chesshotswap` → `com.gtrktscrb.kaleidoscope`), `INFOPLIST_KEY_CFBundleDisplayName`
  ("Chess HotSwap" → "Kaleidoscope"), and the test target `ChessHotSwapTests` → `KaleidoscopeTests`
  (+ its dependency + bundle id).
- **`Sources/App/ChessHotSwapApp.swift`** → **`KaleidoscopeApp.swift`**: rename the file, the
  `@main struct ChessHotSwapApp` → `KaleidoscopeApp`, and `WindowGroup("Chess HotSwap")` →
  `WindowGroup("Kaleidoscope")`.
- **All 15 test files**: `@testable import ChessHotSwap` → `@testable import Kaleidoscope`.
- **Folder + project**: rename `apps/chess-hotswap` → `apps/kaleidoscope` and
  `ChessHotSwap.xcodeproj` → `Kaleidoscope.xcodeproj`. The app dir is still untracked in git, so
  this is the cheapest moment. Consequence: the DerivedData path changes — update the launch
  command in `docs/HANDOFF.md`.

#### Persistence directory migration (data-safety detail)

`GamePersistence.swift:199` stores state under Application Support `…/ChessHotSwap/`. Rename
the directory to `…/Kaleidoscope/`, but add a **one-time migration**: on first access, if the
old `ChessHotSwap` directory exists and the new `Kaleidoscope` one does not, move it. This
preserves any in-progress chess game and word-puzzle state. Covered by a unit test using a
temp directory.

### 2. The shell: Home lens + Facets

Replace the segmented `Picker` with a launcher. Each tool is described by one value type:

```swift
enum FacetCategory: String, CaseIterable { case play, daily, tinker, oracle }
enum FacetStatus { case ready, comingSoon }

struct FacetDescriptor: Identifiable {
    let id: String                 // stable key, e.g. "chess", "cube"
    let title: String              // "Chess", "Rubik's Cube"
    let systemImage: String
    let accent: Color              // the tile's kaleidoscope color
    let category: FacetCategory
    let status: FacetStatus
    let makeView: () -> AnyView    // the facet's root view
}

enum FacetRegistry {
    static let all: [FacetDescriptor] = [ /* … */ ]
}
```

**Registry contents (Wave 1):**

- `.ready`: Chess, Brick Bench, Wordle, Oracle (existing) + Rubik's Cube, 2048, Lights Out (new).
- `.comingSoon`: Sudoku, Minesweeper, Sliding-15, Nonogram, Reversi.
- Category mapping: Chess/2048/Lights Out → `.play`; Rubik's Cube/Brick Bench → `.tinker`;
  Wordle → `.daily`; Oracle → `.oracle`. (Coming-soon games slot into their eventual category.)

**`HomeLensView`** — renders `FacetRegistry.all` grouped by category into a `LazyVGrid` of
`FacetTile`s. `.ready` tiles are tappable and set the active facet; `.comingSoon` tiles render
greyed and disabled. Tile = rounded card with the facet's icon, title, and accent gradient.

**Root view** (`ContentView` renamed to `KaleidoscopeRootView`):

```swift
@State private var activeFacetID: String? = nil   // nil = Home
```

- `activeFacetID == nil` → `HomeLensView`.
- otherwise → the facet's `makeView()` wrapped in shell chrome: a **Home** button + the facet
  title; the facet supplies its own toolbar/footer internally.
- Transition between Home and a facet is an asymmetric scale + opacity ("lens turn").
- Keyboard: `⌘1…⌘9` jump to the *n*-th ready facet; `Esc` / `⌘.` returns Home.

### 3. ContentView refactor (improve code we're working in)

`ContentView` currently owns chess state, the word session, persistence bootstrap, *and* the
chess toolbar — too many jobs. Wave 1 splits it:

- Extract chess into **`ChessFacetView`** (owns its `GameState`, the 2D/3D board, and the chess
  toolbar/footer that today live at root). The shell no longer knows anything chess-specific.
- Each facet view owns its own state (`@StateObject`) and its own persistence bootstrap, keyed
  by the existing `windowSessionID` passed down via the environment. No behavior change for the
  existing tools — purely a relocation so the shell is generic.
- `AppWorkspace` enum is retired in favor of `FacetRegistry`. `AppWorkspaceTests` becomes a
  registry test (see Testing).

### 4. New facets (Wave 1)

Each new facet = a pure-value **model** (deterministic, fully unit-tested using seeded
randomness — no `Date.now()`/`Math.random()` equivalents in tests) + a **view**.

**🧩 Rubik's Cube** (marquee; heaviest item)
- Model `RubiksCube`: 3×3×3 sticker/cubie state. `apply(_ move: Move)` for U/D/L/R/F/B + primes
  + doubles; `scramble(seed:)`; `isSolved` (every face uniform).
- View `RubiksCubeView`: SceneKit via `NSViewRepresentable` (same approach as `Board3DView`).
  Renders 27 rounded cubies with colored stickers; drag a face to rotate that layer (hit-test
  cubie+face → axis → animated layer turn). Controls: Scramble, Reset, elapsed timer, move
  counter, "Solved!" banner.
- Tests: solved initial state; `move` then its inverse → solved; the sexy-move identity
  `(R U R' U')` ×6 → solved; seeded scramble is non-solved; applying a recorded scramble's
  inverse sequence → solved.

**🟦 2048**
- Model `Game2048`: 4×4 grid. `move(_ dir)` with slide+merge (single merge per tile per move),
  seeded spawn of 2/4 after any board-changing move, `score`, `hasWon` (2048), `isGameOver`.
- View `Game2048View`: SwiftUI grid, value-keyed tile colors, arrow-key + drag input, score,
  New Game, win/lose banner.
- Tests: `[2,2,0,0] → [4,0,0,0]`; no chained merge `[2,2,4,0] → [4,4,0,0]`; a non-changing move
  spawns nothing; game-over when full with no merges; win flag at 2048.

**💡 Lights Out**
- Model `LightsOut`: 5×5 bool grid. `press(row,col)` flips itself + orthogonal neighbors;
  `isSolved` (all off); `scramble(seed:)` by applying random valid presses (guarantees solvable).
- View `LightsOutView`: SwiftUI grid of lit/unlit buttons, press count, New Game, solved banner.
- Tests: pressing the same cell twice is identity; corner press flips exactly 3 cells, center
  flips 5; a scramble built from presses is solved by re-applying those same presses.

## Testing & verification

- **Rename safety:** after the module rename, all 15 test files import `Kaleidoscope`; the full
  suite (currently **91 tests, 0 failures**) must still pass.
- **`AppWorkspaceTests` → registry test:** assert the registry exposes the expected ready facets
  and that the Wordle facet's title is "Wordle" (preserves the original intent).
- **Migration test:** old→new Application Support directory move, in a temp dir.
- **New model tests:** cube, 2048, Lights Out as listed above.
- **Gate:** `xcodegen generate` then
  `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test`
  must report `** TEST SUCCEEDED **` before Wave 1 is claimed done. Runtime smoke-check: launch,
  confirm Home grid renders, enter each new facet, scramble/play/solve once.

## Risks & decisions

- **Navigation model:** decided — Home-grid launcher (on-brand for "Kaleidoscope"), not a
  sidebar.
- **Persistence rename:** decided — rename dir to `Kaleidoscope` *with* one-time migration to
  avoid orphaning saves.
- **Rubik's face-turn interaction** is the main technical unknown (SceneKit hit-testing + layer
  rotation). If drag-to-turn proves fiddly within Wave 1, fall back to on-screen move buttons
  (U/D/L/R/F/B ± ) for v1 and revisit drag later; the model is unaffected either way.

## Out of scope reminder

No stats system, no command palette, no theming overhaul, no chess-analysis features, no live
data integrations, and only three of the eight planned new games. Those are named, sequenced,
and waiting in later waves.
