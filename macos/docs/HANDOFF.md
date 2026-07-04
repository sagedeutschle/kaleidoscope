# Kaleidoscope Handoff

Date: 2026-06-27

## Current App

Workspace: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap`

This is a SwiftUI macOS app generated with XcodeGen. It was renamed from
`ChessHotSwap` to **Kaleidoscope** and now launches to a Home lens grid of
facets.

Cross-platform rule: the iOS repo now has a mandatory iOS->macOS parity gate.
When phone features change, mirror the matching behavior here unless the iOS
agent records it as not applicable or tracked parity debt in
`/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/docs/MAC-IOS-GAME-PARITY.md`.

Ready facets:

- Chess: existing 2D/3D chess board with hot-swap view mode.
- Brick Bench: clean-room LEGO-style 3D builder with BrickLink-compatible wanted-list XML import/export.
- Wordle: five-letter daily word puzzle with NYT Daily fetch, random puzzles, and local daily fallback.
- Oracle: the Wizard King's Decree.
- Rubik's Cube: playable cube facet with model tests.
- 2048: playable SwiftUI 2048 board with keyboard, buttons, drag, score, and deterministic model tests.
- Lights Out: playable 5 x 5 Lights Out board with deterministic model tests.
- Minesweeper: playable first-click-safe minefield with flags and deterministic model tests.
- Snake: playable grid snake with arrow/WASD controls, pause, apples, score, and deterministic model tests.
- Sliding-15: playable numbered sliding puzzle with deterministic shuffle tests.

Coming-soon facets:

- Sudoku, Nonogram, Reversi.

## Recent Completed Work

### Stabilization

- Renamed the generated project/scheme/test target to `Kaleidoscope`.
- Added a one-time Application Support migration from `ChessHotSwap` to `Kaleidoscope`.
- Added tests for chess move generation, Brick Bench model/export, daily word provider, and word puzzle scoring.
- Confirmed chess toolbar controls only show in the Chess workspace.
- Added `FacetRegistryTests`, `Game2048Tests`, `LightsOutTests`, `RubiksCubeTests`,
  `MinesweeperGameTests`, `SnakeGameTests`, `SlidingPuzzleTests`,
  `SudokuGameTests`, `NonogramGameTests`, and `ReversiGameTests`.

### Arcade Facets / Agent-B Update

Files:

- `Sources/Model/Game2048.swift`
- `Sources/Views/Game2048View.swift`
- `Sources/Model/Game2048VisualShuffle.swift`
- `Sources/Model/Game2048ShufflePowerUps.swift`
- `Sources/Model/Game2048BoardLayout.swift`
- `Sources/Model/SudokuGame.swift`
- `Sources/Views/SudokuView.swift`
- `Sources/Model/NonogramGame.swift`
- `Sources/Views/NonogramView.swift`
- `Sources/Model/ReversiGame.swift`
- `Sources/Views/ReversiView.swift`
- `Sources/Views/MinesweeperView.swift`
- `Sources/Model/MinesweeperBoardLayout.swift`
- `Sources/Views/SnakeView.swift`
- `Sources/Model/SnakeTilePresentation.swift`
- `Sources/Resources/Assets.xcassets/snake_*.imageset`
- `docs/ASSET_ATTRIBUTIONS.md`

Implemented:

- 2048 shuffle is a real tile-shuffle power-up. It rearranges current tile
  positions while preserving score and the exact tile-value multiset.
- 2048 shuffle uses are configurable per game from 0 through 5 and reset on New Game.
- 2048 board size is real tile count: 3x3 through 6x6, with 4x4 as the default.
- 2048 tiles now slide from their source cells toward the move direction before
  the merged grid and spawned tile commit.
- 2048 board/card geometry is centralized in `Game2048BoardLayout` so different
  board sizes stay centered.
- Sudoku, Nonogram, and Reversi are now playable ready facets instead of
  coming-soon sidebar entries.
- Minesweeper is more tightly packed, has explicit Choose / Flag controls, and
  supports zoom-in / zoom-out buttons that scale the board layout.
- Snake renders from downloaded CC0 sprite assets instead of generated or
  hand-drawn SwiftUI snake graphics.

Asset provenance:

- Snake sprites: `Snake Game Assets` by Clear_code on OpenGameArt.
- License: CC0 1.0 Universal.
- Attribution file: `docs/ASSET_ATTRIBUTIONS.md`.

Coordination:

- Agent-A / Claude established `docs/AGENT-COORDINATION.md` and the `PRISM:`
  protocol for cross-agent notes.
- Agent-B ACKed the protocol there on 2026-06-27 and left arcade/Wave-2 as the
  default Agent-B lane.

### Brick Bench

Files:

- `Sources/Model/LegoBuilderModel.swift`
- `Sources/Views/LegoBuilderView.swift`
- `Tests/LegoBuilderModelTests.swift`

Implemented:

- Brick sizes now include bricks and plates:
  - 1 x 1 brick, 1 x 2 brick, 1 x 4 brick, 2 x 2 brick, 2 x 4 brick, 2 x 6 brick.
  - 1 x 1 plate, 1 x 2 plate, 1 x 4 plate, 2 x 2 plate, 2 x 4 plate, 2 x 6 plate.
- BrickLink part numbers are mapped in `LegoBrickSize.partNumber`.
- BrickLink colors expanded:
  - white, tan, yellow, orange, red, green, blue, black, dark bluish gray, light bluish gray, reddish brown.
- Wanted-list XML export exists in `BrickLinkWantedListExporter`.
- Wanted-list XML import exists in `BrickLinkWantedListImporter`.
- UI supports:
  - adding selected brick/color/layer,
  - parts summary,
  - export XML,
  - paste/import wanted-list XML.

Known limitation:

- No live BrickLink API call is wired yet.
- No secrets or OAuth keys should be committed.
- Brick Bench has a 3D SceneKit canvas with selectable bricks, move arrows, keyboard movement, layers, and Q/R rotation.
- Brick Bench defaults: E places the selected brick, Esc undoes, Tab redoes, and the gear opens shortcut/gizmo customization.

### Wordle

Files:

- `Sources/Model/WordPuzzleModel.swift`
- `Sources/Model/DailyWordProvider.swift`
- `Sources/Views/WordPuzzleView.swift`
- `Tests/WordPuzzleModelTests.swift`
- `Tests/DailyWordProviderTests.swift`
- `Tests/FacetRegistryTests.swift`

Implemented:

- `DailyWordProvider` provides stable local daily words by date.
- Optional authorized remote JSON loading is supported.
- NYT Daily fetch uses `https://www.nytimes.com/svc/wordle/v2/<yyyy-MM-dd>.json` and falls back to local daily if the fetch fails.
- Remote payload shape:

