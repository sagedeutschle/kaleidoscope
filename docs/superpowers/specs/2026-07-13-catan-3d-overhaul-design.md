# Catan 3D Overhaul — Design Spec

**Date:** 2026-07-13
**Branch:** `claude/prismet-catan-research-l86o6j`
**Author:** Claude (Opus 4.8), autonomous overnight build
**Mandate (Sage, verbatim):** "big push i trust you to make big and good changes … i wanna play catan when i wake up on a 3d zoomable board to rival the customization of colonist.io and then some! … homey and fun and cute."

This spec was written under explicit standing authorization to make big changes autonomously
(Sage asleep, no approval loop). It documents the decisions so the work stays coherent and a
future agent can pick it up cold.

## Goal

Overhaul the **presentation** of the existing, working Catan game into a cozy low-poly 3D
experience with deep customization, without touching the proven rules engine.

Success = on wake, Sage can open Catan on their iPhone (Poopoohead) and play a full game on a
**zoomable/pannable/orbitable 3D board** that looks cute and homey, choose from several **board
themes** + **player color** + **piece style**, and play against **2–3 bots** with selectable
difficulty. Everything must build green and the game must remain fully playable.

## What we keep (do NOT touch the rules)

The rules engine is solid, deterministic, value-typed, and covered by `CatanGameTests` (54
vertices / 72 edges / 19 hexes invariants, winnability, longest-road DFS, etc.). We preserve:

- `CatanGame` (rules/actions/legality), `CatanBoard` (fixed topology + geometry), `CatanAI`
  (heuristic bot). We only **extend** them additively.
- The action API the view already drives: `roll / placeSettlement / placeCity / placeRoad /
  buyDevCard / playKnight / bankTrade / moveRobber / endTurn` and the `legal*Vertices/Edges/Hexes`
  queries. The 3D view calls exactly these — identical to the 2D view.
- Save/resume via `PersistedGameSession<CatanSnapshot>`.

## Architecture

```
Sources/Core/Games/
  CatanGame.swift        (unchanged rules; maybe +tiny additive derived helpers)
  CatanBoard.swift       (unchanged geometry — the single source of board coords)
  CatanAI.swift          (+ difficulty parameter; behavior tiers)
  CatanTheme.swift        NEW  themes/biomes/piece-style catalog (pure data)
  CatanPrefs.swift        NEW  UserDefaults-backed customization store
Sources/Features/Games/
  CatanView.swift        (host: header/scoreboard/controls; board-style switch; sheets)
  CatanScene3D.swift      NEW  pure scene graph builder (board geometry -> SCNNode tree)
  CatanBoard3DView.swift  NEW  UIViewRepresentable: SCNView + camera rig + hit-test + bridge
  CatanCustomizeSheet.swift NEW customization + new-game options UI
  (existing 2D Canvas board stays as the fallback renderer)
```

**Layering / isolation:**
- `CatanScene3D` is a pure builder: `(game, theme, pieceStyle, playerColors) -> nodes`. It knows
  SceneKit but not SwiftUI. Testable-ish, and swappable.
- `CatanBoard3DView` owns the live `SCNView`, camera, gestures, hit-testing, and diff/animate on
  state change. It translates a tapped node → a board index and calls back into SwiftUI with an
  intent (`.vertex(i) / .edge(i) / .hex(i)`), which `CatanView` routes to the model exactly like
  a Canvas tap.
- Board→world mapping: board `(x, y)` (pointy-top, size 1) → world `(x, 0, -y)`, hexes extruded
  +Y. One `boardToWorld` function shared, mirroring the 2D `BoardLayout.screen`.

## Board style: 3D default, 2D fallback (honors "3d option")

