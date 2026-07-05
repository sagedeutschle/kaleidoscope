# V13 Pass — Cold-Start Agent Handoff

**Written:** 2026-07-05 ~00:05 EDT by Agent-Design/Fable (Sage, prismet org), the pass orchestrator,
who is STILL ACTIVE in another session. This doc lets a new agent join the pass in parallel
without colliding. Read fully before touching anything.

## 1. What is happening tonight

One consolidated pass ("Prismet v13") over the Kaleidoscope monorepo:
land the 4 uncommitted macOS game ports (Gomoku, Sea Battle, Crazy 8, Spider) → material-identity
mirrors → macOS Home tile art + regroup → iPad sweep → fix + fold in Agent-A's iOS leaderboard
work → **rename Kaleidoscope→Prismet everywhere** (bundle ids/store identities/save paths FROZEN)
→ bump **both platforms to build 13** → dev-deploy to macOS + iPhone "Poopoohead" + iPad Air →
update all docs + git + NAS.

- **Spec (Sage-approved):** `docs/superpowers/specs/2026-07-04-prismet-v13-consolidation-design.md`
- **Plan (source of truth for tasks/sequencing):** `docs/superpowers/plans/2026-07-04-prismet-v13-consolidation.md`
- Sequencing: `Task 0 gate → {1,3,4,5,6-audit} parallel → 2 → 7 → 8 (rename) → 9 → 10 → 11 → 12`

## 2. ⚠️ Machine state — read before ANY build or git command

Tonight the Mac hit critical disk pressure (16 GiB free) and macOS **mass-evicted iCloud-synced
Desktop files to dataless placeholders** — including source files in this repo and the spark
worktrees. Recovery is done but hydration of the full tree is still in flight:

- Disk is fixed (285 GiB free; ~120 GB of stale `Kaleidoscope-*` derived-data caches were deleted;
  TM snapshots thinned). iCloud daemons were restarted; hydration works again.
- All 26 unique-content files (uncommitted work) are hydrated AND backed up at
  `/private/tmp/claude-501/-Volumes-homes-PrismetSharedFolder/ad427b48-c5bd-4885-a57f-fa5ea984337c/scratchpad/rescue/tree/`.
- A full-tree `brctl download` sweep is queued; a watcher polls until 0 dataless files remain.

