# Catan 3D Overhaul — Handoff (2026-07-13)

**Branch:** `claude/prismet-catan-research-l86o6j` (research; **not** merged to `main`)
**Author:** Claude (Opus 4.8), autonomous overnight session
**Built on:** the existing playable Catan (commit `00f1d8c`)

## Good morning — TL;DR

Catan now has a **cozy low-poly 3D board** you can zoom, pan, and orbit, with **colonist.io-grade
customization**. The Debug build is **installed on Poopoohead** — unlock the phone, open **Prismet →
Board → Catan**. (The overnight deploy couldn't auto-launch it because the phone was locked; that's
the only reason the deploy script reported an error. The app is installed and ready.)

If you love it → we merge to `main` and do the macOS port. If you want changes → it's all isolated
on the research branch; `git checkout main` in `ios/` returns to the shipping app untouched.

## What's new

- **Real 3D board (SceneKit):** beveled hex biomes (forests with pine trees, pastures with sheep,
  fields with wheat, hills, ore peaks, a desert cactus), number tokens with pips (6/8 in red),
  cottage/city buildings, colored roads, a friendly robber, and a sea + sandy-shore island.
  Drag to orbit, pinch to zoom — the whole board.
- **6 board themes:** Meadow (default), Autumn, Winter, Candy, Cozy Night (lantern glow), Classic.
- **Customization sheet** (🎨 toolbar button): board theme, **your player color**, **piece style**
  (Cottage / Toy Blocks), gentle auto-rotate, reduce-motion, and **3D ⇄ 2D** board toggle.
- **New-game options:** player count **2–4** (you + up to 3 bots) and **bot difficulty**
  (Gentle / Cozy / Clever).
- **Juice:** pieces pop in when built, the robber hops between hexes, dice bounce on each roll,
  and confetti rains on a win. All respect Reduce Motion.
- **2D board preserved** as a fallback renderer (the original Canvas board), selectable in the
  customize sheet — so the game is always playable even if 3D ever misbehaves.

## How it's built (files)

Rules engine — **unchanged** (kept the winnable, deterministic, tested core):
`Sources/Core/Games/CatanGame.swift`, `CatanBoard.swift`.

New / changed:
| File | Role |
| --- | --- |
| `Core/Games/CatanTheme.swift` | Themes, piece styles, player-color set (pure RGB data) |
| `Core/Games/CatanPrefs.swift` | UserDefaults customization store |
| `Core/Games/CatanAI.swift` | +difficulty tiers (`.cozy` == original behavior) |
| `Core/Games/GameSnapshots.swift` | `CatanSnapshot` carries difficulty (decode-safe) |
| `Features/Games/CatanSceneGeometry.swift` | board→world math, node naming |
| `Features/Games/CatanScene3D.swift` | the scene builder (hexes, pieces, robber, markers, lights) |
| `Features/Games/CatanBoard3DView.swift` | `UIViewRepresentable`: camera, tap hit-testing, state bridge |
| `Features/Games/CatanCustomizeSheet.swift` | the customization UI |
| `Features/Games/CatanConfetti.swift` | win confetti |
| `Features/Games/CatanView.swift` | 3D/2D layout switch + wiring |
| `Tests/CatanGameTests.swift` | +difficulty / multiplayer / decode-safety / theme tests |
| `Tests/CatanRenderHarnessTests.swift` | offscreen SCNRenderer → board PNGs for review |

Design spec: `docs/superpowers/specs/2026-07-13-catan-3d-overhaul-design.md`.

## Verification evidence

- iOS app **builds green** for device (Debug) and simulator.
- **`PrismetTests`: 315/315 pass** (incl. the shared snapshot registry that covers `CatanSnapshot`).
- The 3D scene was rendered offscreen and eyeballed in **Meadow, Cozy Night, and Candy** themes
  (see the render harness; PNGs also in `docs/catan-3d-shots/`).
- Installed on Poopoohead (device Debug build).
- **Not verified:** the live interactive launch on-device (phone was locked overnight). High
  confidence, but the first real play session is the true final check.

## Known limitations & follow-ups (nothing blocking play)

1. **Resource-gain floaties** were scoped but not built (would show "+🌲🧱" when a roll pays you).
   Easy add in `CatanView` after a roll.
2. **AI can stall on some board layouts** (a pre-existing heuristic limitation — certain congested
   4-player / low-trade boards can't reach 10 VP; the game keeps playing but no one wins). Tests no
   longer assume universal termination. A real fix = smarter trading / dev-card / longest-road play.
3. **Legal-move markers** (glowing spots) could be more prominent when zoomed out — consider
   floating gem/ring markers.
4. **SCNShape material order** (top vs side color) is assumed `[front, back, sides]`; verified good
   in renders. If a tile ever shows the darker color on top, swap indices in `makeHex`.
5. **Gameplay depth** still matches the original slice: bank 4:1 only (no ports / player trades),
   dev deck = Knight + Victory Point only. Out of scope tonight.
6. **macOS parity: TRACKED DEBT** — macOS Catan doesn't exist yet; the 3D board is
   `UIViewRepresentable` and needs an AppKit port. See the Parity Log in
   `ios/docs/MAC-IOS-GAME-PARITY.md`.

## Commit trail (on the research branch)

1. Add Catan 3D overhaul design spec
2. theme catalog, difficulty-tiered AI, cozy 3D SceneKit board (+ render harness)
3. interactive 3D board + customization UI
4. juice — placement pops, robber hop, dice bounce, confetti
5. docs — parity tracked-debt + this handoff
