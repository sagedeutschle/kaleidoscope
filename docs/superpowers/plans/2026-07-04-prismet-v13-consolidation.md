# Prismet v13 Consolidation + Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This run: orchestrator (Fable) executes hotspot tasks inline and dispatches the fan-out — 2 opus + 4 sonnet Claude subagents + 3 codex CLI agents.

**Goal:** Land every in-flight piece (4 macOS game ports, material mirrors, Home tile art + regroup, iPad sweep, leaderboard hardening), rename Kaleidoscope→Prismet (user-facing + internal, identities frozen), bump both platforms to build 13, dev-deploy to macOS + iPhone + iPad, and sync all docs/git/NAS.

**Architecture:** Per-game vertical mirrors on the established macOS facet pattern; sparks/mirrors work in isolated git worktrees on disjoint files; ONLY the orchestrator touches `FacetRegistry.swift`, `ContentView.swift`, `GamePersistence.swift`, both `project.yml`s, ledgers, and does merges. Rename is one atomic commit on a quiet tree, last before the version bump.

**Tech Stack:** SwiftUI (iOS 17 / macOS 14), XcodeGen, XCTest, git worktrees, codex CLI (`/Applications/Codex.app/Contents/Resources/codex exec`), Claude Agent tool (opus/sonnet), `devicectl`.

**Spec:** `docs/superpowers/specs/2026-07-04-prismet-v13-consolidation-design.md`

**Facts locked by inspection (2026-07-04 ~23:45):**
- Desktop clone `~/Desktop/Kaleidoscope` main = `98677c9`; origin/main = `a4d0fc8` (2 commits to push).
- 4 spark worktrees `~/Desktop/kscope-spark-{gomoku,seabattle,crazy8,spider}` on branches `spark/<g>-macos` at `a4d0fc8`, port files present but UNCOMMITTED and UNVERIFIED (sparks never built: their derived-data dirs were ~40KB).
- `GamePersistenceKind` already has `.gomoku/.seaBattle/.crazyEight/.spider` + generic `saveSnapshot`/`loadSnapshot` (prep commit `a4d0fc8`).
- `FacetDescriptor(id:title:systemImage:accent:category:status:)` + optional `caption`; `FacetCategory` = daily/puzzles/board/cards/oracle.
- `ContentView.swift`: `@StateObject` block lines ~8–21; route switch ~196–213; `configurePersistence` block ~496–506; `saveSession` switch ~531+; matching `reloadSession` switch below it.
- iOS Home categories: Daily, Puzzles, Board, Cards, Workshop, Lenses (`categoryOrder` line ~52 of `ios/.../HomeView.swift`).
- 22 `tile_*` imagesets exist on iOS, 0 on macOS. Tile names have no hyphens (`tile_seabattle`, `tile_crazyeight`).
- iOS build 12 / macOS build 11; `CFBundleDisplayName` ios/project.yml:49, `PRODUCT_NAME` ios:79 + macos:51, `INFOPLIST_KEY_CFBundleDisplayName` macos:57.
- iCloud-eviction incident recovered: all 26 unique-content files hydrated + backed up to `<scratchpad>/rescue/tree/`; full-tree hydration sweep queued. **Verify hydration before any build** (Task 0).
- NAS share `/Volumes/homes` UNMOUNTED — Stage-5 NAS sync blocked until remounted (Sage).

**Standing rules (every task):** derived data under `~/Library/Caches/` only; `xcodegen generate` after every pull/merge; `SWIFT_COMPILATION_MODE=incremental` for archives; never build on the NAS; facet/card `id` strings and asset ids are contracts; small commits per unit; never stage another agent's files.

---

## Task 0: Preflight gate (orchestrator, serial — everything else waits on this)