```json
{
  "answer": "crane",
  "date": "2026-06-26",
  "sourceName": "Authorized Daily"
}
```

- Wordle shows source name and date.
- Wordle uses a familiar white Wordle-style board with square tiles, green/yellow/gray feedback, and an on-screen keyboard.
- Wordle keeps Random and Local Daily controls alongside the NYT Daily button.

Known limitation:

- Do not add scraping of NYT pages or embed unofficial NYT answer data. Keep the endpoint path contained in `DailyWordProvider`.

## Verification Evidence

Last successful commands:

```bash
xcodegen generate
```

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

Last observed result:

- 180 tests executed.
- 0 failures.
- `** TEST SUCCEEDED **`

Runtime smoke checks performed:

- Brick Bench loaded in the app.
- Add Brick updated canvas and parts summary.
- Export XML produced a BrickLink wanted-list XML payload.
- Wordle loaded local daily source/date.
- Wordle accepted a provider-backed guess and updated board/status.
- Kaleidoscope Home grid compiled with ready 2048 and Lights Out facets.
- Minesweeper, Snake, and Sliding-15 are routed as ready facets.

## Git State

The top-level git root is `/Users/gtrktscrb`.

Observed status:

```bash
?? Desktop/GtrktscrB/apps/chess-hotswap/
```

The app directory appears untracked from the top-level repository. No commit or staging was performed.

## Cross-Project: Yggdrasil / Ygrasil Work

Project path: `/Users/gtrktscrb/Desktop/GtrktscrB/gaming/fromsoft-mods/yggdrasil`

Claude memory calls this `project-yggdrasil`. User may spell it "Ygrasil"; project files use `yggdrasil`.

### Read Order

Future agents should read these first, in this order:

1. `/Users/gtrktscrb/Desktop/GtrktscrB/gaming/fromsoft-mods/yggdrasil/STATUS.md`
2. `/Users/gtrktscrb/Desktop/GtrktscrB/gaming/fromsoft-mods/yggdrasil/2026-06-11-yggdrasil-design.md`
3. `/Users/gtrktscrb/Desktop/GtrktscrB/gaming/fromsoft-mods/yggdrasil/PINNED.md`
4. `/Users/gtrktscrb/Desktop/GtrktscrB/gaming/fromsoft-mods/yggdrasil/PROVENANCE.md`
5. `/Users/gtrktscrb/Desktop/GtrktscrB/gaming/fromsoft-mods/yggdrasil/docs/formats-inventory.md`

### Project Summary

Yggdrasil is the FromSoft multiverse mod project:

- Elden Ring is the host engine.
- Dark Souls 3 is the first donor branch.
- Goal is a world-tree hub connecting full donor-game branches.
- Seamless Co-op is required from day one.
- Public posture is zero redistributed FromSoft assets: ship converter/patcher code only, users point it at their own legitimate installs.

### Machine Roles

- `archbox`: current build box and primary test/host. Use LAN path if tailnet fails.
- `balrog`: Bazzite co-op client test seat.
- `topaz`: Windows fallback only, not current build box.
- MBP: coordination/workspace machine.

Known access notes from `STATUS.md`:

- archbox was reachable via LAN as `archbox.lan` / `192.168.0.114`; Tailscale path was unreliable.
- balrog access is `bazzite@balrog.local`; old Tailscale IP is dead.
- topaz has Smart App Control issues with unsigned tools; local RDP/double-click blessing is required if it becomes relevant.

