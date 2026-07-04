# Prismet session onboarding + cross-platform parity pass — design

**Date:** 2026-07-04 · **Author:** Claude/Fable (Sage's design lane, running under the prismet org account) · **Status:** approved by Sage, pending spec review

## Purpose

Two goals, one pass:

1. **Onboard the prismet-org Claude session** into the established Kaleidoscope repo
   workflow (git-through-GitHub + PRISM ledger), so Sage's agent work flows to the repo
   cleanly from the new account.
2. **Pay down the cross-platform release gates** with a parity + polish pass across
   iPhone, iPad, and macOS — closing RELEASE-GATES §E (macOS ↔ iOS parity) and the
   §F device-verification items.

Approach chosen (of three considered): **gates-first, per-game vertical mirrors** —
port games macOS-native following the existing facet pattern; no shared-package model
convergence this pass (that remains Codex's lane, tracked as debt).

## Part 1 — Prismet session workflow onboarding

The session runs under the prismet org (`xx_gtrktscrb_xx@prismet.xyz`); git access is
machine-level SSH and unchanged. Deliverables:

1. **Round-trip proof:** `git pull --rebase` → commit → `git push` from this session
   (this spec's commit is the proof).
2. **Ledger claim:** a `PRISM: CLAIM` entry in `docs/AGENT-COORDINATION.md` naming this
   agent and the parity-pass lane + files. (Deferred until the currently in-flight
   Agent-A working tree commits, to avoid entangling ledger hunks.)
3. **Identity note:** one line in `AGENTS.md` §2 noting Sage's Claude agents may appear
   under the prismet org account, so Ben's agents can attribute work correctly.

Success = a commit from this session on `origin/main` and the ledger/docs entries live.

## Part 2 — Parity + polish pass

### Stage 1 — Port the four missing games to macOS (hard release gate)

Order: **Gomoku → Sea Battle → Crazy 8 → Spider**. Per game:

- **Model + AI:** copy from `ios/Sources/Core/Games/` → `macos/Sources/Model/`,
  logic byte-preserved; adapt iOS-only sync hooks (`GameSync`) to macOS
  `GamePersistence` / `GameSessionState` conventions.
- **View:** new desktop-idiom SwiftUI view in `macos/Sources/Views/<Game>View.swift`
  (mouse/keyboard-first, window sizing), carrying the v10/v11 material identity —
  Gomoku goban; GamePigeon-style card skins for Sea Battle, Crazy 8, Spider.
- **Registration:** `FacetRegistry` descriptor + `ContentView` route + Home lens entry.
- **Tests:** port the iOS model tests to `macos/Tests/`.
- **Scope call:** Solo AI + local play land in this pass. **Online-friend mode**
  (Gomoku, Sea Battle, Crazy 8) needs Supabase multiplayer wiring on macOS — that is
  Codex's lane; logged as a tracked handoff in the ledger + parity matrix, not
  silently dropped.

### Stage 2 — Material-identity mirrors (macOS)

Mirror the v10/v11 identities: walnut 2048 tray · club Checkers board · Chess
plaques/swatches · Oracle ledger card · Solitaire baize + real card faces · Brick
Bench workshop chrome · per-game skin pickers where iOS has them. (Gomoku goban ships
with its Stage 1 port.)

### Stage 3 — macOS Home

Full-color `tile_<game>` art in the macOS launcher (replacing the old icon treatment)
and the Home category regroup in `FacetRegistry`, matching the iOS grouping.

### Stage 4 — iPad sweep

The app is universal (`TARGETED_DEVICE_FAMILY = 1,2`) as of 2026-07-03. Audit the key
views for iPad layout (grid columns, popovers, sheet/split sizing), fix what's off,
deploy to the iPad Air 13" via the codex CLI (deploy currently pending device wake) and
screenshot-verify.

### Stage 5 — iPhone polish + QA close

- Full iOS test suite green; `ios/scripts/check-mac-ios-parity.sh --strict` clean.
- Clean-install checks from RELEASE-GATES §F: Oracle consult non-empty on fresh
  install; online head-to-head smoke test.
- Deploys: iPhone 15 Plus + iPad Air via codex; macOS via `macos/scripts/deploy-mac.sh`.
- Docs updated as items land: `ios/docs/MAC-IOS-GAME-PARITY.md` matrix,
  `docs/RELEASE-GATES.md` checkboxes, `docs/HANDOFF.md`.

### Working rules (from AGENTS.md, restated as pass requirements)

- Small commits, pushed per completed unit; ledger claim/release per stage.
- Loud claims on collision hotspots: `FacetRegistry.swift`, `ContentView.swift`,
  `HomeView.swift`, either `project.yml`.
- Card `id` strings and asset ids are contracts — never renamed.
- Build locally, derived data in `~/Library/Caches/KaleidoscopeBuild`; archives use
  `SWIFT_COMPILATION_MODE=incremental`; `xcodegen generate` after every pull.
- iOS device deploys delegated to the codex CLI (hardware UDID for xcodebuild,
  CoreDevice id for devicectl).

### Risks and mitigations

- **macOS test-host hang (documented):** fall back to `CODE_SIGNING_ALLOWED=NO` builds
  + model-test verification, as done in prior passes.
- **Swift type-checker timeouts on large inline views:** extract subviews early
  (BoardSegment precedent).
- **Concurrent agents in this clone:** pull-rebase + ledger sweep before every unit;
  if a needed file is lane-claimed, carry as tracked debt rather than editing through.

### Out of scope (explicit)

- Lifting game models into `shared/KaleidoscopeShared` (Codex convergence lane).
- Online-friend multiplayer wiring on macOS (Codex handoff).
- The Kaleidoscope → Prismet rename (separate effort; repo/app names unchanged).
- CI / GitHub Actions automation.
- Ads/IAP work (post-v1 per RELEASE-GATES §C/§D).

## Definition of done

RELEASE-GATES §E items checked (or explicitly marked deferred with owner), §F
clean-device verification done on both iOS devices, macOS app deployed and playable
with the four new games and mirrored identities, test suites green on both apps, and
every unit logged in the coordination ledger.
