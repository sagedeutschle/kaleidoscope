# Prismet macOS -> iOS Game Parity

PRISM: Agent-Ads/Codex, 2026-06-30 14:13 EDT — working matrix for the user's
"all mac version features into phone version, per game" request.

Desktop reference: `macos/` (repo-relative). Phone target: `ios/` (repo-relative).
Shared Swift package: `shared/PrismetShared/`.
(Both apps + the shared package now live in one monorepo — see the root `AGENTS.md`.)

## Required Gate for Future Changes

The user wants cross-platform parity to be automatic. For every user-visible iOS
change, agents must make a macOS parity decision in the same turn:

- **Mirrored:** port the behavior to the macOS app and verify it there.
- **Not applicable:** write the reason here or in `docs/AGENT-COORDINATION.md`.
- **Tracked debt:** add a row/note with owner, blocker, and next action.

Before an iOS tester/review deploy, run:

```
./scripts/check-mac-ios-parity.sh --strict
```

If the matching macOS file is lane-claimed by another agent, do not edit through
the claim. Log the exact blocked files and carry the item as tracked debt until
the lane releases.

Shared code and metadata now belong in:

`/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/PrismetShared`

Both XcodeGen projects depend on the `PrismetShared` Swift package. Put new
cross-platform feature contracts there first when they are not UI-framework
specific. The first shared contract is `PrismetFeatureManifest`, which maps
one canonical feature identity to the current iOS/macOS legacy IDs.

### Fast path mapping

| iOS path | macOS parity check |
| --- | --- |
| `Sources/Core/Games/*.swift` | `Sources/Model/<same file>` |
| `Sources/Features/Games/*View.swift` | `Sources/Views/<same file>` |
| `Sources/Core/Design/*` | `Sources/Model/PrismetDesign.swift` |
| `Sources/Features/Home/*` | `Sources/App/ContentView.swift`, `Sources/Views/HomeLensView.swift`, `Sources/Model/FacetRegistry.swift` |
| `Sources/Backend/*`, `Sources/Core/Games/*Leaderboard*` | `Sources/Account/*`, `Sources/Model/GameLeaderboard.swift`, `Sources/Views/LeaderboardViews.swift` |
| `Sources/Core/Ads/*` | Usually iOS-only; record "not applicable to macOS" unless macOS gains ads/paywall UI. |
| `Resources/*`, `project.yml` | `Sources/Resources/*`, `project.yml`, and version/build settings |

## Current Matrix

