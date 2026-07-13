# Catan → macOS + Prismet 1.2 App Store Push — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the new Catan game to the macOS app at full 3D parity, deploy the universal iOS build (with the 3D SceneKit board) to an iPad simulator and the Poopoohead iPhone, and stage a Prismet-branded v1.2 App Store push (Catan-hero screenshot suite incl. the missing iPad set + rewritten description) up to — but not including — the manual upload/submit.

**Architecture:** Three independent lanes off branch `claude/prismet-catan-research-l86o6j` in the Kaleidoscope monorepo (`~/Desktop/Kaleidoscope`). Lane A ports Catan into the separate macOS target (`macos/`) following the repo's established `NSViewRepresentable`-over-`SCNView` precedent (Rubik's/Lego/Chess). Lane B is pure build+deploy of the existing universal iOS build. Lane C edits the DEBUG screenshot harness, the Python framer, the version, and the listing kit, then captures + frames a new suite. Lanes A and C both feed the eventual release; Lane B is standalone.

**Tech Stack:** Swift / SwiftUI / SceneKit; XcodeGen (`project.yml` is source of truth, `.xcodeproj` is generated); `xcodebuild` + `xcrun devicectl` (device) + `xcrun simctl` (simulator); Python 3 + Pillow (screenshot framer); App Store Connect (manual submit).

---

## Locked decisions (from brainstorming 2026-07-13)

1. **macOS Catan = full 3D parity** — port the SceneKit board to `NSViewRepresentable`, not just the 2D fallback. Fall back to 2D-only **only if** the 3D port genuinely fights the toolchain.
2. **Screenshots = Catan hero + iPad set + refresh** — add the Catan 3D board as a headline shot, generate the currently-missing iPad 13″ set, reframe the iPhone set. Branded template.
3. **Brand = Prismet** — 1.2 description and framed screenshots say "Prismet". (Flipping the actual ASC public store name from "Kaleidescope" → "Prismet" remains a manual ASC step at submit time.)

## Cross-cutting rules (apply to every task)

- **PRISM coordination (MANDATORY):** Another Claude agent is actively pushing to `origin/claude/prismet-catan-research-l86o6j` (2 commits today). Before editing any file, re-read `docs/AGENT-COORDINATION.md`'s tail, confirm no live CLAIM overlaps your files, append a dated CLAIM naming your exact files, and flip to RELEASE with build/test status when done. Re-read files immediately before editing — they change underneath you.
- **Prepare, do NOT submit:** Lane C stages materials only. Do not archive-and-upload, do not PATCH ASC metadata, do not submit for review. Stop at "ready for Sage's manual submit" and hand back.
- **Verification is forensic (MANDATORY):** No "should build" claims. Every build task ends with a real `xcodebuild` run that exits 0 and a launch/screenshot that is actually observed. Inspect rendered screenshots with your own eyes (Read the PNG) before claiming a screen looks right.
- **iCloud-sync hazard:** The Desktop is iCloud-synced; under disk pressure `xcodebuild`/`cat` **hang** (not fail) on dataless placeholders. If a tool stalls, check `ls -lO <file>` for `dataless` and `brctl download <path>` before retrying. Build dirs already live in `~/Library/Caches/*-build` (outside iCloud) by design — keep them there.
- **Xcode/codesign conventions:** Build with `-derivedDataPath ~/Library/Caches/<name>` (never into the iCloud project dir), regenerate with `xcodegen generate`, archive Release with `SWIFT_COMPILATION_MODE=incremental`.
- **Delegation option:** Per operator preference, iOS/macOS build+deploy and mechanical capture/framing may be delegated to the Codex CLI (`/Applications/Codex.app/Contents/Resources/codex exec --full-auto "…"`). The macOS 3D-view port is design-sensitive → keep on a full-weight agent; Claude reviews + commits.
- **No push, no submit without Sage's explicit go.** Commit locally only.

## Current-state facts (verified during recon 2026-07-13)

