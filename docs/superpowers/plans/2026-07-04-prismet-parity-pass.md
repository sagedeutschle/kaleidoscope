# Prismet Parity Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This run: orchestrator executes inline (executing-plans) with **4 codex sparks** as parallel workers in git worktrees.

**Goal:** Close RELEASE-GATES §E — port Gomoku, Sea Battle, Crazy 8, Spider to macOS with material identity, mirror the v10/v11 redesigns, land macOS Home tile art + regroup, sweep iPad layout, and finish with green tests + device verification on iPhone/iPad/macOS.

**Architecture:** Per-game vertical mirrors following the established macOS facet pattern (`Model/<Game>Game.swift` + `<Game>Session` ObservableObject + `Views/<Game>View.swift` + `FacetRegistry` descriptor + `ContentView` route). Sparks work in isolated worktrees on disjoint files; ONLY the orchestrator touches shared hotspots (`FacetRegistry.swift`, `ContentView.swift`, `GamePersistence.swift`, ledgers).

**Tech Stack:** SwiftUI (macOS 14), XcodeGen, XCTest, codex CLI (`/Applications/Codex.app/Contents/Resources/codex exec`), git worktrees.

**Spec:** `docs/superpowers/specs/2026-07-04-prismet-parity-pass-design.md`

---

## Task 0: Prismet onboarding finish (orchestrator)

