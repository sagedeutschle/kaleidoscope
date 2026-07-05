# Prismet v13 consolidation + rename pass — design

**Date:** 2026-07-04 (night shift) · **Author:** Claude/Fable (Sage's design lane, prismet org)
· **Status:** approved by Sage · **Supersedes nothing** — continues
`2026-07-04-prismet-parity-pass-design.md` (Tasks 3–7 of its plan fold into this pass).

## Purpose

One pass, four outcomes, decided with Sage tonight:

1. **Finish and land every moving piece** already in flight: the four uncommitted macOS
   game ports (Gomoku, Sea Battle, Crazy 8, Spider) in the spark worktrees, the
   material-identity mirrors, macOS Home tile art + regroup, the iPad sweep, and
   Agent-A's uncommitted iOS leaderboard-identity hardening (verify → fix → fold in).
2. **Rename Kaleidoscope → Prismet uniformly** — user-facing + internal, with a hard
   freeze list of identities that must not change (see §Rename).
3. **Ship build 13 aligned on all three platforms** — iOS (iPhone + iPad) bumps 12→13,
   macOS jumps 11→13 — and **dev-deploy to all three devices** (Poopoohead iPhone 15
   Plus, iPad Air 13", macOS). No TestFlight upload tonight; the v1.0/build-8 App Store
   review fork stays untouched and Sage-gated.
4. **Sync every location:** docs rewritten to current state, git pushed, GitHub repo
   renamed, the stale NAS clone (14 commits behind, pre-Moguls — the "missing Moguls"
   report) pulled up to date, project memory saved.

Approach chosen (of three considered): **land everything first, rename last as one
atomic commit on a quiet tree, then bump + deploy.** Rename-first was rejected because
it invalidates the finished spark ports; a parallel rename branch was rejected because
it conflicts with every in-flight diff.

## Inspection findings this design rests on (verified 2026-07-04 evening)

- Desktop clone `~/Desktop/Kaleidoscope` = canonical; main at `13a9098`, 1 commit
  unpushed; Agent-A's 7-file iOS leaderboard diff uncommitted ("handed to Fable",
  known Postgrest drift, no test run).
- Four spark worktrees `~/Desktop/kscope-spark-{gomoku,seabattle,crazy8,spider}` at
  `a4d0fc8`, each holding complete uncommitted port files (model + AI + session + view);
  no codex processes still running; branches have zero commits.
- NAS clone `/Volumes/homes/PrismetSharedFolder/Kaleidoscope` stale at `a929aae`
  (pre-Moguls, pre-SteamRewind, pre-build-12).
- Versions: iOS `CURRENT_PROJECT_VERSION=12`, macOS `11`, marketing `1.0` both.
- Moguls exists on both platforms in the Desktop clone (`MogulModel/MogulSource/
  MogulsView` iOS + macOS, `moguls.json` resource) — nothing needs re-porting.
- macOS app installed at `13a9098`; iPhone deploy last night unconfirmed; iPad Air was
  unplugged and has never received a recent build.
- Live PRISM claims: the parity-pass orchestrator claim (hotspots:
  `FacetRegistry.swift`, `ContentView.swift`, `GamePersistence.swift`, both ledgers,
  parity matrix) — this session resumes that lane.

## Stages

### Stage 0 — Preflight (orchestrator)
Push/sync Desktop clone with origin; PRISM ledger claim for this pass; baseline
`xcodegen generate` + builds on both platforms (know what's red before fan-out);
**check iPad Air connectivity via `devicectl` now** — surface to Sage immediately if
unplugged. Confirm `gh` + `flyctl`-independent tonight (no web infra in scope).

### Stage 1 — Parallel lanes
- **Spark-port lane (codex #1, then orchestrator):** per worktree — build with
  `CODE_SIGNING_ALLOWED=NO`, commit the port files per the parity-plan message format;
  orchestrator merges `--no-ff` serially, then wires registration (four
  `FacetDescriptor`s, `ContentView` routes + `@StateObject`s + save/reload switch
  entries) — hotspot files stay orchestrator-only. Facet `id` strings are contracts:
  `gomoku`, `sea-battle`, `crazy-8`, `spider` (cross-check `KaleidoscopeFeatureManifest`).
- **Leaderboard lane (codex #2):** review Agent-A's diff, fix the Postgrest API drift,
  run the full iOS suite, commit the slice + both ledger hunks (Agent-A's entries are
  already written in the dirty ledgers — committing them closes that thread).
- **Design-mirror lane (sonnet #1–4, fresh isolated worktrees off current main —
  mirror target files don't overlap the spark ports, so no need to wait for merges):**
  one mirror each — walnut 2048 tray → `Game2048View.swift`; club Checkers →
  `CheckersView.swift`; Solitaire baize + real card faces → `SolitaireView.swift`;
  Brick Bench workshop chrome (chrome only, not the 3D scene) → `LegoBuilderView.swift`.
  Lane rule: each agent touches ONLY its named view file(s); iOS reference views named
  in the plan; commit on branch, orchestrator merges.
- **Opus #1:** iPad sweep audit on simulator (Home, one game per family, Debt
  Clock/Moguls, Steam Rewind lenses) — produces a fix list with screenshots; fixes land
  Stage 2.
- **Opus #2:** remaining design-lane mirrors — Chess plaques/swatches, Oracle ledger
  card (`DecreeView`), per-game skin pickers where iOS has them.

### Stage 2 — Convergence (orchestrator + opus #1)
macOS Home: copy `tile_<game>` imagesets from iOS assets, render image tiles in
`HomeLensView` (+ optional `tileImage` on `FacetRegistry`), regroup `FacetCategory` to
match iOS Home sections. Opus #1's iPad fixes land with a parity decision logged per
fix. Everything merged; both platforms build green; macOS model tests (~180) + full
iOS suite green. Worktrees removed, spark branches deleted.

### Stage 3 — Rename Kaleidoscope → Prismet (one atomic commit)

**In scope:** app display name on all three platforms (home screen / dock / About);
`project.yml` project/scheme/target names + generated `.xcodeproj` names; code symbols
(`KaleidoscopeApp`→`PrismetApp`, `KaleidoscopeDesign`→`PrismetDesign`, shared package
`KaleidoscopeShared`→`PrismetShared` incl. `KaleidoscopeFeatureManifest`→
`PrismetFeatureManifest`, and remaining `Kaleido*` prefixes); scripts (deploy-mac,
parity check, sync helpers, derived-data cache names); all **current-state** docs
(README, AGENTS.md, CLAUDE.md, HANDOFF, RELEASE-GATES, parity matrix, setup docs);
Desktop folder `~/Desktop/Kaleidoscope` → `~/Desktop/Prismet`; NAS inner folder
`PrismetSharedFolder/Kaleidoscope` → `PrismetSharedFolder/Prismet`; GitHub repo
`sagedeutschle/kaleidoscope` → `sagedeutschle/prismet` (old URLs redirect; update
remotes on both clones).

**Frozen — must NOT change (breakage list):**
- Bundle IDs `com.spocksclub.kaleidoscope` (iOS — ASC record 6785993194, Game Center,
  in-review v1.0) and `com.gtrktscrb.kaleidoscope` (macOS — container identity).
- IAP product id `com.spocksclub.kaleidoscope.removeads`; Supabase project ref;
  Oracle gist id; ASC app record.
- **On-disk persistence paths, save file names, and UserDefaults keys** — renaming
  these silently wipes local saves; they stay legacy. Same for `Info.plist` custom key
  *values* that gate entitlement hashes (`KaleidoscopeAdUnlockCodeHashes` etc.) —
  key names may rename only if the reading code renames in the same commit and no
  persisted data is keyed on them; when in doubt, freeze.
- Facet/card/asset `id` strings (contracts) and the append-only coordination-ledger
  history (log entries stay verbatim; only living docs rename).
- `ios/Sources/Backend/Secrets.swift` (gitignored) — untouched.

**Consequential repoints in the same stage:** Oracle launchd plist
(`com.gtrktscrb.wkd.daily`) points at the Desktop path — update + `launchctl` reload +
verify; sweep scripts/docs for absolute `/Users/gtrktscrb/Desktop/Kaleidoscope` paths;
old `~/Applications/Kaleidoscope.app` removed when Prismet.app deploys.

**Gate:** `grep -ri kaleidoscope` sweep with an explicit allowlist (frozen items
above), `xcodegen generate` + full rebuild + both test suites green post-rename.

### Stage 4 — Build 13 + deploys
Bump iOS `CURRENT_PROJECT_VERSION` 12→13 and macOS 11→13 (aligned by decision);
`check-mac-ios-parity.sh --strict` green (script updated for new names);
deploys — macOS via deploy script → `~/Applications/Prismet.app`; iPhone Poopoohead
(xcodebuild wants hardware UDID `00008120-001278982192201E`, devicectl wants CoreDevice
`B2081DF4-7D29-5F35-8CC4-18227227036B`) and iPad Air (hw `00008122-001E79A20EB9801C`,
CoreDevice `F4E0AAC6-BAAC-5213-A50D-EB233908A105`) via the codex CLI path (codex #3).
Clean-install checks (RELEASE-GATES §F): Oracle consult non-empty on fresh install;
online head-to-head smoke iPhone↔iPad.

### Stage 5 — Docs, git, shared folders, memory
HANDOFF.md rewritten to current state; RELEASE-GATES §E/§F ticked (or explicitly
deferred with owner — e.g. macOS online-friend wiring stays a Codex handoff);
parity-matrix rows updated; PRISM RELEASE entries; NIGHTSHIFT doc §Run log entry;
all commits pushed; GitHub repo renamed; **NAS clone pulled to head** (closes the
missing-Moguls staleness); project memory files saved (locations map, v13 state,
rename freeze list, build gotchas).

## Agent allocation (budget: 2 opus + 4 sonnet Claude, 3 codex)

| Agent | Stage 1 | Later stages |
|---|---|---|
| codex #1 | spark-port verify + commit ×4 | — |
| codex #2 | leaderboard verify + fix + suite | — |
| codex #3 | — | Stage 4 device deploys + iOS suite runs |
| sonnet #1–4 | one material mirror each | — |
| opus #1 | iPad sweep audit | Stage 2 iPad fixes |
| opus #2 | Chess plaques + Oracle card + skin pickers | Stage 3 rename transform assist |
| orchestrator | merges, registration, hotspots | tile art/regroup, rename, bumps, gates, deploys, docs, NAS, memory |

Orchestrator exclusively owns: `FacetRegistry.swift`, `ContentView.swift`,
`GamePersistence.swift`, both `project.yml`s, both ledgers, parity matrix, all merges.

## Working rules (unchanged from AGENTS.md; restated)
Small commits pushed per unit; derived data under `~/Library/Caches/` only; archives
`SWIFT_COMPILATION_MODE=incremental`; `xcodegen generate` after every pull/merge; never
build on the NAS mount; NAS gets git-pull only.

## Risks / mitigations
- **Spark ports never compiled post-merge** → codex verifies per worktree before any merge.
- **macOS test-host hang (documented)** → `CODE_SIGNING_ALLOWED=NO` build + model tests.
- **iPad unplugged** → checked at Stage 0; if absent, its deploy is the pass's single
  open item, everything else proceeds.
- **Rename hidden couplings** (storage paths, plist keys, string-typed lookups) →
  freeze list + allowlisted grep sweep + full rebuild/suite gate; symbol renames done
  per-symbol (not blind sed) on Swift sources.
- **Desktop folder rename breaks external pointers** → Oracle plist repoint + reload;
  absolute-path sweep; worktrees removed before rename.
- **Swift type-checker timeouts on big views** → extract subviews early (precedent).
- **SMB slowness/hangs on NAS** → all NAS operations are end-of-pass git pulls; no
  builds, no greps over the mount.

## Out of scope (explicit)
- TestFlight/ASC upload of build 13; the v1.0 build-8/11 review fork (Sage-gated).
- Bundle-ID / store-identity / Supabase / gist changes (frozen forever list).
- macOS online-friend multiplayer wiring (tracked Codex handoff).
- Shared-package model convergence; CI; ads/IAP activation.
- The `archive/Kaleidoscope.stale-pre-git-20260704` NAS copy (stays archived as-is).

## Definition of done
All Stage 1–2 work merged and green on both platforms; rename complete with a clean
allowlisted grep sweep; both apps at build 13; installed and verified on macOS +
iPhone + iPad (or iPad explicitly logged unavailable); RELEASE-GATES §E fully ticked;
docs/ledger/NIGHTSHIFT run-log current; origin pushed + repo renamed; NAS clone at
head; memory saved.