- **macOS target exists:** `macos/project.yml` (app `Prismet`, `platform: macOS`, deploymentTarget 14.0, bundle `com.gtrktscrb.kaleidoscope`), scheme `Prismet`, deploy script `macos/scripts/deploy-mac.sh` (xcodegen → `xcodebuild -scheme Prismet -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` → installs/launches `~/Applications/Prismet.app`). Depends on SwiftPM package `shared/PrismetShared` + Supabase.
- **Registries are SEPARATE:** iOS uses `GameCard.all` (`ios/Sources/Features/Home/HomeView.swift:22`) + `CanonicalGameID` (`ios/Sources/Core/Games/GamePlayMode.swift:106`, has `.catan`) + `soloOrLocalDestination` (`HomeView.swift:220`, `case .catan: CatanView(...)` at `:242`). macOS uses `FacetRegistry.all` (`macos/Sources/Model/FacetRegistry.swift:35`, String ids, ends at `spider` ~`:162`, **no catan**) + a `switch selection` in `macos/Sources/App/ContentView.swift:199-221` (**no `case "catan"`**). Only shared code is metadata: `shared/PrismetShared/Sources/PrismetShared/PrismetFeatureManifest.swift`.
- **Catan source (all under `ios/`, iOS target only):**
  - Pure Foundation (portable verbatim): `ios/Sources/Core/Games/CatanBoard.swift` (197 L), `CatanGame.swift` (557 L), `CatanAI.swift` (231 L).
  - SceneKit-only (portable as-is): `ios/Sources/Features/Games/CatanSceneGeometry.swift`.
  - iOS-only, needs port: `CatanView.swift` (716 L, SwiftUI + ~5 chrome touchpoints), `CatanBoard3DView.swift` (`UIViewRepresentable`+`SCNView`+`TappableCatanSCNView`), `CatanScene3D.swift` (`UIColor`×5, `UIImage` token renderer), `CatanTheme.swift` (`uiColor: UIColor` bridge; `color: Color` is cross-platform), `CatanPrefs.swift` (UserDefaults wrapper, portable).
  - Persistence gap: `PersistedGameSession`/`CatanSnapshot` have **0** occurrences on macOS; macOS uses per-game `…Session` + `GamePersistence`/`GameSessionState`.