### Current Milestone State

Phase: M0/M1 overlap.

Current tracker from `STATUS.md`:

- M0 toolchain bring-up: in progress.
- M1 High Wall walkable in ER: layout converter done; FLVER models converter done; collision/nav/in-game walk remain.
- M2 hub v0 + travel: not started.
- M3 High Wall populated: not started.
- M4 Vordt + audio research spike: not started.
- M5 co-op gate: not started and requires a second ER-owning Steam account because archbox + balrog share one account.

Recent concrete progress:

- DS3 unpack path was built natively in `pipeline/UnpackDS3`.
- High Wall DS3 MSB layout conversion was implemented in `pipeline/Msb3ToMsbe`.
- High Wall layout output round-tripped as ER MSBE.
- FLVER model conversion was built in `pipeline/Flver3ToFlverE`.
- 605/605 High Wall map-piece models were converted from DS3 FLVER2 `0x20014` to ER FLVER2 `0x2001A`.
- Converted model output landed under archbox-side `~/yggdrasil/build/m50/map/m50_00_00_00/`.
- ER unpacking and Oodle/KRAK packaging were researched/solved enough for native Linux work.
- A crude `m50` proof-of-concept build was assembled with layout, models, and reused collision shells.

### Main Technical Pivot

Collision/nav is the project pivot.

Important status:

- DS3 collision uses old Havok (`hk_2014.1.0-r1`).
- ER collision uses newer Havok/tagfile line.
- Direct automated collision transcode is considered dead from current evidence.
- Public/native ER collision generation is not available.
- Reusing/kitbashing ER collision blocks works structurally, but conforming them to High Wall is manual GUI work unless new R&D succeeds.

This weakens the original "fully automated DS3 -> ER map pipeline" assumption. The next agent should not claim batch-scale map conversion is solved until collision/nav has an evidence-backed path.

### Yggdrasil Next Actions

Recommended next work order:

1. Wake/reach balrog if deployment is needed.
2. Run the staged deploy script from the archbox build output if present: `build/m50/deploy-to-balrog.sh`.
3. Launch the YGGDRASIL tile / ModEngine setup and CE-warp to `m50_00_00_00`.
4. Verify whether High Wall renders and whether the player can stand/walk.
5. If load fails, classify failure using `build/m50/WARP-TEST.md` if present on archbox.
6. Decide collision strategy:
   - accept manual GUI collision/nav kitbash per map,
   - pursue in-engine/proprietary-Havok R&D,
   - or rescope the DS3 branch plan.
7. Keep `STATUS.md` updated before ending any Yggdrasil session.

### Yggdrasil Safety Rules

- Do not put donor game assets in git.
- Do not redistribute FromSoft content.
- Treat `STATUS.md` as the living source of truth.
- Everything pins: game versions, tools, Seamless version, ModEngine version.
- Run evidence-based checks before claiming a milestone is complete.
- Keep chess/Brick Bench work separate from Yggdrasil work unless the user explicitly asks to bridge them.

## Recommended Next Steps

### 1. BrickLink API Credentials

If the user returns with BrickLink API credentials:

- Do not paste secrets into tracked files.
- Prefer a local ignored file or environment variables.
- Add a `BrickLinkCredentials` type that reads:
  - consumer key,
  - consumer secret,
  - token value,
  - token secret.
- Add a `BrickLinkAPIClient` boundary in a new model/service file.
- Keep import/export XML working offline.
- Add tests around request construction without real network calls.

Suggested file:

- `Sources/Model/BrickLinkAPIClient.swift`

Suggested env names:

- `BRICKLINK_CONSUMER_KEY`
- `BRICKLINK_CONSUMER_SECRET`
- `BRICKLINK_TOKEN_VALUE`
- `BRICKLINK_TOKEN_SECRET`

### 2. Sudoku / Nonogram / Reversi

These facets remain coming soon. Keep each future game as a pure model plus a
small SwiftUI view, following the Minesweeper/Snake/Sliding-15 pattern.

### 3. Remote Daily Word Endpoint

If the user provides an authorized daily word endpoint:

- Use the existing `DailyWordProvider.remoteWord(from:)`.
- Validate five-letter lowercase answer.
- Keep local daily fallback on failure.
- Do not store remote answers permanently unless explicitly requested.

## Useful Commands

Regenerate project:

```bash
xcodegen generate
```

Run full tests:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

Launch debug build:

```bash
open /Users/gtrktscrb/Library/Developer/Xcode/DerivedData/Kaleidoscope-djxqvxhoqountjfngczlxnyrxuqu/Build/Products/Debug/Kaleidoscope.app
```

Kill running app:

```bash
pkill -x Kaleidoscope || true
```

## Caution

- Do not revert user changes.
- Use `apply_patch` for manual edits.
- Run `xcodegen generate` after adding/removing source files.
- Run full tests before claiming completion.
- Avoid committing API credentials or secrets.