`CatanPrefs.boardStyle ∈ {threeD, twoD}`, default `.threeD`. The 2D Canvas renderer is retained
untouched as the fallback so the game is **always playable** even if 3D misbehaves on-device.
SceneKit is already proven in this app (Chess/Rubik's/Lego use `SCNView`), so risk is low, but
the fallback is our safety net for an unattended overnight ship.

## Cute/homey art direction (low-poly storybook)

- **Biomes** (resource→look): brick→**Hills** (clay mounds), lumber→**Forest** (little trees),
  wool→**Pasture** (sheep dots on grass), grain→**Fields** (wheat tufts), ore→**Mountains**
  (grey rocks), desert→**sand + cactus**.
- Chunky **beveled hex prisms** (chamfered edges), soft rounded everything, warm key light +
  soft ambient + gentle shadows. Water ring around the island. Number tokens = rounded discs
  (6/8 in red). Roads = little beveled bars; settlements = **cottages**; cities = bigger
  house/keep with a glow dot. Robber = a friendly dark pawn, not scary.
- Lighting/material tone is per-theme (Meadow warm day … Night cozy lanterns).

## Customization ("rival colonist.io and then some")

- **Themes** (board skins): Meadow (default), Autumn, Winter, Candy (pastel), Night (cozy
  lanterns), Classic. Each = palette for {biome tops/sides, desert, water, rim, token face,
  ambient light color+intensity, background}.
- **Player color**: pick your color from a curated set; bots auto-reassigned to stay distinct.
- **Piece style**: Cottage (default) + Blocky (toy) at minimum.
- **Camera/board**: tilt, auto-rotate idle, zoom presets, reduce-motion (kills idle/ambient
  and shortens transitions).
- **New game**: player count 2–4, bot difficulty.
- All persisted in `CatanPrefs` (UserDefaults); live preview in the sheet.

## Bots: multiple + difficulty

Model already clamps to 2–4 players (you + up to 3 bots: Amber/Jade/Garnet). Add
`CatanBotDifficulty` (e.g., `.gentle / .cozy / .clever`) passed to `CatanAI(difficulty:)`:
tunes greediness, whether it trades toward goals, robber cruelty (avoid targeting the human on
gentle), and dev-card buying. Difficulty is chosen at new-game time and stored in the snapshot
(decode-safe default) so resume is faithful. Bots keep distinct names/colors → reads as "multiple
characters."

## Camera + interaction (the crux)

Start from the app's existing SceneKit pattern (Chess board is the closest analog: tap-to-select
on a board). Plan: SceneKit built-in camera control for orbit/zoom/pan (constrained) + a single
`UITapGestureRecognizer` for placement/robber taps (single-tap doesn't fight the pan/pinch/rotate
camera gestures). Hit-test returns the nearest named node; node names encode
`vertex-<i>/edge-<i>/hex-<i>`. Only currently-legal targets show glowing markers and are
tappable. Exact patterns pulled from the SceneKit-conventions survey (Chess/Rubik's/Lego).

## Juice (fun/cute)

Dice tumble on roll, piece "pop" (scale bounce) on placement, robber hop between hexes,
resource-gain floaties on production, subtle water shimmer + idle sway, win confetti, and the
existing haptics (`sensoryFeedback`). All gated by reduce-motion.

## Save-compat & tests

- `CatanSnapshot` gains `difficulty` with a custom `init(from:)` default (pattern already used by
  `SeaBattleSnapshot`/`CheckersSnapshot`) so pre-existing saves decode. Update the
  `GameSaveSnapshotRegistry` sample.
- TDD for model/AI additions; keep the full suite green. SceneKit view is not unit-tested
  (house convention); a green build + on-device verification is the gate.

## Risks & mitigations (unattended ship)

1. **Broken/unplayable build on wake** → keep 2D fallback; build+test frequently; deploy &
   verify running; never leave branch non-building; commit at milestones.
2. **Scope overrun** → priority order: (1) beautiful playable 3D board, (2) themes+color+style
   customization, (3) juice, (4) extra themes/piece styles. Land each layer building-green.
3. **Camera vs tap conflict** → single-tap only for placement; lean on Chess's proven approach.
4. **Perf on device** → low-poly, few nodes, static board built once; animate only deltas.

## Parity

macOS Catan does not exist yet; this is iOS-only research. Log as **TRACKED DEBT** in
`ios/docs/MAC-IOS-GAME-PARITY.md` (a full macOS Catan + 3D port is a later, large item). Deploy
uses `KALEIDOSCOPE_SKIP_PARITY=1` (local research device install, not a tester/App Store deploy).

## Out of scope tonight

Ports/harbors, player-to-player trading, the 3 progress dev-cards, online multiplayer, macOS
port, App Store submission. (All are existing follow-ups or future work.)