- **macOS SceneKit precedent (the port template):** `macos/Sources/Views/RubiksCubeView.swift:348` `RubiksSceneView: NSViewRepresentable` (`makeNSView`/`updateNSView` :370/:409 + a `ClickableSCNView` mouse-hit subclass); also `macos/Sources/Views/Board3DView.swift:53` (chess, `SCNVector3`/mouse drag) and `macos/Sources/Views/LegoBuilder3DView.swift:104`.
- **iOS CatanView chrome touchpoints to swap (from `CatanView.swift`):** (1) `UIAccessibility.isReduceMotionEnabled` (:40) → `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`; (2) `.navigationBarTitleDisplayMode(.inline)` (:55,:502) → remove; (3) `.toolbarBackground(…, for: .navigationBar)` (:56) → `.windowToolbar`/remove; (4) `ToolbarItem(placement: .topBarTrailing)` (:58,:62,:503) → `.automatic`/`.primaryAction`; (5) `.sensoryFeedback(.impact(weight:.light), …)` (:67) → drop (keep `.success` on :68 if supported, else drop). Board drawing (2D `Canvas` `:247-341`) needs no change.
- **Version state:** `ios/project.yml:84-85` → `CURRENT_PROJECT_VERSION "14"`, `MARKETING_VERSION "1.2"`. `Info.plist` uses `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)` and is regenerated by xcodegen (edit `project.yml`, not the plist). History: v1.0/build 12 LIVE; **v1.1/build 13 WAITING_FOR_REVIEW**; v1.2/build 14 staged (never uploaded, old What's New).
- **Brand state:** in-code `Prismet` everywhere (`project.yml:1,49,79`; `Info.plist:8`); bundle id `com.spocksclub.kaleidoscope`; **public ASC name still "Kaleidescope"** (id `6785993194`). Description + framer `BRAND` still say "Kaleidescope".
- **Screenshot infra:** DEBUG harness `ios/Sources/App/ShotHarness.swift` gated by env `PRISMET_SHOT`/`KALEIDO_SHOT` via `ios/Sources/App/RootView.swift:3-16,25-35`. Supported keys (switch `:34-64`): `home, chess3d, chess2d, 2048, wordle, minesweeper, minesweeper30, solitaire, sudoku, rubiks, brickbench, snake, nonogram, reversi, checkers, gomoku, spider, crazyeight, seabattle, oracle, debtclock, moguls, steamrewind, moguldetail, settings, glyphs` — **no `catan`**. Framer `ios/scripts/generate-appstore-screenshots.py`: `CANVAS=(1320,2868)` (6.9″ iPhone only), `BRAND="KALEIDESCOPE"` (:13), 7-shot `SHOTS` list (:25-75). Existing sets: `ios/docs/appstore-screenshots-v14/` (7 raw) + `/final/` (7 framed), all 1320×2868, **iPhone-only**. Listing copy: `ios/docs/APP-STORE-LISTING.md`. No fastlane; `ios/docs/asc-helper.py` is GET-only; submit is manual.
- **Devices/sims available now:** physical `Poopoohead` (iPhone 15 Plus, paired/available; deploy.sh targets hardware UDID `00008120-001278982192201E`). iPad sims: `iPad Pro 13-inch (M4)` `7EDA7E27-90E7-4368-8B9D-EF65A438E0EC`, plus 11″ M4, mini A17, iPad A16, Air 13/11 M3 — none booted.

---

## File-structure map

**Lane A (macOS Catan):**
- Create `macos/Sources/Model/CatanBoard.swift`, `CatanGame.swift`, `CatanAI.swift` — copies of the iOS Foundation models (verbatim; adjust only the `//` header/module comment if any).
- Create `macos/Sources/Model/CatanSceneGeometry.swift` — copy (SceneKit-only, portable).
- Create `macos/Sources/Model/CatanTheme.swift`, `CatanPrefs.swift` — ported (UIColor→NSColor bridge; UserDefaults wrapper).
- Create `macos/Sources/Views/CatanView.swift` — ported view (chrome swaps + macOS session wiring).
- Create `macos/Sources/Views/CatanBoard3DView.swift` — `NSViewRepresentable` port (template: `RubiksCubeView.swift`'s `RubiksSceneView`).
- Create `macos/Sources/Model/CatanScene3D.swift` — ported (UIColor→NSColor, UIImage token→NSImage).
- Create `macos/Sources/Model/CatanSession.swift` (or fold into CatanView) — macOS-idiom save/restore via `GamePersistence`.
- Modify `macos/Sources/Model/FacetRegistry.swift` (add `catan` descriptor) and `macos/Sources/App/ContentView.swift` (add `case "catan"` + `catanSession` property).
- Test: `macos/Tests/CatanGameTests.swift` (mirror of `ios/Tests/CatanGameTests.swift`) if the macOS scheme runs unit tests; otherwise rely on iOS tests + build/launch.

**Lane B (deploys):** no source files; uses `ios/scripts/deploy.sh` + a simulator build/install invocation.

**Lane C (1.2 push):**
- Modify `ios/Sources/App/ShotHarness.swift` (add `case "catan"`).
- Modify `ios/project.yml` (build bump).
- Modify `ios/scripts/generate-appstore-screenshots.py` (`BRAND`, Catan shot, iPad canvas/set).
- Modify `ios/docs/APP-STORE-LISTING.md` (Prismet brand, Catan-forward copy — full text in Task C5).
- Create `ios/docs/appstore-screenshots-1.2/` (raw) + `/final/` (framed iPhone + iPad).

---

## LANE A — Catan on macOS (full 3D parity)

> Execute A1→A7 in order. After A4 you have a *buildable, playable 2D* macOS Catan (safe checkpoint / the fallback). A5–A6 add the 3D board. Keep the 2D `Canvas` renderer wired as the toggle fallback exactly as iOS does.

### Task A1: Port the pure-Swift models to macOS

**Files:**
- Create: `macos/Sources/Model/CatanBoard.swift` (from `ios/Sources/Core/Games/CatanBoard.swift`)
- Create: `macos/Sources/Model/CatanGame.swift` (from `ios/Sources/Core/Games/CatanGame.swift`)
- Create: `macos/Sources/Model/CatanAI.swift` (from `ios/Sources/Core/Games/CatanAI.swift`)
- Create: `macos/Sources/Model/CatanSceneGeometry.swift` (from `ios/Sources/Features/Games/CatanSceneGeometry.swift`)

- [ ] **Step 1: Copy the four files verbatim into `macos/Sources/Model/`.** They are `import Foundation` / `import SceneKit` only — no platform code. Confirm the macOS target's `SeededGenerator`/`nextInt` symbols (used by `CatanGame`/`CatanAI`) exist on macOS; if the RNG type lives under a different name/path on macOS, add the same helper. Do NOT rename types (`CatanBoard`, `CatanGame`, `CatanAI`, `CatanResource`, etc.) — later tasks reference them by these exact names.
- [ ] **Step 2: `cd macos && xcodegen generate --quiet`** so the new `Sources/Model/*.swift` are auto-included (macOS `project.yml` globs `macos/Sources`).
- [ ] **Step 3: Compile-check the models only** by building the macOS scheme (see A7 command) and confirming no errors reference the four new files. Expected: any remaining errors are about the not-yet-created `CatanView`, not the models.
- [ ] **Step 4: Commit** — `git add macos/Sources/Model/Catan*.swift macos/Prismet.xcodeproj && git commit -m "macOS Catan: port Foundation models + scene geometry"`.

### Task A2: Mirror the game-logic tests to macOS (TDD guard for the port)

**Files:**
- Create: `macos/Tests/CatanGameTests.swift` (from `ios/Tests/CatanGameTests.swift`), only if `macos/project.yml` defines a unit-test target.

- [ ] **Step 1:** Check `macos/project.yml` for a test target. If present, copy `ios/Tests/CatanGameTests.swift` (incl. `testHeadlessGameReachesALegitimateWinner`) into `macos/Tests/`, adjust `@testable import` to the macOS module name.
- [ ] **Step 2:** `xcodegen generate --quiet` and run the macOS tests filtered to Catan. Expected: PASS (logic is identical to iOS where it's already 315/315). If macOS has no test target, note that and skip — iOS `CatanGameTests` already covers the shared logic; the macOS gate is build+launch.
- [ ] **Step 3: Commit** if a test file was added.

### Task A3: Port `CatanTheme` + `CatanPrefs`

**Files:**
- Create: `macos/Sources/Model/CatanTheme.swift`
- Create: `macos/Sources/Model/CatanPrefs.swift`

- [ ] **Step 1:** Copy `CatanPrefs.swift` verbatim (UserDefaults wrapper is portable).
- [ ] **Step 2:** Copy `CatanTheme.swift`; replace the `var uiColor: UIColor` bridge with an `NSColor` equivalent (`var nsColor: NSColor`) OR, preferred, expose only the cross-platform `var color: Color` and delete the platform bridge if the macOS 3D scene can consume `NSColor(color)`. Keep the theme enum cases and names identical (`Meadow/Autumn/Winter/Candy/Night/Classic`).
- [ ] **Step 3:** `xcodegen generate --quiet`, build, confirm these two compile. **Commit.**

### Task A4: Port `CatanView` with the 2D board + macOS session wiring (SAFE CHECKPOINT)

**Files:**
- Create: `macos/Sources/Views/CatanView.swift` (from `ios/Sources/Features/Games/CatanView.swift`)
- Create: `macos/Sources/Model/CatanSession.swift` (macOS save/restore)
- Reference (read, do not edit): a simple macOS game with a `…Session` for the idiom, e.g. `macos/Sources/Views/SpiderView.swift` + its session and `GamePersistence` usage.

- [ ] **Step 1:** Create `CatanSession` mirroring a peer macOS game session: it owns a `CatanGame`, exposes save/restore through the macOS `GamePersistence`/`GameSessionState` API (NOT the iOS `PersistedGameSession`/`CatanSnapshot`, which don't exist on macOS). Match the persistence key convention used by peer sessions (e.g. `"catan"`).
- [ ] **Step 2:** Copy `CatanView.swift`; make these exact swaps (all listed in "Current-state facts"): remove `.navigationBarTitleDisplayMode(.inline)`; change `.toolbarBackground(…, for: .navigationBar)` to a macOS-safe placement or remove; change `ToolbarItem(placement: .topBarTrailing)` → `.automatic`; replace `UIAccessibility.isReduceMotionEnabled` with `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`; drop `.sensoryFeedback(.impact…)`. Change the view's init to accept the macOS `session` (e.g. `CatanView(session: CatanSession)`) instead of `accountID:`.
- [ ] **Step 3:** In this checkpoint, force the **2D `Canvas` board** (`boardStyle == .twoD`) as the default so the view is guaranteed to render even before the 3D board exists — the 3D branch can `#error`/be stubbed until A5. Keep all 6 themes / AI tiers / customization sheet wired.
- [ ] **Step 4: Register** — in `macos/Sources/Model/FacetRegistry.swift` add a `FacetDescriptor(id: "catan", …)` following the last entry (match the fields peers use: title "Catan", category/Board, icon, etc.); in `macos/Sources/App/ContentView.swift` add a `@StateObject`/property `catanSession` and a `case "catan": CatanView(session: catanSession)` in the routing switch (~`:221`).
- [ ] **Step 5:** `xcodegen generate --quiet`, build the macOS scheme (A7 command), fix errors until it exits 0.
- [ ] **Step 6: Launch + verify** — run `macos/scripts/deploy-mac.sh`, open Prismet, click the Catan facet, confirm the 2D board renders and a full solo game is playable (place, roll, trade, win). This is the **safe fallback state** if 3D fights.
- [ ] **Step 7: Commit** — `git commit -m "macOS Catan: 2D board playable + registry/routing wired"`.

### Task A5: Port `CatanScene3D` (SceneKit content builder)

**Files:**
- Create: `macos/Sources/Model/CatanScene3D.swift` (from `ios/Sources/Features/Games/CatanScene3D.swift`)

- [ ] **Step 1:** Copy the file; replace every `UIColor(...)` (≈5 sites: lines 148/158/191/292/297 in the iOS source) with `NSColor(...)`.
- [ ] **Step 2:** Port the `tokenImage` `UIImage` number-token renderer (iOS `:287`) to `NSImage`. Template: how `macos/Sources/Model`/views build `NSImage` textures for SceneKit materials — search the macOS chess/rubiks scene builders for `NSImage` texture usage and mirror it (e.g. draw into an `NSImage` via `lockFocus()`/`NSGraphicsContext` or `NSImage(size:flipped:drawingHandler:)`). Keep the function signature/return usage identical so the material assignment site is unchanged.
- [ ] **Step 3:** `CatanSceneGeometry` is already ported (A1) and SceneKit-only — no change. Build; fix until the scene builder compiles. **Commit.**

### Task A6: Port `CatanBoard3DView` to `NSViewRepresentable`

**Files:**
- Create: `macos/Sources/Views/CatanBoard3DView.swift` (from `ios/Sources/Features/Games/CatanBoard3DView.swift`)
- Reference (read): `macos/Sources/Views/RubiksCubeView.swift:348-430` (`RubiksSceneView: NSViewRepresentable` + `ClickableSCNView`).

- [ ] **Step 1:** Recreate `CatanBoard3DView` as `struct CatanBoard3DView: NSViewRepresentable` with `makeNSView`/`updateNSView` mirroring the iOS `makeUIView`/`updateUIView` bodies (scene assembly is the same SceneKit calls). Use `SCNView` (cross-platform) as the view.
- [ ] **Step 2:** Replace `TappableCatanSCNView: SCNView` (UIKit touch hit-test) with a mouse-based subclass modeled on `ClickableSCNView` in `RubiksCubeView.swift`: override `mouseDown`/`mouseDragged`/`mouseUp` to distinguish a click (hit-test → vertex/edge/hex tap → forward to the game) from an orbit drag; keep default camera-control for orbit/zoom/pan. Preserve the same tap-callback closure interface `CatanView` passes in.
- [ ] **Step 3:** In `macos/Sources/Views/CatanView.swift`, un-stub the 3D branch: `boardStyle == .threeD` now renders `CatanBoard3DView(...)`; restore the iOS default board style (3D default) and the 2D/3D toggle in the customization sheet.
- [ ] **Step 4:** `xcodegen generate --quiet`; build; fix until exit 0.
- [ ] **Step 5: Commit** — `git commit -m "macOS Catan: NSViewRepresentable 3D SceneKit board + mouse hit-testing"`.

### Task A7: Build, launch, and verify macOS Catan (3D)

**Build/deploy command (the macOS analog of the iOS deploy):**
```bash
cd /Users/gtrktscrb/Desktop/Kaleidoscope/macos && ./scripts/deploy-mac.sh
```
(Internally: `xcodegen generate` → `xcodebuild -project Prismet.xcodeproj -scheme Prismet -destination 'platform=macOS' -derivedDataPath ~/Library/Caches/Prismet-mac-build CODE_SIGNING_ALLOWED=NO build` → install/launch `~/Applications/Prismet.app`.)

- [ ] **Step 1:** Run the command. Expected: exit 0, `~/Applications/Prismet.app` launches.
- [ ] **Step 2:** Open Catan from the Prismet home grid. Verify: **3D board renders**, orbit/zoom/pan by mouse works, clicking a vertex/edge/hex registers the correct game action, all 6 themes apply, AI difficulty tiers selectable, 2D/3D toggle switches cleanly, a full solo game reaches a legit win.
- [ ] **Step 3 (eyes-free aid if needed):** if visual verification on-screen is impractical, mirror the iOS offscreen render technique (`ios/Tests/CatanRenderHarnessTests.swift` renders board PNGs via `SCNRenderer`) into a macOS render-harness test, dump PNGs, and Read them.
- [ ] **Step 4:** Run the iOS↔macOS parity gate: `scripts/check-mac-ios-parity.sh --strict` — expected PASS now that macOS Catan exists (this un-blocks removing `KALEIDOSCOPE_SKIP_PARITY` from the release build).
- [ ] **Step 5:** Update `ios/docs/MAC-IOS-GAME-PARITY.md` — flip the Catan row from TRACKED DEBT to done (3D parity), add a Parity Log entry. **Commit.**
- [ ] **Step 6: PRISM RELEASE** — append the macOS-Catan RELEASE entry to `docs/AGENT-COORDINATION.md` with build/launch/parity status.

**Fallback:** if A5/A6 fight the toolchain beyond a reasonable timebox, ship the A4 2D-playable state, re-file 3D as tracked debt in the parity doc, and flag to Sage. (Per the locked decision, 2D-only is the sanctioned fallback.)

---

## LANE B — Deploy to iPad simulator + Poopoohead iPhone

> The universal iOS build already contains the 3D SceneKit Catan (verified installed+launched on Poopoohead earlier today). This lane confirms iPad and re-confirms iPhone.

### Task B1: iPad simulator

- [ ] **Step 1: Boot the iPad sim** — `xcrun simctl boot 7EDA7E27-90E7-4368-8B9D-EF65A438E0EC` (iPad Pro 13-inch M4) and `open -a Simulator`.
- [ ] **Step 2: Build for the sim + install + launch:**
```bash
cd /Users/gtrktscrb/Desktop/Kaleidoscope/ios && xcodegen generate --quiet
xcodebuild -project Prismet.xcodeproj -scheme Prismet -configuration Debug \
  -destination 'platform=iOS Simulator,id=7EDA7E27-90E7-4368-8B9D-EF65A438E0EC' \
  -derivedDataPath ~/Library/Caches/Prismet-build-sim build
APP=$(find ~/Library/Caches/Prismet-build-sim/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)
xcrun simctl install 7EDA7E27-90E7-4368-8B9D-EF65A438E0EC "$APP"
xcrun simctl launch 7EDA7E27-90E7-4368-8B9D-EF65A438E0EC com.spocksclub.kaleidoscope
```
Expected: build exits 0; app installs; launches in the iPad sim.
- [ ] **Step 3: Verify** Catan opens and the 3D board renders on iPad layout (screenshot via `xcrun simctl io <id> screenshot /tmp/ipad-catan.png`; Read it).

### Task B2: Poopoohead iPhone (re-confirm)

- [ ] **Step 1:** Confirm Poopoohead is connected: `xcrun devicectl list devices | grep Poopoohead` (expect `available (paired)`).
- [ ] **Step 2:** `cd /Users/gtrktscrb/Desktop/Kaleidoscope/ios && KALEIDOSCOPE_SKIP_PARITY=1 ./scripts/deploy.sh` (keep the skip flag until Lane A lands macOS Catan and the parity gate passes; after that, the flag is unnecessary). Expected: exit 0, install + launch on Poopoohead. (If Lane A is already merged, drop `KALEIDOSCOPE_SKIP_PARITY=1`.)
- [ ] **Step 3: Verify** Catan on-device (3D board, playable).

---

## LANE C — Stage the Prismet 1.2 App Store push (prepare only)

### Task C1: Add the `catan` screenshot key

**Files:** Modify `ios/Sources/App/ShotHarness.swift` (switch at `:34-64`).

- [ ] **Step 1:** Add `case "catan": CatanView(accountID: nil)` (or the harness's account stub — match how peer game cases construct their view; if `CatanView` needs an account id, pass the harness's dummy as other cases do). Ensure the 3D board is the default so the shot shows the hero 3D board (optionally set the pref so `boardStyle == .threeD`, mirroring how `chess3d`/`chess2d` force `chess.is3D`).
- [ ] **Step 2:** `cd ios && xcodegen generate --quiet`; build the harness for a sim to confirm it compiles.
- [ ] **Step 3: Commit** — `git commit -m "screenshots: add catan shot key to ShotHarness"`.

### Task C2: Bump the build number

**Files:** Modify `ios/project.yml:84`.

- [ ] **Step 1:** Set `CURRENT_PROJECT_VERSION: "15"` (build 13 is in review, 14 was staged-then-superseded; 15 is the clean Catan build). Keep `MARKETING_VERSION: "1.2"`.
- [ ] **Step 2:** `xcodegen generate --quiet`; confirm `Info.plist` picks up `$(CURRENT_PROJECT_VERSION)=15`. **Commit** — `git commit -m "release: bump to 1.2 build 15 (Catan)"`.

### Task C3: Capture raw screenshots (iPhone 6.9″ + iPad 13″)

**Curated shot list (Catan-hero first):** `catan` (hero, 3D board), `home`, `chess3d`, `seabattle`, `2048`, `sudoku`, `solitaire`, `wordle`. (8 shots — Catan replaces nothing; it leads.)

**Files:** create `ios/docs/appstore-screenshots-1.2/` (raw).

- [ ] **Step 1:** Boot an iPhone 6.9″ sim (e.g. iPhone 17 Pro Max — pick the available 1320×2868 device from `xcrun simctl list devices available`) and the iPad Pro 13″ sim.
- [ ] **Step 2:** Build the Debug app once per sim (reuse the B1 pattern per device id).
- [ ] **Step 3:** For each shot key, capture on each device:
```bash
SIMCTL_CHILD_PRISMET_SHOT=<key> xcrun simctl launch <sim-id> com.spocksclub.kaleidoscope
sleep 2
xcrun simctl io <sim-id> screenshot ios/docs/appstore-screenshots-1.2/<device>_<key>.png
```
- [ ] **Step 4:** Verify raw dimensions: iPhone 6.9″ = 1320×2868; iPad 13″ = 2064×2752 (portrait). Read a couple of PNGs to confirm the intended screen rendered (esp. `catan` shows the 3D board). **Commit** the raw set.

### Task C4: Extend + run the framer for iPhone + iPad, Prismet-branded

**Files:** Modify `ios/scripts/generate-appstore-screenshots.py`.

- [ ] **Step 1:** Change `BRAND = "KALEIDESCOPE"` → `BRAND = "PRISMET"` (:13).
- [ ] **Step 2:** Parameterize canvas per device: keep iPhone `(1320, 2868)`; add iPad `(2064, 2752)`. Refactor the `SHOTS` list + main loop to render both device sets from `ios/docs/appstore-screenshots-1.2/<device>_<key>.png` → `.../final/<device>/NN_<key>.png`. Add the Catan hero entry first with title/subtitle (e.g. title "Catan", subtitle "Build on a cozy 3D board").
- [ ] **Step 3:** Run `python3 ios/scripts/generate-appstore-screenshots.py`. Expected: framed PNGs for both device families in `ios/docs/appstore-screenshots-1.2/final/{iphone,ipad}/`.
- [ ] **Step 4:** Read 2–3 framed outputs (incl. the Catan hero on both devices) to confirm branding says PRISMET, framing is clean, no clipping. **Commit** the framer change + final set.

### Task C5: Rewrite the listing copy (Prismet, Catan-forward)

**Files:** Modify `ios/docs/APP-STORE-LISTING.md`. Use exactly this copy (respect the noted limits):

- [ ] **Step 1 — App name (≤30):** `Prismet`
- [ ] **Step 2 — Subtitle (≤30):** `20+ classic games & Catan` (25)
- [ ] **Step 3 — Promotional text (≤170, editable without review):**
  `New: Catan on a cozy, zoomable 3D board — build settlements, cities, and roads. Plus 20+ classics: Chess, Wordgame, 2048, Sudoku, Sea Battle, Solitaire, and more. Free to play.`
- [ ] **Step 4 — Keywords (≤100, comma-separated, no spaces):**
  `catan,settlers,wordgame,2048,sudoku,chess,solitaire,minesweeper,snake,seabattle,gomoku,board,puzzle`
- [ ] **Step 5 — Description:** replace the body so it opens with Prismet + Catan:
  ```
  Prismet is a calm home for classic games and daily puzzles. Open one app and jump into Catan, Chess, Wordgame, 2048, Sudoku, Solitaire, Sea Battle, and more — each with its own hand-crafted look.

  NEW — CATAN
  Build settlements, cities, and roads on a cozy, zoomable 3D board. Six board themes, adjustable AI opponents, and up to four players. A relaxed take on the classic you know.

  GAMES INCLUDED
  • Catan — settlements, cities, roads, robber, dev cards, longest road & largest army
  • Wordgame — daily five-letter guessing
  • Chess — 2D or 3D board
  • 2048, Sudoku, Minesweeper, Snake, Nonogram, Lights Out, Sliding Puzzle
  • Solitaire & Spider
  • Sea Battle, Checkers, Reversi, Connect Four, Gomoku, Crazy 8
  • Rubik's Cube, Brick Bench
  • Bonus lenses: Oracle, Debt Clock, Steam Rewind

  DESIGNED TO FEEL GOOD
  Handsome, hand-crafted screens. Calm sound. No clutter. Play offline, no account required.

  Free to play. More games and features on the way.
  ```
- [ ] **Step 6 — What's New (v1.2 / build 15):**
  `NEW: Catan. Build settlements, cities, and roads on a cozy, zoomable 3D board — six themes, adjustable AI, and up to four players, on iPhone, iPad, and Mac. Plus more resilient online friend rooms, smoother tester-device deployment, and build/warning cleanup across the app.`
- [ ] **Step 7:** Update the file's brand references from "Kaleidescope" → "Prismet" in the copy blocks (leave a one-line historical note that the public ASC name flip is a manual submit-time step). Verify each field is within its character limit. **Commit** — `git commit -m "listing: Prismet 1.2 copy, Catan-forward"`.

### Task C6: Assemble the submit-ready handoff (do NOT submit)

- [ ] **Step 1:** Write `ios/docs/appstore-screenshots-1.2/README.md` (or extend the listing kit) with the manual submit checklist for Sage: archive a **Release** build (`SWIFT_COMPILATION_MODE=incremental`), upload via Xcode Organizer, upload the framed iPhone + iPad sets, paste the C5 copy, answer age-rating/privacy, then submit.
- [ ] **Step 2:** Explicitly record the **release gates** (see below) at the top of that checklist.
- [ ] **Step 3: Commit.** Stop here — hand back to Sage. No upload, no ASC PATCH, no submit.

---

## Release gating & sequencing (surface to Sage before any submit)

1. **v1.1/build 13 is WAITING_FOR_REVIEW.** App Store Connect will not accept a new version for review while one is in review — 1.1 must be approved/released (or its submission removed) before 1.2/build 15 can be submitted.
2. **Catan is on this unmerged research branch, which is diverged from origin** (local 5 / remote 2 — the remote has an alt Catan-board polish `d647014` + the additive `OnlineGameCatalog` `706edad`). A submittable release build requires reconciling the branch and merging Catan into the release line. Per Sage's 2026-07-13 call, ship the local SceneKit board; decide separately whether to cherry-pick `706edad` (OnlineGameCatalog, clean) before release.
3. **Public ASC name flip** ("Kaleidescope" → "Prismet") is a manual ASC step; the staged materials already say Prismet.
4. **macOS parity gate:** once Lane A lands, `check-mac-ios-parity.sh --strict` should pass, so the release build no longer needs `KALEIDOSCOPE_SKIP_PARITY=1`.

**Suggested execution order:** Lane B first (fast, confirms the build on both form factors) → Lane A (the substantial port) → Lane C (materials, which want the macOS parity gate green and a Catan build to screenshot).

---

## Self-review

- **Spec coverage:** "send it to the macos app" → Lane A (full 3D per decision, 2D fallback documented). "ipad sim and poopoohead phone" → Lane B (both). "prismet 1.2 push, better screenshots, appropriate description" → Lane C (Prismet brand, Catan-hero + iPad set + refresh, rewritten copy). Prepare-not-submit + release gates captured.
- **Placeholder scan:** listing copy is complete/literal; the only intentionally-recipe (not verbatim-code) steps are the Swift view ports — justified because they are mechanical transformations of existing 200–700-line files with named template files and an itemized API-swap list, and dumping the full ported files here would be premature and error-prone. Model ports are verbatim copies.
- **Type consistency:** view/model/type names kept identical to iOS across tasks (`CatanGame`, `CatanBoard`, `CatanAI`, `CatanScene3D`, `CatanBoard3DView`, `CatanSceneGeometry`, `CatanTheme`, `CatanView`, facet id `"catan"`, persistence key `"catan"`, build 15).
- **Scope:** three independent lanes; each is independently testable/shippable. Lane A alone is a coherent macOS feature; Lane C alone stages a release.