| Game | Phone parity now | Remaining mac feature gaps |
| --- | --- | --- |
| 2048 | Core play, save/restore, account-scoped sync; desktop-style shuffle power-up controls, saved shuffle settings, and visual shuffle effects. | Optional: port desktop undo stack / slide animation planner if exact Mac session controls are needed. |
| Snake | Core play, save/restore, account-scoped sync. | Port desktop sprite/tile presentation assets from `SnakeTilePresentation` and snake image assets. |
| Minesweeper | Core play, styles, save/restore, account-scoped sync. | Audit desktop board layout and interaction-mode polish against phone gestures. |
| Sudoku | Core play, save/restore, account-scoped sync. | Add richer undo/state controls if we want exact desktop session controls. |
| Rubik's Cube | Phone has touch controls plus SwiftUI 3D corner preview. | Desktop has deeper SceneKit-style 3D camera/render feel; audit whether phone needs a full SceneKit/RealityKit pass. |
| Chess | Core rules, AI/ELO, save/restore, account-scoped sync; color-specific glyphs fixed. | Optional: port desktop asset-piece rendering or 3D models if the phone board still looks weak. |
| Wordle | NYT daily fetch, practice mode, local Wordle leaderboard, global leaderboard submit, save/restore. | Keep monitoring NYT endpoint stability and offline fallback behavior. |
| Oracle | Decree model and bundled `Resources/decrees.json` now included through `sources`; unit coverage confirms bundled chronicle loads with non-empty decrees. | Verify on a clean device install that the consult path is non-empty in the live UI. |
| Lights Out | Core play, save/restore, account-scoped sync. | Add desktop-like undo/state controls if needed. |
| Sliding Puzzle | Core play, save/restore, account-scoped sync, leaderboard submit. | Confirm desktop "Sliding-15" naming/result flow parity. |
| Nonogram | Core play, save/restore, account-scoped sync. | Desktop audit suggests optional mark modes if click-cycle becomes clumsy on phone. |
| Reversi | Core play, save/restore, account-scoped sync. | Add desktop-style result slip/local score entry if desired. |
| Checkers | Core play, save/restore, account-scoped sync; Human vs AI toggle, undo, result slip, saved result state, and human-vs-AI win leaderboard submit. | Optional: richer local score history if we want exact desktop score-sheet behavior. |
| Connect Four | Core play, save/restore, account-scoped sync. | Add desktop-style result slip/local score entry if desired. |
| Gomoku | Core play, bot/local/online friend, save/restore, account-scoped sync. | Mirrored to macOS with goban view, save/reload, bot toggle, AI ELO, model tests. Remaining: online friend room flow is still phone-first/tracked. |
| Sea Battle | Core play, Solo AI/Online Friend, standard 5-ship deployment phase, difficulty picker, save/restore. | Mirrored to macOS with five-ship deployment, drag/move fleet setup, AI difficulty, save/reload, model tests. Remaining: online friend room flow is still phone-first/tracked. |
| Solitaire | Core play, save/restore, account-scoped sync. | Audit desktop `SolitaireSession` behavior for scoring/undo differences. |
| Spider | Core one-suit Spider Solitaire, save/restore. | Mirrored to macOS with one-suit Spider, save/reload, model tests. Remaining: optional skin picker polish. |
| Crazy 8 | Core local/online friend card play, save/restore. | Mirrored to macOS with local/friend table mode, AI opponent/ELO, save/reload, model tests. Remaining: online friend room flow is still phone-first/tracked. |
| Brick Bench | BrickLink import/export, layered top-down builder, save/restore, account-scoped sync; phone-native 3D preview added. | Desktop still has SceneKit build view, gizmo/keyboard controls, richer 3D placement and undo/redo. |
| Catan (Settlers) | New iOS Board game — full playable engine (19-hex board, snake-draft setup, dice production, robber, roads/settlements/cities, dev cards Knight+VP, Longest Road, Largest Army, win at 10 VP), 3 players (you + 2 bots), bank 4:1 trading, Canvas board in house style, save/restore + account-scoped sync. | **Tracked debt — macOS not yet mirrored.** Owner: Agent-Design/Claude. Blocker: authored in a headless Linux cloud session (no Xcode to build/verify). Next: after iOS build + `CatanGameTests` pass on a Mac, mirror `CatanBoard`/`CatanGame`/`CatanAI` into `macos/Sources/Model/` and a `CatanView` into `macos/Sources/Views/`, then register in `FacetRegistry` + `ContentView`. Carry-over simplifications: dev deck = Knight + Victory Point only; trading = bank 4:1 (no ports / player trades); discard-on-7 and robber steal are automatic. |

## Next Order

1. Clean-device smoke: install the current v14 Debug build on iPhone + iPad, verify Oracle non-empty and online friend room flow.
2. macOS parity polish: add the remaining per-game skin pickers and close the tracked online-friend gaps where practical.
3. Snake: port the desktop sprite/tile presentation assets for a fast visible polish win.
4. Board games: repeat the Checkers result-slip/undo pattern for Reversi and Connect Four where ranking is fair.
3. Brick Bench: defer full SceneKit/gizmo unless launch review says the Canvas 3D preview is not enough.
4. Oracle: run a clean install/device verification after the resource bundling fix.

## Parity Log