**Files:**
- Modify: `AGENTS.md` (§2 The collaborators)
- Modify: `docs/AGENT-COORDINATION.md` (append claim — commit deferred while Agent-A's uncommitted entry sits in the same file)

- [ ] **Step 1:** Add to `AGENTS.md` §2 under the Agents bullet: `Sage's Claude agents may appear under the prismet org account (xx_gtrktscrb_xx@prismet.xyz) — same human, same lanes.`
- [ ] **Step 2:** Append a `PRISM: CLAIM` entry to `docs/AGENT-COORDINATION.md` (newest-first position) claiming: macOS ports of Gomoku/Sea Battle/Crazy 8/Spider via 4 codex spark worktrees, orchestrator-owned `FacetRegistry.swift` + `ContentView.swift` + `GamePersistence.swift`, spec+plan paths. Working-tree visibility = live claim; commit the ledger hunk only when Agent-A's dirty entry has been committed by their session.
- [ ] **Step 3:** Commit `AGENTS.md` alone: `git add AGENTS.md && git commit -m "AGENTS: note Sage's Claude agents may run under the prismet org"`

## Task 1: Persistence prep commit (orchestrator, on main — MUST land before sparks branch)

**Files:**
- Modify: `macos/Sources/Model/GamePersistence.swift`

- [ ] **Step 1:** Add four cases to `GamePersistenceKind`: `gomoku`, `seaBattle`, `crazyEight`, `spider`; extend `fileName` with `"gomoku.json"`, `"sea-battle.json"`, `"crazy-8.json"`, `"spider.json"`.
- [ ] **Step 2:** Add generic methods to `GamePersistenceStore` (so sparks never edit this file):

```swift
func saveSnapshot<T: Codable>(_ value: T, kind: GamePersistenceKind, windowSessionID: String) throws {
    try save(value, to: url(for: kind, windowSessionID: windowSessionID))
}

func loadSnapshot<T: Codable>(_ type: T.Type, kind: GamePersistenceKind, windowSessionID: String) throws -> T? {
    try load(type, from: url(for: kind, windowSessionID: windowSessionID))
}
```

- [ ] **Step 3:** Build check: `cd macos && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -derivedDataPath ~/Library/Caches/KaleidoscopeBuild CODE_SIGNING_ALLOWED=NO build` → `BUILD SUCCEEDED`.
- [ ] **Step 4:** `git add macos/Sources/Model/GamePersistence.swift && git commit -m "macOS: persistence kinds + generic snapshot store methods for Gomoku/SeaBattle/Crazy8/Spider ports" && git push`

## Task 2: Spark worktrees + launch (orchestrator)

- [ ] **Step 1:** Create 4 worktrees from post-prep main:

```bash
cd ~/Desktop/Kaleidoscope
for g in gomoku seabattle crazy8 spider; do
  git worktree add -b spark/$g-macos ~/Desktop/kscope-spark-$g main
done
```

- [ ] **Step 2:** Launch each spark in the background: `cd ~/Desktop/kscope-spark-<g> && /Applications/Codex.app/Contents/Resources/codex exec --full-auto "<prompt below>"` (verify sandbox/approval flags via `codex exec --help` first; each spark builds with its own derived data path).
- [ ] **Step 3:** Render the agent status board (visualize widget) and re-render at checkpoints.

**Spark prompt template** (fill `<Game>`, `<gameId>`, files):

```
You are Spark-<N> porting <Game> from iOS to macOS in the Kaleidoscope monorepo (this worktree, branch spark/<g>-macos). Read AGENTS.md first. HARD LANE RULES: you may ONLY create/edit these files — macos/Sources/Model/<Game>Game.swift, macos/Sources/Model/<Game>AI.swift (if iOS has one), macos/Sources/Model/<Game>Session.swift, macos/Sources/Views/<Game>View.swift, macos/Tests/<Game>GameTests.swift. NEVER touch FacetRegistry.swift, ContentView.swift, GamePersistence.swift, project.yml, any ledger/docs, or anything under ios/. Do not register the facet — the orchestrator wires registration after merge; your files just need to compile in the target.

Port recipe:
1. Copy ios/Sources/Core/Games/<Game>Game.swift (+ <Game>AI.swift) to macos/Sources/Model/ — keep game logic byte-identical where possible; models are Foundation-only Codable. Strip iOS-only references (GameSync hooks, GamePlayMode online paths) but keep the core rules intact; note anything stripped in your final summary.
2. Write <Game>Session.swift following the exact pattern of macos/Sources/Model/GameSessionState.swift's Game2048Session: ObservableObject, a Codable <Game>SessionSnapshot (version field), configurePersistence(windowSessionID:store:), reloadSavedState(), saveNow(), snapshot()/restore(). Persist via the generic store methods: store.loadSnapshot(<Game>SessionSnapshot.self, kind: .<kindCase>, windowSessionID:) and store.saveSnapshot(_:kind:.<kindCase>, windowSessionID:).
3. Write <Game>View.swift taking `session: <Game>Session` (@ObservedObject), desktop idiom: mouse-first hit targets, hover states where natural, fixed min sizes that fit the ContentView detail pane. Match the material identity of the iOS view at ios/Sources/Features/Games/<Game>View.swift (<identity note>). Solo AI + local two-player only — omit online-friend UI. Follow the structure of an existing macOS game view (macos/Sources/Views/ReversiView.swift or CheckersView.swift) for chrome/controls. If a view body grows complex, extract subviews early (swift type-checker timeouts are a known gotcha).
4. Port the iOS model tests: find them with `ls ios/Tests | grep -i <game>`, copy to macos/Tests/<Game>GameTests.swift, adapt imports/names. Do not port online/multiplayer test cases.
5. Verify: cd macos && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -derivedDataPath ~/Library/Caches/KscopeSpark<N> CODE_SIGNING_ALLOWED=NO build. Expected: BUILD SUCCEEDED. (App-host `xcodebuild test` hangs are a known issue — a green build + ported test file is the deliverable; the orchestrator runs suites post-merge.)
6. Commit ONLY your files on this branch: git add macos/Sources/Model/<Game>*.swift macos/Sources/Views/<Game>View.swift macos/Tests/<Game>GameTests.swift && git commit -m "macOS: port <Game> (model+AI+session+view+tests) — spark <N>". Do NOT push, do NOT merge.
End your run with a summary: files created, anything stripped/deferred, build status.
```

**Spark assignments:**

| Spark | Game | Kind case | iOS sources | Identity note |
|---|---|---|---|---|
| 1 | Gomoku | `.gomoku` | GomokuGame/GomokuAI (131+254 ln) | wooden goban, stone pieces (v10 goban identity) |
| 2 | Sea Battle | `.seaBattle` | SeaBattleGame/SeaBattleAI (275+168 ln) | GamePigeon-style naval skin; keep the 5-ship deployment phase |
| 3 | Crazy 8 | `.crazyEight` | CrazyEightGame/CrazyEightAI (105+152 ln) | GamePigeon-style card skin; reuse PlayingCard (already in macOS Model) |
| 4 | Spider | `.spider` | SpiderGame (135 ln, one-suit) | baize + real card faces per Solitaire identity; reuse PlayingCard |

## Task 3: Merge sparks + registration (orchestrator — owns all shared files)

**Files:**
- Modify: `macos/Sources/Model/FacetRegistry.swift`
- Modify: `macos/Sources/App/ContentView.swift`

- [ ] **Step 1:** For each finished spark: review the branch diff (`git diff main..spark/<g>-macos`), then `git merge --no-ff spark/<g>-macos` on main (adds-only branches; conflicts none expected).
- [ ] **Step 2:** Add four `FacetDescriptor`s to `FacetRegistry.all` (ids are contracts — check `shared/KaleidoscopeShared` `KaleidoscopeFeatureManifest` for canonical ids before finalizing; default kebab-case shown):

```swift
FacetDescriptor(id: "gomoku", title: "Gomoku", systemImage: "circle.grid.3x3",
                accent: Color(red: 0.72, green: 0.55, blue: 0.30), category: .board, status: .ready),
FacetDescriptor(id: "sea-battle", title: "Sea Battle", systemImage: "lifepreserver",
                accent: Color(red: 0.22, green: 0.47, blue: 0.66), category: .board, status: .ready),
FacetDescriptor(id: "crazy-8", title: "Crazy 8", systemImage: "suit.club",
                accent: Color(red: 0.60, green: 0.28, blue: 0.55), category: .cards, status: .ready),
FacetDescriptor(id: "spider", title: "Spider", systemImage: "suit.spade",
                accent: Color(red: 0.25, green: 0.42, blue: 0.30), category: .cards, status: .ready),
```

- [ ] **Step 3:** Wire `ContentView.swift`: four `@StateObject private var <g>Session = <Game>Session()` (lines ~9-21 block), four `case "<id>": <Game>View(session: <g>Session)` routes (~line 196 block), four entries each in the `saveSession`/`reloadSession` switches (~lines 531/550 blocks).
- [ ] **Step 4:** `cd macos && xcodegen generate && xcodebuild ... CODE_SIGNING_ALLOWED=NO build` → `BUILD SUCCEEDED`; run model test suite where the host allows.
- [ ] **Step 5:** Launch the app (`./scripts/deploy-mac.sh`), click through all four new facets, verify play + save/reload.
- [ ] **Step 6:** Commit registration; push; append `PRISM: RELEASE` ledger entry (with Task 0's claim if now committable); update `ios/docs/MAC-IOS-GAME-PARITY.md` rows (Gomoku/Sea Battle/Crazy 8/Spider → mirrored, online-friend = tracked Codex handoff) and tick `docs/RELEASE-GATES.md` §E port items.
- [ ] **Step 7:** Remove worktrees: `git worktree remove ~/Desktop/kscope-spark-<g>` ×4; delete merged branches.

## Task 4: Material-identity mirrors (sparks round 2 + orchestrator)

Re-launch sparks in fresh worktrees from updated main, one mirror each — same lane rules (each touches ONLY its named view/model files):

| Spark | Mirror | Target file(s) | iOS reference |
|---|---|---|---|
| 1 | Walnut 2048 tray | `macos/Sources/Views/Game2048View.swift` | `ios/Sources/Features/Games/Game2048View.swift` |
| 2 | Club Checkers board | `macos/Sources/Views/CheckersView.swift` | `ios/Sources/Features/Games/CheckersView.swift` |
| 3 | Solitaire baize + real card faces | `macos/Sources/Views/SolitaireView.swift` | `ios/Sources/Features/Games/SolitaireView.swift` |
| 4 | Brick Bench workshop chrome | `macos/Sources/Views/LegoBuilderView.swift` (chrome only, not the 3D scene) | `ios/Sources/Features/Games/BrickBenchView.swift` |

Orchestrator (design lane, inline): Chess plaques/swatches (`macos/Sources/Views/` chess views), Oracle ledger card (`DecreeView`), per-game skin pickers where iOS has them, review + merge each spark branch as in Task 3.

- [ ] Sparks launched (round 2) → merged → build green → committed + pushed + matrix rows updated.
- [ ] Orchestrator mirrors done → build green → committed + pushed.

## Task 5: macOS Home tile art + regroup (orchestrator — hotspot files)

- [ ] **Step 1:** Copy the full-color `tile_<game>` imagesets from `ios/Sources/.../Assets.xcassets` (find with `find ios -name 'tile_*' -type d`) into `macos/Sources/Resources/Assets.xcassets/`.
- [ ] **Step 2:** Render image tiles in the macOS Home lens grid (`macos/Sources/Views/HomeLensView.swift` + `FacetRegistry` gains an optional `tileImage: String?`), falling back to `systemImage` where no art exists.
- [ ] **Step 3:** Regroup `FacetCategory` assignments to match the iOS Home grouping (compare `ios/Sources/Features/Home/HomeView.swift` catalog sections).
- [ ] **Step 4:** Build, visually verify, commit, push, tick RELEASE-GATES §E tile-art + regroup items.

## Task 6: iPad sweep (orchestrator + codex deploy)

- [ ] **Step 1:** Build for iPad sim: `cd ios && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -derivedDataPath ~/Library/Caches/KaleidoscopeBuild build` (adjust sim name to `xcrun simctl list devices available`).
- [ ] **Step 2:** Screenshot-audit Home, 3 game views (one per family: board/cards/puzzle), Debt Clock/Moguls, Steam Rewind on iPad sim; fix layout issues found (grid columns, popovers, sheet sizing). Every fix = parity decision logged.
- [ ] **Step 3:** Deploy to physical iPad Air via codex (CoreDevice `F4E0AAC6-BAAC-5213-A50D-EB233908A105`, hardware UDID `00008122-001E79A20EB9801C` for xcodebuild — device must be awake); verify.
- [ ] **Step 4:** Commit fixes, push, ledger entry.

## Task 7: QA close (orchestrator + codex)

- [ ] **Step 1:** Full iOS suite green on sim; `ios/scripts/check-mac-ios-parity.sh --strict` clean.
- [ ] **Step 2:** macOS build + model tests green; `./scripts/deploy-mac.sh`.
- [ ] **Step 3:** Clean-install checks: Oracle consult non-empty on fresh install; online head-to-head smoke (iPhone vs iPad).
- [ ] **Step 4:** Deploy to Poopoohead via codex (hardware UDID `00008120-001278982192201E`).
- [ ] **Step 5:** Update `docs/RELEASE-GATES.md` (§E/§F ticks), `docs/HANDOFF.md` (parity state), `ios/docs/MAC-IOS-GAME-PARITY.md`; final `PRISM: RELEASE` ledger entry; push.

## Standing rules for every task

- `git pull --rebase` + ledger sweep before each orchestrator unit; never stage Agent-A's dirty iOS files or ledger hunk.
- Derived data under `~/Library/Caches/` only; `SWIFT_COMPILATION_MODE=incremental` for any archive; `xcodegen generate` after every pull/merge.
- Card/facet `id` strings are contracts — never rename.
- Small commits per unit; push after each merged unit.