**Files:** `docs/AGENT-COORDINATION.md` (append claim; commit deferred until Task 3 lands Agent-A's ledger hunks)

- [ ] **Step 1: Hydration gate.** Run; require `0 dataless` before proceeding:

```bash
for d in ~/Desktop/Kaleidoscope ~/Desktop/kscope-spark-{gomoku,seabattle,crazy8,spider}; do
  n=$(find $d -type f \( -name "*.swift" -o -name "*.yml" -o -name "*.json" -o -path "*/.git/*" \) -print0 2>/dev/null | xargs -0 ls -lO 2>/dev/null | awk '$5 ~ /dataless/' | wc -l | tr -d ' ')
  echo "$d: $n dataless"
done
```
Expected: `0` on all five lines. If nonzero: re-run the sweep queue (`find <dir> -type f -print0 | xargs -0 -n 100 brctl download`), wait, re-check. Do NOT start builds with dataless files — xcodebuild will hang, not fail.

- [ ] **Step 2: Git sanity + push backlog.**

```bash
cd ~/Desktop/Kaleidoscope
ls .git/index.lock 2>/dev/null && echo "STALE LOCK — investigate before removing"
git status --short | head -20        # expect ONLY Agent-A's 7 iOS files + 2 ledgers + untracked plan/spec
git push origin main                  # pushes 13a9098 + 98677c9 + this plan's commit
```
Expected: push succeeds. If push hangs >60s, check network and retry once; log blocker otherwise.

- [ ] **Step 3: Commit this plan file.**

```bash
git add docs/superpowers/plans/2026-07-04-prismet-v13-consolidation.md && git commit -m "Plan: prismet v13 consolidation + rename pass" && git push
```

- [ ] **Step 4: iPad + iPhone availability check (surface early, don't block).**

```bash
xcrun devicectl list devices 2>/dev/null | grep -iE "ipad|poopoohead|iphone 15"
```
Expected: both devices listed as connected/available. If iPad absent → note "iPad deploy = open item" and continue.

- [ ] **Step 5: Baseline builds (know what's red).**

```bash
cd ~/Desktop/Kaleidoscope/macos && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -derivedDataPath ~/Library/Caches/PrismetPass-mac -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
cd ~/Desktop/Kaleidoscope/ios && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'generic/platform=iOS Simulator' -derivedDataPath ~/Library/Caches/PrismetPass-ios CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: macOS `BUILD SUCCEEDED`. iOS may fail ONLY in Agent-A's leaderboard files (known Postgrest drift — Task 3 fixes it). Any OTHER failure = stop and diagnose.

- [ ] **Step 6: Append PRISM claim** to `docs/AGENT-COORDINATION.md` (newest-first position, do not commit yet):

```
- `PRISM: CLAIM Agent-Design/Fable (Sage, prismet org) 2026-07-05 (v13 consolidation + rename pass)` —
  Executing docs/superpowers/plans/2026-07-04-prismet-v13-consolidation.md. Orchestrator owns:
  FacetRegistry.swift, ContentView.swift, GamePersistence.swift, both project.yml, both ledgers,
  parity matrix, all merges, the Stage-3 rename. Fan-out: codex×3 (spark verify, leaderboard fix,
  deploys), sonnet×4 (material mirrors), opus×2 (iPad sweep, chess/oracle mirrors + rename assist).
```

## Task 1: Spark-port verify + commit (codex agent #1; parallel with Tasks 3/4/5/6-audit)

Launch via Bash (background), one game at a time serially inside the agent (they share the repo object store):

```bash
cd ~/Desktop/kscope-spark-gomoku && /Applications/Codex.app/Contents/Resources/codex exec --full-auto "<PROMPT>"
```

**PROMPT template** (repeat per worktree, substituting game names):

```
You are verifying + committing an already-written macOS port of <Game> in this git worktree
(branch spark/<g>-macos). Read AGENTS.md first. HARD LANE RULES: you may edit ONLY
macos/Sources/Model/<Game>Game.swift, <Game>AI.swift (if present), <Game>Session.swift,
macos/Sources/Views/<Game>View.swift, macos/Tests/<Game>GameTests.swift. NEVER touch
FacetRegistry.swift, ContentView.swift, GamePersistence.swift, project.yml, ledgers, or ios/.
Steps: (1) cd macos && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj
-scheme Kaleidoscope -destination 'platform=macOS' -derivedDataPath ~/Library/Caches/PrismetSpark-<g>
CODE_SIGNING_ALLOWED=NO build. (2) Fix compile errors ONLY inside your lane files (missing-symbol
errors caused by files outside your lane: report, don't fix). (3) When BUILD SUCCEEDED:
git add macos/Sources/Model/<Game>*.swift macos/Sources/Views/<Game>View.swift macos/Tests/<Game>GameTests.swift
&& git commit -m "macOS: port <Game> (model+session+view+tests) — verified build". Do NOT push/merge.
End with: files committed, anything stripped, build status.
```

| Worktree | Game | Files present |
|---|---|---|
| kscope-spark-gomoku | Gomoku | GomokuGame/AI/Session + GomokuView + GomokuGameTests |
| kscope-spark-seabattle | SeaBattle | SeaBattleGame/AI/Session + SeaBattleView + SeaBattleGameTests |
| kscope-spark-crazy8 | CrazyEight | CrazyEightGame/AI/Session + CrazyEightView + CrazyEightGameTests |
| kscope-spark-spider | Spider | SpiderGame/Session + SpiderView + SpiderGameTests (no AI — one-suit) |

- [ ] Gomoku verified + committed · - [ ] SeaBattle · - [ ] Crazy8 · - [ ] Spider

## Task 2: Merge + registration (orchestrator — after Task 1)

**Files:** Modify `macos/Sources/Model/FacetRegistry.swift`, `macos/Sources/App/ContentView.swift`

- [ ] **Step 1:** `cd ~/Desktop/Kaleidoscope && git pull --rebase` then per game: `git merge --no-ff spark/<g>-macos -m "Merge spark/<g>-macos: <Game> port"` (adds-only; on conflict STOP and inspect).
- [ ] **Step 2:** Append to `FacetRegistry.all` (before the closing `]`):

```swift
        FacetDescriptor(id: "gomoku",
                        title: "Gomoku",
                        systemImage: "circle.grid.3x3",
                        accent: Color(red: 0.72, green: 0.55, blue: 0.30),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "sea-battle",
                        title: "Sea Battle",
                        systemImage: "lifepreserver",
                        accent: Color(red: 0.22, green: 0.47, blue: 0.66),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "crazy-8",
                        title: "Crazy 8",
                        systemImage: "suit.club",
                        accent: Color(red: 0.60, green: 0.28, blue: 0.55),
                        category: .cards,
                        status: .ready),
        FacetDescriptor(id: "spider",
                        title: "Spider",
                        systemImage: "suit.spade",
                        accent: Color(red: 0.25, green: 0.42, blue: 0.30),
                        category: .cards,
                        status: .ready),
```

- [ ] **Step 3:** `ContentView.swift` — four additions in each block, matching existing style exactly:
  - `@StateObject` block (~line 21, after `checkersSession`):
    ```swift
    @StateObject private var gomokuSession = GomokuSession()
    @StateObject private var seaBattleSession = SeaBattleSession()
    @StateObject private var crazyEightSession = CrazyEightSession()
    @StateObject private var spiderSession = SpiderSession()
    ```
  - Route switch (~line 213, after `case "solitaire"`):
    ```swift
    case "gomoku": GomokuView(session: gomokuSession)
    case "sea-battle": SeaBattleView(session: seaBattleSession)
    case "crazy-8": CrazyEightView(session: crazyEightSession)
    case "spider": SpiderView(session: spiderSession)
    ```
  - `bootstrapPersistence()` (~line 506): four `<x>Session.configurePersistence(windowSessionID: windowSessionID)` lines.
  - `saveSession(for:)` switch: `case "gomoku": gomokuSession.saveNow()` (+3 more); mirror the same four cases in `reloadSession(for:)`.
  (If a Session type ended up without one of these methods, match what the spark actually built — read the Session file first, adapt the call sites, never the frozen pattern.)
- [ ] **Step 4:** Build: same command as Task 0 Step 5 (macOS). Expected `BUILD SUCCEEDED`. Then run model tests if the host cooperates: `xcodebuild test -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -derivedDataPath ~/Library/Caches/PrismetPass-mac CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5` (known test-host hang → fall back to build-green + committed test files).
- [ ] **Step 5:** `./scripts/deploy-mac.sh`, click through all four new facets: play a move, quit, relaunch, verify save/reload.
- [ ] **Step 6:** Commit `git add macos/Sources/Model/FacetRegistry.swift macos/Sources/App/ContentView.swift && git commit -m "macOS: register Gomoku/SeaBattle/Crazy8/Spider facets + session wiring" && git push`. Update `ios/docs/MAC-IOS-GAME-PARITY.md` rows (4 games → mirrored; online-friend = tracked Codex handoff) and tick `docs/RELEASE-GATES.md` §E port lines; commit docs.
- [ ] **Step 7:** Remove spark worktrees + branches: `for g in gomoku seabattle crazy8 spider; do git worktree remove --force ~/Desktop/kscope-spark-$g; git branch -d spark/$g-macos; done`

## Task 3: Leaderboard verify + fix (codex agent #2; starts right after Task 0)

**Files:** Agent-A's 7 modified iOS files + both ledger files (all listed in Task 0 Step 2)

Launch: `cd ~/Desktop/Kaleidoscope && codex exec --full-auto "<PROMPT>"` with:

```
Verify and fix the uncommitted iOS leaderboard-identity work in this repo (7 modified files —
git status shows them; docs/AGENT-COORDINATION.md diff hunks describe intent). Lane: those 7 files
ONLY plus the two AGENT-COORDINATION.md ledger hunks. Do NOT touch macos/, project.yml, or other
agents' files. Steps: (1) cd ios && xcodegen generate && build for iOS Simulator with derived data
~/Library/Caches/PrismetPass-leaderboard; fix the known Postgrest API drift in LeaderboardStore.swift
(supabase-swift query builder signatures) until BUILD SUCCEEDED. (2) Run the full iOS test suite on
an iPhone simulator; all green (fix regressions inside your lane only). (3) Commit the 7 files + both
ledger files: git commit -m "iOS: leaderboard identity hardening (gc_account_id canonical) — verified
suite green [Agent-A handoff]". Do NOT push. Report: what you changed, test counts, anything deferred.
```

- [ ] Launched · - [ ] Suite green · - [ ] Committed (unblocks ledger commits for everyone)

## Task 4: Material mirrors (sonnet agents #1–4; start right after Task 0, own worktrees)

Orchestrator creates 4 worktrees off current main FIRST (targets don't overlap spark files):

```bash
cd ~/Desktop/Kaleidoscope
for m in 2048 checkers solitaire brickbench; do git worktree add -b mirror/$m-macos ~/Desktop/kscope-mirror-$m main; done
```

Dispatch each sonnet with this prompt (fill per row):

```
You are mirroring an iOS v10/v11 material-identity redesign to macOS in the git worktree
~/Desktop/kscope-mirror-<m> (branch mirror/<m>-macos), Kaleidoscope monorepo. Read AGENTS.md.
HARD LANE RULE: edit ONLY <target file(s)>. Never touch FacetRegistry/ContentView/GamePersistence/
project.yml/ledgers/ios/. Reference implementation: <iOS reference> — match its material identity
(colors, textures, chrome) in desktop idiom; keep ALL existing macOS functionality and session API
calls intact; extract subviews early if the type-checker slows. Verify: cd macos && xcodegen generate
&& xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS'
-derivedDataPath ~/Library/Caches/PrismetMirror-<m> CODE_SIGNING_ALLOWED=NO build → BUILD SUCCEEDED.
Commit only your file(s): git commit -m "macOS: mirror <identity> (v10/v11 parity)". No push/merge.
Report: what changed visually, build status.
```

| Agent | Mirror | Target file | iOS reference |
|---|---|---|---|
| sonnet-1 | Walnut 2048 tray | `macos/Sources/Views/Game2048View.swift` | `ios/Sources/Features/Games/Game2048View.swift` |
| sonnet-2 | Club Checkers board | `macos/Sources/Views/CheckersView.swift` | `ios/Sources/Features/Games/CheckersView.swift` |
| sonnet-3 | Solitaire baize + real card faces | `macos/Sources/Views/SolitaireView.swift` | `ios/Sources/Features/Games/SolitaireView.swift` |
| sonnet-4 | Brick Bench workshop chrome (not the 3D scene) | `macos/Sources/Views/LegoBuilderView.swift` | `ios/Sources/Features/Games/BrickBenchView.swift` |

- [ ] Worktrees created · - [ ] 4 sonnets dispatched · - [ ] Each: build green + committed
- [ ] Orchestrator merges each finished branch (`git merge --no-ff mirror/<m>-macos`), rebuilds, pushes, updates parity matrix row, removes worktree+branch.

## Task 5: Chess plaques + Oracle ledger card + skin pickers (opus agent #2; parallel)

Worktree: `git worktree add -b mirror/chess-oracle ~/Desktop/kscope-mirror-chessoracle main`. Same prompt skeleton as Task 4 with lane = chess view files under `macos/Sources/Views/` (`Board2DView.swift`, chess chrome in `ContentView`'s `chessDetail` is ORCHESTRATOR-owned — if plaques require ContentView edits, report for orchestrator instead), `macos/Sources/Views/DecreeView.swift`, plus per-game skin pickers ONLY where the iOS counterpart has one (check `ios/Sources/Features/Games/*View.swift` for skin-picker controls; mirror into the same macOS game view file). iOS references: `ios/Sources/Features/Games/ChessView.swift`, `ios/Sources/Features/Games/OracleView.swift`.

- [ ] Dispatched · - [ ] Build green + committed · - [ ] Merged + pushed + matrix updated

## Task 6: iPad sweep (opus agent #1; audit parallel, fixes after Task 3 commit)

- [ ] **Step 1 (audit, read-only):** Build for iPad sim and screenshot-audit:

```bash
cd ~/Desktop/Kaleidoscope/ios && xcodegen generate
xcrun simctl list devices available | grep -i ipad   # pick largest iPad
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=<iPad name>' -derivedDataPath ~/Library/Caches/PrismetPass-ipad CODE_SIGNING_ALLOWED=NO build
```
Boot sim, install, launch (`xcrun simctl install/launch`), screenshot (`xcrun simctl io booted screenshot`) Home, one game per family (Chess, Solitaire, 2048), Debt Clock + Moguls board, Steam Rewind. Produce a fix list: file → symptom → proposed fix. No edits yet.
- [ ] **Step 2 (fixes):** After Task 3's commit lands (HomeView is in Agent-A's set), apply fixes on main directly — iPad fixes may touch iOS view files broadly; coordinate with orchestrator for anything also touched by Tasks 4/5 (macOS-only — no overlap expected). Every fix logs a parity decision (mirrored / n-a / tracked) in the commit message.
- [ ] **Step 3:** Full iOS suite still green; commit per fix cluster; push.

## Task 7: macOS Home tile art + regroup (orchestrator — after Tasks 2/4/5 merged)

**Files:** `macos/Sources/Model/FacetRegistry.swift`, `macos/Sources/Views/HomeLensView.swift`, `macos/Sources/Resources/Assets.xcassets/`

- [ ] **Step 1:** Copy all 22 iOS tile imagesets: `rsync -a ~/Desktop/Kaleidoscope/ios/Sources/Resources/Assets.xcassets/tile_*.imageset ~/Desktop/Kaleidoscope/macos/Sources/Resources/Assets.xcassets/` (verify source path first with `find ios -name "tile_2048.imageset"` — adjust if assets live elsewhere).
- [ ] **Step 2:** `FacetDescriptor` gains `var tileImage: String? = nil`; fill per facet using the no-hyphen names: `"tile_2048"`, `"tile_gomoku"`, `"tile_seabattle"`, `"tile_crazyeight"`, `"tile_spider"`, `"tile_chess"`, `"tile_checkers"`, `"tile_solitaire"`, `"tile_brickbench"`, `"tile_oracle"`, `"tile_debtclock"`, `"tile_steamrewind"`, `"tile_wordle"`, `"tile_snake"`, `"tile_minesweeper"`, `"tile_sudoku"`, `"tile_rubiks"`, `"tile_lightsout"`, `"tile_sliding"`, `"tile_nonogram"`, `"tile_reversi"`, `"tile_connectfour"` (map by game, not by facet-id string).
- [ ] **Step 3:** `HomeLensView.swift` (~line 98): render the art when present, fall back to the glyph:

```swift
if let tile = facet.tileImage {
    Image(tile)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
} else {
    Image(systemName: facet.systemImage)
}
```
(Adapt frame/clip to the existing tile cell metrics in that file — read the surrounding layout first.)
- [ ] **Step 4:** Regroup to match iOS `categoryOrder` (Daily, Puzzles, Board, Cards, Workshop, Lenses): in `FacetCategory` add `case workshop = "Workshop"`, rename `case oracle = "Oracle"` → `case lenses = "Lenses"`; reassign `brick-bench → .workshop`; `oracle`, `debt-clock`, `steam-rewind` → `.lenses`; declare `CaseIterable` order daily, puzzles, board, cards, workshop, lenses. Raw values are display-only (verify no persistence reads `FacetCategory.rawValue` — `grep -rn "FacetCategory" macos/Sources | grep -v FacetRegistry.swift`).
- [ ] **Step 5:** Build + visual check (`./scripts/deploy-mac.sh`) → commit `"macOS Home: full-color tile art + category regroup (iOS parity)"` → push → tick RELEASE-GATES §E tile/regroup lines + matrix rows.

## Task 8: Rename Kaleidoscope → Prismet (orchestrator + opus #2; quiet tree required)

**Preconditions:** Tasks 1–7 merged/committed; `git status` clean; all agents idle; Xcode closed.

- [ ] **Step 1: Working-tree renames** (one commit with everything below):

```bash
cd ~/Desktop/Kaleidoscope
git mv shared/KaleidoscopeShared shared/PrismetShared
git mv shared/PrismetShared/Sources/KaleidoscopeShared shared/PrismetShared/Sources/PrismetShared
git mv shared/PrismetShared/Tests/KaleidoscopeSharedTests shared/PrismetShared/Tests/PrismetSharedTests
git mv ios/Kaleidoscope.entitlements ios/Prismet.entitlements   # verify actual path first: find ios -name "*.entitlements"
```

- [ ] **Step 2: Symbol map** (Swift sources; whole-word, per-symbol — NOT blind `sed` over everything):

| Old | New |
|---|---|
| `KaleidoscopeApp` | `PrismetApp` (+ rename the two App files) |
| `KaleidoDesign` / `KaleidoPaper` | `PrismetDesign` / `PrismetPaper` |
| `KaleidoscopeShared` (module/product/package) | `PrismetShared` |
| `KaleidoscopeFeature*` (Manifest/ID/Category/…) | `PrismetFeature*` |
| `KaleidoscopeLeaderboard*` (Service/Period/Metric) | `PrismetLeaderboard*` |
| `KaleidoscopeAdMobBannerUnitID` / `KaleidoscopeAdUnlockCodeHashes` / `KaleidoscopeRemoveAdsProductID` | `PrismetAdMobBannerUnitID` / `PrismetAdUnlockCodeHashes` / `PrismetRemoveAdsProductID` (code + project.yml key names in the SAME commit; the IAP id VALUE `com.spocksclub.kaleidoscope.removeads` is FROZEN) |
| lowercase design tokens (`kaleidoCard` etc. — inventory with `grep -rhoE "\bkaleido[A-Za-z]+" --include='*.swift' ios macos shared \| sort -u`) | `prismet*` equivalents |

Execution: `grep -rl '<Old>' --include='*.swift' ios macos shared | xargs sed -i '' 's/\b<Old>\b/<New>/g'` per symbol, in the table's order (longest-first prevents partial hits).

- [ ] **Step 3: project.yml (both)** — `name: Prismet`; `PRODUCT_NAME: Prismet`; iOS `CFBundleDisplayName: Prismet` (line 49); macOS `INFOPLIST_KEY_CFBundleDisplayName: "Prismet"` (line 57); package path `../shared/PrismetShared` + package/product refs; target names `Kaleidoscope:`→`Prismet:`, `KaleidoscopeTests:`→`PrismetTests:`; entitlements path; user-facing strings (e.g. `NSGKFriendListUsageDescription`) reworded to Prismet. **FROZEN: both bundle ids, team ids, IAP product id value.**
- [ ] **Step 4: Scripts + docs.** `macos/scripts/deploy-mac.sh` (`PROJECT_NAME="Prismet"`; BUNDLE_ID stays); `ios/scripts/check-mac-ios-parity.sh` + `scripts/*` (scheme/project name refs); living docs (README, AGENTS.md, CLAUDE.md, docs/HANDOFF.md, docs/RELEASE-GATES.md, ios/docs/MAC-IOS-GAME-PARITY.md + setup docs) — Kaleidoscope→Prismet except: ledger history entries (verbatim), bundle/IAP ids, ASC record names, historical commit references.
- [ ] **Step 5: FROZEN list — verify untouched** after Steps 1–4: `GamePersistence.defaultRootURL`'s `"Kaleidoscope"` (+ `"ChessHotSwap"`) directory strings; both bundle ids; IAP value; Supabase refs; gist id; facet/card/tile id strings; `Secrets.swift`. Gate: `grep -rn "kaleidoscope\|Kaleidoscope\|Kaleido" ios macos shared scripts --include='*.swift' --include='*.yml' --include='*.sh' | grep -vE "com\.(spocksclub|gtrktscrb)\.kaleidoscope|removeads|ChessHotSwap|appendingPathComponent\(\"Kaleidoscope\"" ` → expect empty; every survivor is either allowlisted here or a bug.
- [ ] **Step 6: Rebuild both platforms** (xcodegen generate first — project files become `Prismet.xcodeproj`); macOS model tests; iOS full suite. All green.
- [ ] **Step 7: Commit** `"Rename Kaleidoscope → Prismet (user-facing + internal; bundle ids, store identities, save paths frozen)"` + push.
- [ ] **Step 8: External repoints:**

```bash
gh api -X PATCH repos/sagedeutschle/kaleidoscope -f name=prismet    # old URLs redirect
cd ~/Desktop && mv Kaleidoscope Prismet && cd Prismet && git remote set-url origin git@github.com:sagedeutschle/prismet.git
sed -i '' 's|Desktop/Kaleidoscope|Desktop/Prismet|g' ~/Library/LaunchAgents/com.gtrktscrb.wkd.daily.plist
launchctl unload ~/Library/LaunchAgents/com.gtrktscrb.wkd.daily.plist && launchctl load ~/Library/LaunchAgents/com.gtrktscrb.wkd.daily.plist
grep -rn "Desktop/Kaleidoscope" ~/Desktop/Prismet/scripts ~/Desktop/Prismet/oracle ~/Desktop/Prismet/docs | head   # sweep leftovers
rm -rf ~/Applications/Kaleidoscope.app    # replaced by Prismet.app at next deploy
```

## Task 9: Build 13 (orchestrator)

- [ ] `ios/project.yml`: `CURRENT_PROJECT_VERSION: "13"` (line ~84). `macos/project.yml`: `CURRENT_PROJECT_VERSION: "13"` (line ~55).
- [ ] `cd ios && xcodegen generate && <sim build>`; `cd macos && xcodegen generate && <build>`; `ios/scripts/check-mac-ios-parity.sh --strict` → PASS.
- [ ] Commit `"Build 13: iOS 12→13, macOS 11→13 (aligned) — Prismet v13"` + push.

## Task 10: Deploys (codex agent #3)

- [ ] **macOS:** `cd ~/Desktop/Prismet/macos && ./scripts/deploy-mac.sh` → `~/Applications/Prismet.app` launches; new games + tile Home + "Prismet" in menu bar.
- [ ] **iPhone (Poopoohead):** xcodebuild device build with hardware UDID `00008120-001278982192201E`, install/launch via `xcrun devicectl device install app --device B2081DF4-7D29-5F35-8CC4-18227227036B <path>.app` (codex CLI path per AGENTS.md; home screen shows **Prismet**, build 13 in Settings→About).
- [ ] **iPad Air:** same flow, hardware UDID `00008122-001E79A20EB9801C`, CoreDevice `F4E0AAC6-BAAC-5213-A50D-EB233908A105`. If unplugged/asleep → log open item, notify Sage.

## Task 11: QA close (orchestrator + codex #3)

- [ ] Clean-install on one device (delete app first): Oracle consult non-empty; Moguls board renders on Debt Clock lens.
- [ ] Online head-to-head smoke iPhone↔iPad (any online game; RELEASE-GATES §F).
- [ ] macOS: play one round in each of the 4 new games; save/reload OK.

## Task 12: Docs, ledger, shared folders, memory (orchestrator)

- [ ] `docs/HANDOFF.md` rewritten to v13 current state (Prismet name, build 13, parity closed, remaining gates: App Store fork, ads/IAP, macOS online-friend). `docs/RELEASE-GATES.md`: tick §E complete, §F device-verification lines done/updated. Parity matrix final rows.
- [ ] Ledger: flip Task-0 claim to `PRISM: RELEASE` with build/test/deploy status; push all.
- [ ] `~/Desktop/GtrktscrB/PRISMCODE-PRISMET-NIGHTSHIFT-2026-07-04.md` §Run log entry (this pass: what shipped, the iCloud-eviction incident + recovery, disk cleanup ~120GB, blockers).
- [ ] **NAS (needs `/Volumes/homes` remounted — Sage):** `cd /Volumes/homes/PrismetSharedFolder/Kaleidoscope && git remote set-url origin git@github.com:sagedeutschle/prismet.git && git pull --rebase && cd .. && mv Kaleidoscope Prismet`; update `README-RENAMED-2026-07-04.txt` noting repo+app now renamed too. If still unmounted → open item.
- [ ] Memory files: locations map (Desktop/Prismet canonical, NAS mirror), v13 state, rename freeze list, iCloud-on-Desktop hazard + hydration playbook, agent-budget outcome.

## Sequencing summary

```
Task 0 (gate) → {Task 1, Task 3, Task 4, Task 5, Task 6-audit} in parallel
Task 1 → Task 2.  {Task 2, 4, 5} → Task 7.  Task 3 → Task 6-fixes.
ALL of 2–7 → Task 8 (rename) → Task 9 → Task 10 → Task 11 → Task 12.
```