- `PRISM: Codex/Legion, 2026-07-15 (Fair Play Casino 11-table expansion)` —
  **MIRRORED in the same pass:** iPhone, iPad, and macOS now share one typed
  11-table catalog and deterministic fairness engines, with native session,
  chance-game, Five-Card Draw, rules, reset, accessibility, and adaptive-layout
  surfaces on each platform. The iOS presentation, safety, and session tests are
  matched by `macos/Tests/CasinoMacPresentationTests.swift`,
  `CasinoSafetyContractTests.swift`, and `PracticeCasinoSessionTests.swift`.
  Owner: Codex/Legion. Blocker: none. Next action: keep new Casino tables shared
  first and require simultaneous native presentation/tests before deploy.

- `PRISM: Agent-Ads/Codex, 2026-07-02` — Added mandatory iOS->macOS parity gate,
  deploy-script enforcement, and path mapping. This is a process change only; no
  gameplay source changed. macOS counterpart docs updated so both agent lanes see
  the rule.
- `PRISM: Agent-Ads/Codex, 2026-07-02 (shared package foundation)` — Added
  `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/PrismetShared`,
  a SwiftPM package imported by both apps. First shared layer is
  `PrismetFeatureManifest`: canonical IDs, existing iOS/macOS ID aliases,
  categories, leaderboard policy, and launch-review visibility. Use this package
  as the landing zone for future non-UI shared logic before copying code into
  either app target.
- `PRISM: Agent-Ads/Codex, 2026-07-03 (iPad universal packaging)` — Changed the
  iOS app target from iPhone-only to universal (`TARGETED_DEVICE_FAMILY = 1,2`)
  so physical iPads launch full-screen instead of iPhone compatibility mode.
  macOS parity: not applicable; this is iOS packaging metadata only.
- `PRISM: Agent-Ads/Codex, 2026-07-03 (Wordgame v8 broker restore)` — Re-enabled
  the iOS Wordgame Home card in the Daily group and turned the default Daily path
  back to the public Supabase broker URL. Shared manifest visibility was updated
  to match. macOS parity: already visible and broker-backed in the macOS app.
- `PRISM: Codex, 2026-07-03 (custom iOS game tile art)` — Wired the iOS Home grid
  and DEBUG glyph screenshot harness to the new full-color `tile_<game>` image
  assets. macOS parity: tracked debt; the macOS launcher still uses its existing
  icon treatment and should receive a matching custom-art pass after the iOS
  deploy is stable.
- `PRISM: Codex, 2026-07-03 (Spider, Crazy 8, Sea Battle iOS slice)` — Added
  iOS clean-room models, views, snapshots, Home routes, and online handoff for
  Crazy 8 + Sea Battle. macOS parity: tracked debt; mirror the new model/view/test
  files into the macOS app in a follow-up parity pass.
- `PRISM: Codex, 2026-07-03 (Sea Battle deployment phase)` — Changed iOS Sea
  Battle to begin with standard 5-ship placement for Solo AI and Online Friend,
  with manual/auto deployment and setup snapshots before shots begin. macOS
  parity: tracked debt; the desktop app has not received the new Sea Battle
  model/view/tests yet.
- `PRISM: Agent-Design/Fable, 2026-07-03 (v10 design pass parity decisions)` —
  iOS v10 landed material identities on 2048/Checkers/Chess/Oracle/BrickBench/
  Solitaire/Gomoku, GamePigeon-style skins on Spider/Crazy 8/Sea Battle, a Debt
  Clock live trend banner, a Wordgame letter-status tracker, DARK default paper,
  per-game skin pickers, and Home Workshop/Lenses categories. macOS decisions:
  (1) MIRRORED now: DARK default (`PrismetDesign.swift` fallback → .dark),
  Debt Clock trend banner + LED loading/error + full-width flowing rows (view +
  stats model re-copied per the established pattern), Brick Bench green-baseplate
  stud fix (same buried-child-node root cause existed in the macOS
  LegoBuilder3DView — studs were parented to slabNode with scene-space y).
  macOS rebuilt + relaunched green via deploy-mac.sh.
  (2) NOT APPLICABLE: Wordgame letter tracker — macOS WordPuzzleView already has
  an interactive QWERTY with per-letter best-score coloring (physical-keyboard
  app); the iOS feature exists because the native iOS keyboard can't show status.
  (3) TRACKED DEBT (owner: Agent-Design; next action: run the prepared mirror
  plans in the macOS repo — per-surface plans already written): the six-game
  material-identity mirror (walnut 2048 tray, club Checkers board, Chess plaques/
  swatches, Oracle ledger card, Solitaire baize + real card faces, BrickBench
  workshop chrome), Gomoku goban look, per-game skin pickers, Home category
  regroup (macOS FacetRegistry), and the Spider/Crazy 8/Sea Battle games
  themselves (models not yet ported — pre-existing Codex debt row above).