**HARD RULES until the gate passes:**
1. Never start an `xcodebuild` while dataless files remain — it HANGS (doesn't fail). Gate check:
   ```bash
   find ~/Desktop/Kaleidoscope ~/Desktop/kscope-spark-{gomoku,seabattle,crazy8,spider} -type f -print0 2>/dev/null \
     | xargs -0 ls -lOd 2>/dev/null | awk '$5 ~ /dataless/' | wc -l    # must be 0
   ```
2. If a git command times out, it may leave a stale `.git/index.lock` (0 bytes). Verify no live git
   process owns it (`ps aux | grep git`) before removing.
3. `cat`/`grep`/`git show` can block on dataless content — queue `brctl download <file>` and wait
   instead of retrying blindly.
4. The NAS share `/Volumes/homes` is UNMOUNTED (Sage must remount). Do nothing NAS-related.
5. Don't open Xcode on this repo tonight (its git polling wedges during hydration).

## 3. Repo state snapshot (as of writing)

- Canonical clone: `~/Desktop/Kaleidoscope`, branch `main` at `98677c9`
  (`Spec: prismet v13 consolidation…`). origin/main is at `a4d0fc8` — 2 commits unpushed
  (push happens in the orchestrator's Task 0).
- **Uncommitted, do not clobber:**
  - Agent-A's 7 iOS leaderboard files + 2 ledger files (fix lane = plan Task 3, codex).
  - Plan file `docs/superpowers/plans/2026-07-04-prismet-v13-consolidation.md` +
    handoff (this file) — orchestrator commits them in Task 0.
- 4 spark worktrees `~/Desktop/kscope-spark-{gomoku,seabattle,crazy8,spider}` (branches
  `spark/<g>-macos` at `a4d0fc8`): port files present, uncommitted, never built (Task 1 lane).
- Versions: iOS build 12, macOS build 11 → both go to **13** in Task 9 (orchestrator only).
- macOS app installed at 13a9098-ish; iPhone deploy state unknown; iPad Air possibly unplugged.

## 4. Lane map — what you may and may not take

**ORCHESTRATOR-ONLY (Fable, active now — NEVER touch):**
`macos/Sources/Model/FacetRegistry.swift` · `macos/Sources/App/ContentView.swift` ·
`macos/Sources/Model/GamePersistence.swift` · both `project.yml` · both `AGENT-COORDINATION.md`
ledgers (append-only claims OK, nothing else) · `ios/docs/MAC-IOS-GAME-PARITY.md` ·
ALL merges to main · the Task 8 rename · Task 9 version bump · Tasks 10–12.

**OPEN LANES a new agent can claim** (in priority order — claim in the ledger first, see §5):

| Lane | Plan task | Model fit | Files | Collision risk |
|---|---|---|---|---|
| Spark-port verify+commit | Task 1 | codex (or any) | ONLY `<Game>{Game,AI,Session}.swift`, `<Game>View.swift`, `<Game>GameTests.swift` inside ONE worktree | none (isolated worktrees) |
| Leaderboard verify+fix | Task 3 | codex/backend | Agent-A's 7 iOS files + both ledger hunks | none if you claim it whole |
| Material mirror ×4 | Task 4 | sonnet/design | ONE view file per worktree (`Game2048View` / `CheckersView` / `SolitaireView` / `LegoBuilderView`), branch `mirror/<m>-macos` | none (disjoint) |
| Chess/Oracle mirrors | Task 5 | opus/design | chess views + `DecreeView.swift` in own worktree; if plaques need ContentView → REPORT, don't edit | low |
| iPad audit (read-only) | Task 6 step 1 | opus | none (screenshots + fix list only) | zero |

Each plan task embeds the full prompt/recipe — execute exactly as written there, including the
per-task build command with its OWN derived-data path under `~/Library/Caches/`.

**Do not start:** anything in Tasks 2/7/8/9/10/11/12 (orchestrator), or new scope not in the plan.

## 5. Coordination protocol (PRISM — mandatory)

1. `git pull --rebase` before starting (if it hangs, see §2).
2. Grep live claims: `grep -rn "PRISM:" docs/ ios/docs/ | tail -20` — respect them.
3. Append your claim to `docs/AGENT-COORDINATION.md` (newest-first):
   `PRISM: CLAIM <your-name> 2026-07-05 (<lane>) — files: <exact list>. Part of the v13 pass, plan Task <n>.`
   Working-tree visibility = live claim; the orchestrator commits ledger hunks with Task 3.
4. Small commits, ONLY your lane files, message style per the plan. **Do NOT push** from worktree
   lanes (orchestrator merges + pushes). Task 3 commits but doesn't push.
5. When done, flip your claim to `PRISM: RELEASE …` with build/test status, and note anything
   stripped or deferred.

## 6. Build rules (hard-won — violations cost debugging sessions)

- Derived data under `~/Library/Caches/<unique-name>` ONLY. Never inside the project. Never NAS.
- `xcodegen generate` after every pull/merge (`.xcodeproj` is generated + gitignored).
- Never hand-edit `Info.plist` / never `INFOPLIST_KEY_*` additions — keys go in `project.yml`.
- Archives: `SWIFT_COMPILATION_MODE=incremental` (whole-module crashes swift-frontend).
- macOS `xcodebuild test` can hang at the test host — green build + committed test files is the
  accepted fallback; orchestrator runs suites post-merge.
- Big SwiftUI view bodies: extract subviews early (type-checker timeouts are a known gotcha).
- Never run `/login` under any CLI profile (shared keychain — flips ALL accounts).

## 7. Frozen identities (violating any of these = revert on sight)

Bundle ids `com.spocksclub.kaleidoscope` / `com.gtrktscrb.kaleidoscope` · IAP value
`com.spocksclub.kaleidoscope.removeads` · ASC record `6785993194` · Supabase project ref ·
Oracle gist id · facet/card/tile `id` strings · `GamePersistence` storage dir strings
(`"Kaleidoscope"`, `"ChessHotSwap"`) · `ios/Sources/Backend/Secrets.swift` (gitignored) ·
append-only ledger history. The Kaleidoscope→Prismet rename (Task 8) is ORCHESTRATOR-ONLY.

## 8. Quick reference

| Thing | Value |
|---|---|
| Repo | `~/Desktop/Kaleidoscope` (GitHub `sagedeutschle/kaleidoscope`; renamed to `prismet` in Task 8) |
| Scratchpad rescue/backups | `/private/tmp/claude-501/-Volumes-homes-PrismetSharedFolder/ad427b48-c5bd-4885-a57f-fa5ea984337c/scratchpad/` (`rescue/tree/`, `repo/` = origin tarball) |
| iPhone 15 Plus "Poopoohead" | hw UDID `00008120-001278982192201E` · CoreDevice `B2081DF4-7D29-5F35-8CC4-18227227036B` |
| iPad Air 13" M3 | hw UDID `00008122-001E79A20EB9801C` · CoreDevice `F4E0AAC6-BAAC-5213-A50D-EB233908A105` |
| codex CLI | `/Applications/Codex.app/Contents/Resources/codex exec --full-auto "<prompt>"` |
| Night-shift portfolio doc | `~/Desktop/GtrktscrB/PRISMCODE-PRISMET-NIGHTSHIFT-2026-07-04.md` (§Run log — append results) |
| Kaleidoscope→Prismet rename scope | spec §Rename; freeze list above |

## 9. How to sync with the orchestrator

- The orchestrator re-checks the ledger and worktree branches between its tasks; your committed
  worktree branch + RELEASE ledger entry is the handback signal — no other channel needed.
- If you hit something outside your lane (a hotspot edit you need, a frozen-identity problem, a
  machine-level failure), STOP, log it in your ledger entry, and leave the work uncommitted.
- Progress signals you can read: `git -C ~/Desktop/Kaleidoscope log --oneline -10` (orchestrator
  commits land here), plan checkboxes (orchestrator ticks them as tasks land), and the §Run log.