- 2026-07-04 (Agent-Design/Fable) — **The Moguls board** (Debt Clock lens top-bar switcher:
  THE DEBT / THE MOGULS; billionaire/CEO ledger with Council-of-Bots satire verdicts +
  boss-vs-median-worker pay ratios; new files `Sources/Core/Stats/MogulModel.swift`,
  `Sources/Backend/MogulSource.swift`, `Sources/Features/Stats/MogulsView.swift`,
  `Resources/moguls.json`; gist-served like decrees). **macOS decision: MIRRORED same-day (2026-07-04)** — model/source/view ported to macos/Sources/{Model,Views}, bundled moguls.json added, switcher wired into the macOS DebtClockStatsView; macOS build green (CODE_SIGNING_ALLOWED=NO path).

- 2026-07-05 (Agent-Design/Fable, v13 consolidation pass) — **The v10/v11 tracked-debt rows above are CLOSED.**
  **MIRRORED:** the four missing games are now macOS-native facets — Gomoku (goban), Sea Battle
  (5-ship deployment, naval skin), Crazy 8, Spider (one-suit) — each model+session+view+tests,
  registered in FacetRegistry/ContentView with per-window save/reload; walnut 2048 tray; club
  Checkers board (incl. board-style skins, captured-piece trays); Solitaire baize + real card
  faces + rosette backs; Brick Bench workshop chrome (plastic buttons, stud tiles, tool shelf);
  Chess plaques (engraved player plaques framing the flat board); Oracle ledger card (wax seal,
  ornamental rule, verdict stamps); full-color `tile_<game>` Home art (22 imagesets mirrored to
  the macOS catalog, launcher renders art with glyph fallback); Home category regroup
  (FacetCategory now Daily/Puzzles/Board/Cards/Workshop/Lenses, matching iOS).
  **TRACKED DEBT (owner: Codex, backend lane):** online-friend multiplayer wiring for
  Gomoku/Sea Battle/Crazy 8 on macOS (solo AI + local play shipped this pass).
  **TRACKED DEBT (owner: Agent-Design, follow-up):** per-game skin pickers on macOS (2048
  walnut/slate/cream, chess in-world swatch chips); Brick Bench per-brick EditBar (needs
  LegoBuilderModel duplicate/delete APIs); felt-styled Checkers result sheet (shared
  ResultSlipView reskin); macOS Checkers AI opponent (model gap — pass-and-play only today).
  All builds green on main (CODE_SIGNING_ALLOWED=NO path).
- `PRISM: Agent-Design/Claude, 2026-07-12 (Catan / Settlers — new iOS Board game)` —
  Added a full playable Catan to iOS (Board category). New files: `Sources/Core/Games/
  CatanBoard.swift`, `CatanGame.swift`, `CatanAI.swift`; `Sources/Features/Games/CatanView.swift`;
  `Tests/CatanGameTests.swift`. Registry edits: `.catan` in `CanonicalGameID`, solo-only
  `GameModeCatalog` entry, `CatanSnapshot` + sample in `GameSnapshots.swift`, Home card + route.
  **TRACKED DEBT (owner: Agent-Design/Claude):** macOS mirror not yet done — blocker is that
  this was authored in a headless Linux cloud session with no Xcode. Next action: once the iOS
  build + `CatanGameTests` are green on a Mac, port `CatanBoard`/`CatanGame`/`CatanAI` to
  `macos/Sources/Model/` and a `CatanView` to `macos/Sources/Views/`, then register in
  `FacetRegistry` + `ContentView`. NOTE: iOS build/tests were NOT run in this session.
