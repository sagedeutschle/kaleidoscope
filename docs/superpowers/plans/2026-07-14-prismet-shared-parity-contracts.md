# Prismet Shared Parity Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a Foundation-only shared contract layer for Prismet's canonical feature inventory, platform capabilities, launch modes, player identity domains, and opaque save envelopes without changing any existing app save bytes or claimed UI files.

**Architecture:** This first Workstream 1 plan establishes the `PrismetShared` contract of record for game/lens IDs, observed presentation and capability status, launch modes, identity domains, and save-envelope metadata while the apps remain unchanged consumers. A follow-on service plan makes that contract authoritative in production by adding account/profile/leaderboard/online/ads/feedback parity surfaces, fakes, platform adapters, and app/parity-gate enforcement. Identity types keep local guest, backend account, and team-scoped Game Center identities distinct. Save envelopes wrap opaque bytes; they do not reinterpret platform payloads.

**Tech Stack:** Swift 5.9, Foundation, Swift Package Manager, XCTest, XcodeGen, Xcode 26 command-line builds.

## Global Constraints

- Work from an isolated git worktree. Do not modify the dirty owner checkout.
- Preserve the active Catan, Illuminated Cabinet facelift, and online-catalog lanes. This plan owns only the files explicitly listed below plus one append-only coordination claim.
- The Long Now repository is read-only reference material for this program.
- Do not import SwiftUI, UIKit, AppKit, GameKit, Supabase, or CryptoKit into `PrismetShared`.
- Do not rename existing iOS IDs, macOS IDs, save directories, cloud columns, leaderboard IDs, or payload schemas.
- Do not make the apps import the new contracts in this slice. App adapters receive their own plan after upstream online work is reconciled.
- A catalog entry describes current behavior. Missing Mac cloud save, online friend play, or Catan must remain visible as tracked debt rather than being labeled complete.
- Do not describe Workstream 1 as complete after this plan. Account/profile, cloud transport, leaderboard transport, online matches, ads/consent, haptics, and touch-only dispositions remain required entries in the immediately following service-contract plan.
- Stage and commit only owned files. Never stage `.legion/`, the untracked facelift specification, or unrelated coordination edits from the owner checkout.

## Owned Files

- `shared/PrismetShared/Sources/PrismetShared/PrismetFeatureManifest.swift`
- `shared/PrismetShared/Sources/PrismetShared/PrismetGameModeContracts.swift`
- `shared/PrismetShared/Sources/PrismetShared/PrismetIdentityContracts.swift`
- `shared/PrismetShared/Sources/PrismetShared/PrismetSaveEnvelope.swift`
- `shared/PrismetShared/Tests/PrismetSharedTests/PrismetFeatureManifestTests.swift`
- `shared/PrismetShared/Tests/PrismetSharedTests/PrismetGameModeContractsTests.swift`
- `shared/PrismetShared/Tests/PrismetSharedTests/PrismetIdentityContractsTests.swift`
- `shared/PrismetShared/Tests/PrismetSharedTests/PrismetSaveEnvelopeTests.swift`
- `shared/PrismetShared/README.md`
- `docs/AGENT-COORDINATION.md` (append-only claim and release note)

## Contract Decisions

### Canonical inventory

The catalog contains exactly these 23 current Home surfaces. `legacyID` means the identifier already used by that platform and is not a migration target.

| Canonical ID | Title | Category | iOS legacy ID | macOS legacy ID |
| --- | --- | --- | --- | --- |
| `2048` | 2048 | Puzzles | `2048` | `2048` |
| `snake` | Snake | Puzzles | `snake` | `snake` |
| `minesweeper` | Minesweeper | Puzzles | `minesweeper` | `minesweeper` |
| `sudoku` | Sudoku | Puzzles | `sudoku` | `sudoku` |
| `rubiks-cube` | Rubik's Cube | Puzzles | `rubiks` | `rubiks-cube` |
| `lights-out` | Lights Out | Puzzles | `lightsout` | `lights-out` |
| `sliding-puzzle` | Sliding Puzzle | Puzzles | `sliding` | `sliding-15` |
| `nonogram` | Nonogram | Puzzles | `nonogram` | `nonogram` |
| `wordgame` | Wordgame | Daily | `wordle` | `wordle` |
| `chess` | Chess | Board | `chess` | `chess` |
| `reversi` | Reversi | Board | `reversi` | `reversi` |
| `checkers` | Checkers | Board | `checkers` | `checkers` |
| `connect-four` | Connect Four | Board | `connectfour` | `connect-four` |
| `gomoku` | Gomoku | Board | `gomoku` | `gomoku` |
| `sea-battle` | Sea Battle | Board | `seabattle` | `sea-battle` |
| `catan` | Catan | Board | `catan` | none until the Catan lane lands |
| `solitaire` | Solitaire | Cards | `solitaire` | `solitaire` |
| `spider` | Spider | Cards | `spider` | `spider` |
| `crazy-eight` | Crazy 8 | Cards | `crazyeight` | `crazy-8` |
| `brick-bench` | Brick Bench | Workshop | `brickbench` | `brick-bench` |
| `oracle` | Oracle | Lenses | `oracle` | `oracle` |
| `debt-clock` | Debt Clock | Lenses | `debtclock` | `debt-clock` |
| `steam-rewind` | Steam Rewind | Lenses | `steamrewind` | `steam-rewind` |

Category order is exactly `Daily`, `Puzzles`, `Board`, `Cards`, `Workshop`, `Lenses`.

### Modes and capabilities

Keep the existing iOS raw mode values: `soloBot`, `localTwoPlayer`, and `onlineFriend`. A launch context adds only `home` or `parlor`; it never changes the canonical feature ID.

Current iOS mode support is:

- Solo: every game surface from `2048` through `catan`; lenses have no game mode.
- Local two-player: Chess, Reversi, Checkers, Connect Four, Gomoku, and Crazy 8.
- Online friend: Chess, Reversi, Checkers, Connect Four, Gomoku, Sea Battle, and Crazy 8.

Current Mac mode support is:

- Solo: 2048, Snake, Minesweeper, Sudoku, Rubik's Cube, Chess (bot route exposed by the current UI), Lights Out, Sliding Puzzle, Nonogram, Wordgame, Gomoku, Sea Battle, Solitaire, Spider, Crazy 8, and Brick Bench.
- Local two-player: Reversi, Checkers, Connect Four, Gomoku, and Crazy 8. Do not advertise local Chess merely because its internal model has a dormant `vsComputer = false` path; no current Mac UI exposes it.
- Online friend is absent for every Mac game in this slice.
- Catan has no playable Mac capability until its separate lane lands.
- Mac cloud-save capability is absent for every game until the adapter plan lands.
- Mac local-save capability exists for the 16 solo entries above plus Reversi, Checkers, and Connect Four. Oracle has a partial append-only archive, not a canonical game save, so it receives `.lens` rather than `.localSave`.

The shared capability vocabulary is additive and includes `soloPlay`, `localTwoPlayer`, `onlineFriend`, `localSave`, `cloudSave`, `leaderboard`, `lens`, `parlorTable`, and `ambientSpectator`. No current feature receives `parlorTable` or `ambientSpectator` yet.

Use this exact capability matrix. `Available` means the current UI and backing behavior are both reachable. `Mac debt` is capability-specific and must not change the presentation disposition. Abbreviations: `S` solo, `L` local two-player, `O` online friend, `LS` local save, `CS` cloud save, `LB` wired leaderboard surface, `X` lens.

| Canonical ID | iOS available | Mac available | Mac tracked debt |
| --- | --- | --- | --- |
| `2048` | S, LS, CS, LB | S, LS, LB | CS |
| `snake` | S, LS, CS, LB | S, LS, LB | CS |
| `minesweeper` | S, LS, CS | S, LS | CS |
| `sudoku` | S, LS, CS | S, LS | CS |
| `rubiks-cube` | S, LS, CS, LB | S, LS | CS, LB |
| `lights-out` | S, LS, CS, LB | S, LS | CS, LB |
| `sliding-puzzle` | S, LS, CS, LB | S, LS | CS, LB |
| `nonogram` | S, LS, CS | S, LS | CS |
| `wordgame` | S, LS, CS, LB | S, LS | CS, LB |
| `chess` | S, L, O, LS, CS | S, LS | L, O, CS |
| `reversi` | S, L, O, LS, CS | L, LS | S, O, CS |
| `checkers` | S, L, O, LS, CS, LB | L, LS, LB | S, O, CS |
| `connect-four` | S, L, O, LS, CS | L, LS, LB | S, O, CS |
| `gomoku` | S, L, O, LS, CS | S, L, LS | O, CS |
| `sea-battle` | S, O, LS, CS | S, LS | O, CS |
| `catan` | S, LS, CS | none | S, LS, CS |
| `solitaire` | S, LS, CS | S, LS, LB | CS |
| `spider` | S, LS, CS | S, LS | CS |
| `crazy-eight` | S, L, O, LS, CS | S, L, LS | O, CS |
| `brick-bench` | S, LS, CS | S, LS | CS |
| `oracle` | S, LS, CS, X | X | S, LS, CS |
| `debt-clock` | X | X | none |
| `steam-rewind` | X | X | none |

For iOS, mark each available capability `.mirrored`. For Mac, mark each available capability `.adapted`; mark every entry in `Mac tracked debt` `.trackedDebt`. Omitted capabilities are not part of that platform record. Use these exact debt rationales:

- every available Mac capability: `Native Mac implementation.`
- `cloudSave`: `Account-scoped cloud save is not wired on macOS.`
- `onlineFriend`: `Online friend play is not wired on macOS.`
- `leaderboard`: `The iOS leaderboard surface is not wired for this game on macOS.`
- missing `soloPlay`: `The iOS solo opponent mode has no Mac route.`
- missing `localTwoPlayer` for Chess: `The model supports local Chess internally, but no current Mac route exposes it.`
- Catan `soloPlay` and `localSave`: `The active Catan Mac lane has not released its playable route and persistence.`

Presentation status is separate: all currently present iOS surfaces are `.mirrored`; all currently present Mac surfaces are `.adapted` with rationale `Native Mac input and layout.`; Catan on Mac is `.trackedDebt` with rationale `The active Catan Mac lane has not released its route.`

### Identity and saves

- `localGuestID` is a device-local UUID.
- `backendAccountID` is the Supabase authentication UUID when available.
- Game Center identity is a tuple of `developerTeamID` and the app's derived UUID. It is not a universal cross-platform account key because the apps use different developer teams.
- A save storage scope is either `device` or `backendAccount`, with a UUID identifier.
- A save envelope has its own envelope version, a payload schema version, canonical feature ID, scope, slot ID, optional score, modification date, device mutation UUID, source platform, and opaque `Data` payload.
- The envelope codec uses sorted JSON keys and seconds-since-1970 dates. It never decodes or rewrites the opaque payload.

---

### Task 0: Create the isolated execution lane

**Files:**
- Modify: `docs/AGENT-COORDINATION.md` (append only in the new worktree)

- [ ] **Step 1: Confirm the owner checkout remains untouched**

Run from `/Users/gtrktscrb/Desktop/Kaleidoscope` with the bundled fallback git binary if `/usr/bin/git` is blocked by the Xcode license prompt:

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git rev-parse --absolute-git-dir
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git rev-parse --path-format=absolute --git-common-dir
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git rev-parse --show-superproject-working-tree
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git branch --show-current
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git status --short --branch
```

Expected: git directory and common directory are both `/Users/gtrktscrb/Desktop/Kaleidoscope/.git`, the superproject output is empty, and the branch is `claude/prismet-catan-research-l86o6j`; this confirms the owner checkout is not already a linked worktree. Unrelated dirty entries remain limited to the coordination ledger, `.legion/`, and the facelift specification.

- [ ] **Step 2: Fetch without changing the owner checkout**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git fetch origin claude/prismet-catan-research-l86o6j
```

Expected: `origin/claude/prismet-catan-research-l86o6j` is refreshed; no working files change.

- [ ] **Step 3: Create a feature worktree from the current local tip**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git check-ignore -q .worktrees
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git worktree add -b codex/prismet-shared-parity-contracts .worktrees/codex-prismet-shared-parity claude/prismet-catan-research-l86o6j
```

Expected: the ignore check passes; the new worktree at `/Users/gtrktscrb/Desktop/Kaleidoscope/.worktrees/codex-prismet-shared-parity` is clean on `codex/prismet-shared-parity-contracts` and includes this plan and the approved design.

- [ ] **Step 4: Reconcile the three upstream commits in the worktree**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git merge --no-edit origin/claude/prismet-catan-research-l86o6j
```

Expected: a clean merge or fast-forward. If a conflict touches Catan, active UI claims, or the incoming online catalog, abort the merge and reassess the base; this contract slice has no authority to choose either side of those files.

- [ ] **Step 5: Verify the clean shared-package baseline**

```bash
swift test --package-path shared/PrismetShared
```

Expected: the pre-change package suite passes. If it fails, preserve the full failure output and investigate the baseline before editing source; do not attribute a pre-existing failure to this lane.

- [ ] **Step 6: Re-read coordination after integration and append the claim**

Read both ledgers before editing:

```bash
sed -n '1,2600p' /Users/gtrktscrb/Desktop/Kaleidoscope/docs/AGENT-COORDINATION.md
sed -n '1,2600p' docs/AGENT-COORDINATION.md
```

The first command intentionally reads the owner's live dirty ledger so uncommitted active claims are not missed. Do not copy that file into the worktree and do not commit its unrelated changes. If either ledger claims an owned shared-package file, narrow this plan or wait for release before editing it.

Append this block, with the actual UTC timestamp, to the worktree's ledger:

```markdown
### PRISM — Shared Parity Contracts — <UTC timestamp>

- **Branch/worktree:** `codex/prismet-shared-parity-contracts` / `/Users/gtrktscrb/Desktop/Kaleidoscope/.worktrees/codex-prismet-shared-parity`
- **Status:** ACTIVE
- **Owns:** `shared/PrismetShared/Sources/PrismetShared/PrismetFeatureManifest.swift`, `PrismetGameModeContracts.swift`, `PrismetIdentityContracts.swift`, `PrismetSaveEnvelope.swift`; matching package tests; `shared/PrismetShared/README.md`
- **Excludes:** all iOS/macOS app source, Catan, Illuminated Cabinet facelift, online catalog/lobby, The Long Now
- **Verification:** focused and full SwiftPM tests, then no-sign iOS/macOS compile smokes
```

- [ ] **Step 7: Commit only the coordination claim**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add docs/AGENT-COORDINATION.md
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Claim Prismet shared parity contracts"
```

Expected: one append-only ledger commit.

---

### Task 1: Replace the stale manifest with the shared feature catalog

**Files:**
- Modify: `shared/PrismetShared/Sources/PrismetShared/PrismetFeatureManifest.swift`
- Modify: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetFeatureManifestTests.swift`

- [ ] **Step 1: Write failing catalog tests**

Replace the stale five-category and 17-feature assertions with tests that prove:

```swift
XCTAssertEqual(PrismetFeatureCategory.allCases.map(\.rawValue),
               ["Daily", "Puzzles", "Board", "Cards", "Workshop", "Lenses"])
XCTAssertEqual(PrismetFeatureID.allCases.count, 23)
XCTAssertEqual(PrismetFeatureCatalog.all.count, 23)
XCTAssertEqual(Set(PrismetFeatureCatalog.all.map(\.canonicalID)).count, 23)
XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .rubiksCube, platform: .iOS), "rubiks")
XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .rubiksCube, platform: .macOS), "rubiks-cube")
XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .slidingPuzzle, platform: .macOS), "sliding-15")
XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .crazyEight, platform: .macOS), "crazy-8")
XCTAssertNil(PrismetFeatureCatalog.platformID(for: .catan, platform: .macOS))
```

Add separate tests for unique non-nil platform IDs, every available/debt cell in the exact capability matrix, separation of presentation status from capability debt, and the invariant that every `.adapted`, `.notApplicable`, or `.trackedDebt` presentation/capability record has a non-empty rationale.

Verify the compatibility facade forwards the same array:

```swift
XCTAssertEqual(PrismetFeatureManifest.all, PrismetFeatureCatalog.all)
```

- [ ] **Step 2: Run the focused test and observe failure**

```bash
swift test --package-path shared/PrismetShared --filter PrismetFeatureManifestTests
```

Expected: compile/test failures for the new catalog API, six-category order, and 23-entry inventory.

- [ ] **Step 3: Implement the catalog types**

Use these public type shapes in `PrismetFeatureManifest.swift`:

```swift
public enum PrismetPlatform: String, CaseIterable, Codable, Hashable, Sendable {
    case iOS
    case macOS
}

public enum PrismetFeatureCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case daily = "Daily"
    case puzzles = "Puzzles"
    case board = "Board"
    case cards = "Cards"
    case workshop = "Workshop"
    case lenses = "Lenses"
}

public enum PrismetPlatformDisposition: String, Codable, Hashable, Sendable {
    case mirrored
    case adapted
    case notApplicable
    case trackedDebt
}

public enum PrismetFeatureCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case soloPlay
    case localTwoPlayer
    case onlineFriend
    case localSave
    case cloudSave
    case leaderboard
    case lens
    case parlorTable
    case ambientSpectator
}

public struct PrismetCapabilityStatus: Codable, Hashable, Sendable {
    public let capability: PrismetFeatureCapability
    public let disposition: PrismetPlatformDisposition
    public let rationale: String?

    public var isAvailable: Bool {
        disposition == .mirrored || disposition == .adapted
    }

    public init(
        capability: PrismetFeatureCapability,
        disposition: PrismetPlatformDisposition,
        rationale: String? = nil
    ) {
        precondition(
            disposition == .mirrored ||
            rationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
        self.capability = capability
        self.disposition = disposition
        self.rationale = rationale
    }
}

public struct PrismetPlatformSupport: Codable, Hashable, Sendable {
    public let platform: PrismetPlatform
    public let legacyID: String?
    public let presentationDisposition: PrismetPlatformDisposition
    public let presentationRationale: String?
    public let capabilityStatuses: [PrismetCapabilityStatus]

    public init(
        platform: PrismetPlatform,
        legacyID: String?,
        presentationDisposition: PrismetPlatformDisposition,
        presentationRationale: String? = nil,
        capabilityStatuses: [PrismetCapabilityStatus]
    ) {
        precondition(Set(capabilityStatuses.map(\.capability)).count == capabilityStatuses.count)
        precondition(
            presentationDisposition == .mirrored ||
            presentationRationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
        let presentationIsAvailable = presentationDisposition == .mirrored || presentationDisposition == .adapted
        precondition(!presentationIsAvailable || legacyID?.isEmpty == false)
        self.platform = platform
        self.legacyID = legacyID
        self.presentationDisposition = presentationDisposition
        self.presentationRationale = presentationRationale
        self.capabilityStatuses = capabilityStatuses
    }

    public var capabilities: Set<PrismetFeatureCapability> {
        Set(capabilityStatuses.filter(\.isAvailable).map(\.capability))
    }

    public func status(for capability: PrismetFeatureCapability) -> PrismetCapabilityStatus? {
        capabilityStatuses.first { $0.capability == capability }
    }
}

public struct PrismetFeature: Codable, Hashable, Identifiable, Sendable {
    public var id: String { canonicalID.rawValue }
    public let canonicalID: PrismetFeatureID
    public let title: String
    public let category: PrismetFeatureCategory
    public let support: [PrismetPlatformSupport]
    public let leaderboardMetric: PrismetLeaderboardMetric?
    public let leaderboardPeriod: PrismetLeaderboardPeriod
    public let visibleInLaunchReview: Bool

    public init(
        canonicalID: PrismetFeatureID,
        title: String,
        category: PrismetFeatureCategory,
        support: [PrismetPlatformSupport],
        leaderboardMetric: PrismetLeaderboardMetric? = nil,
        leaderboardPeriod: PrismetLeaderboardPeriod = .lifetime,
        visibleInLaunchReview: Bool = true
    ) {
        precondition(support.count == PrismetPlatform.allCases.count)
        precondition(Set(support.map(\.platform)) == Set(PrismetPlatform.allCases))
        precondition(support.allSatisfy { record in
            if record.presentationDisposition == .mirrored {
                return record.legacyID?.isEmpty == false
            }
            return record.presentationRationale?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
        })
        self.canonicalID = canonicalID
        self.title = title
        self.category = category
        self.support = support
        self.leaderboardMetric = leaderboardMetric
        self.leaderboardPeriod = leaderboardPeriod
        self.visibleInLaunchReview = visibleInLaunchReview
    }

    // Compatibility views over the platform-aware support records.
    public var iOSID: String? { platformID(for: .iOS) }
    public var macOSID: String? { platformID(for: .macOS) }

    public func support(for platform: PrismetPlatform) -> PrismetPlatformSupport? {
        support.first { $0.platform == platform }
    }

    public func platformID(for platform: PrismetPlatform) -> String? {
        support(for: platform)?.legacyID
    }
}
```

Add an explicit public initializer to any remaining public value type in this task; do not rely on Swift's internal memberwise initializer. Keep the existing top-level leaderboard metric and period only as compatibility metadata for the current iOS behavior. Exact per-mode query scopes and submission destinations belong to the next service-contract plan; this plan must not pretend one policy describes both apps.

Keep `PrismetLeaderboardMetric.higherIsBetter`. Keep `PrismetFeatureManifest` as a deprecated-in-documentation compatibility facade that forwards `all`, `feature(for:)`, `feature(platformID:platform:)`, and `platformID(for:platform:)` to `PrismetFeatureCatalog` without using a Swift deprecation attribute yet.

- [ ] **Step 4: Populate the exact 23-entry table**

Implement the canonical IDs and legacy mappings from **Contract Decisions**. iOS is the baseline. Mac support must report observed gaps:

- Catan: `.trackedDebt` presentation, nil Mac legacy ID, tracked solo/local-save/cloud-save capability debt, and the exact Catan rationales above.
- Every Mac game missing account-scoped cloud save receives a `.cloudSave` capability status of `.trackedDebt`; do not merely omit it.
- Games whose iOS online mode is absent on Mac receive `.onlineFriend` tracked debt with the exact rationale above.
- Debt Clock and Steam Rewind: `.adapted` presentation with available `.lens`; Mac input/presentation is native rather than a literal phone copy.
- Do not assign `parlorTable` or `ambientSpectator` in this slice.
- Assign `.leaderboard` availability and debt exactly as shown in the matrix. Keep Wordgame's existing top-level daily/fewest-moves compatibility metadata. Do not add a lossy platform leaderboard-policy abstraction in this slice.

The constructors above enforce exactly one support record per platform, unique per-capability statuses, a legacy ID for present surfaces, and a non-empty rationale for every non-mirrored presentation or capability status.

- [ ] **Step 5: Run focused tests**

```bash
swift test --package-path shared/PrismetShared --filter PrismetFeatureManifestTests
```

Expected: all catalog tests pass.

- [ ] **Step 6: Commit the catalog**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add shared/PrismetShared/Sources/PrismetShared/PrismetFeatureManifest.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetFeatureManifestTests.swift
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Share Prismet feature capability catalog"
```

---

### Task 2: Add shared game-mode and launch-context contracts

**Files:**
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetGameModeContracts.swift`
- Create: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetGameModeContractsTests.swift`

- [ ] **Step 1: Write failing mode tests**

Cover raw-value compatibility, launch-context round trips, platform-aware options, and canonical identity preservation:

```swift
XCTAssertEqual(PrismetGameMode.soloBot.rawValue, "soloBot")
XCTAssertEqual(PrismetGameMode.localTwoPlayer.rawValue, "localTwoPlayer")
XCTAssertEqual(PrismetGameMode.onlineFriend.rawValue, "onlineFriend")

let context = try PrismetGameLaunchContext.validated(
    featureID: .chess,
    mode: .soloBot,
    surface: .home,
    platform: .iOS
)
XCTAssertEqual(context.featureID, .chess)
XCTAssertEqual(context.surface, .home)
```

Assert iOS mode lists exactly as specified in **Modes and capabilities**. Assert Mac never returns `.onlineFriend` and Catan returns no playable Mac modes. Assert lenses reject construction as a playable launch context. Assert a `.parlor` launch currently rejects Chess and every other feature because no `.parlorTable` capability is available in Workstream 1; Workstream 3 will enable only Catan, Chess, and Reversi without changing their canonical IDs.

- [ ] **Step 2: Run the focused test and observe failure**

```bash
swift test --package-path shared/PrismetShared --filter PrismetGameModeContractsTests
```

Expected: compile failure because the contracts do not exist.

- [ ] **Step 3: Implement the mode API**

```swift
public enum PrismetGameMode: String, CaseIterable, Codable, Hashable, Sendable {
    case soloBot
    case localTwoPlayer
    case onlineFriend
}

public enum PrismetGameLaunchSurface: String, CaseIterable, Codable, Hashable, Sendable {
    case home
    case parlor
}

public struct PrismetGameLaunchContext: Codable, Hashable, Sendable {
    public let featureID: PrismetFeatureID
    public let mode: PrismetGameMode
    public let surface: PrismetGameLaunchSurface
    public let platform: PrismetPlatform

    private init(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    ) {
        self.featureID = featureID
        self.mode = mode
        self.surface = surface
        self.platform = platform
    }

    public static func validated(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    ) throws -> PrismetGameLaunchContext {
        guard PrismetFeatureCatalog.feature(for: featureID) != nil else {
            throw PrismetGameLaunchValidationError.unknownFeature(featureID)
        }
        guard PrismetGameModeCatalog.playableModes(for: featureID, platform: platform).contains(mode) else {
            throw PrismetGameLaunchValidationError.unavailableMode(
                featureID: featureID,
                mode: mode,
                platform: platform
            )
        }
        if surface == .parlor {
            let parlorIsAvailable = PrismetFeatureCatalog
                .feature(for: featureID)?
                .support(for: platform)?
                .status(for: .parlorTable)?
                .isAvailable == true
            guard parlorIsAvailable else {
                throw PrismetGameLaunchValidationError.unavailableSurface(
                    featureID: featureID,
                    surface: surface,
                    platform: platform
                )
            }
        }
        return PrismetGameLaunchContext(
            featureID: featureID,
            mode: mode,
            surface: surface,
            platform: platform
        )
    }
}

public enum PrismetGameLaunchValidationError: Error, Equatable {
    case unknownFeature(PrismetFeatureID)
    case unavailableMode(featureID: PrismetFeatureID, mode: PrismetGameMode, platform: PrismetPlatform)
    case unavailableSurface(
        featureID: PrismetFeatureID,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    )
}

public enum PrismetGameModeCatalog {
    public static func playableModes(
        for featureID: PrismetFeatureID,
        platform: PrismetPlatform
    ) -> [PrismetGameMode] {
        guard let capabilities = PrismetFeatureCatalog
            .feature(for: featureID)?
            .support(for: platform)?
            .capabilities else { return [] }

        let ordered: [(PrismetFeatureCapability, PrismetGameMode)] = [
            (.soloPlay, .soloBot),
            (.localTwoPlayer, .localTwoPlayer),
            (.onlineFriend, .onlineFriend)
        ]
        return ordered.compactMap { capability, mode in
            capabilities.contains(capability) ? mode : nil
        }
    }
}
```

Do not expose an unchecked public memberwise initializer. Add private `CodingKeys`, encode `platform`, and implement `init(from:)` by decoding the four fields and delegating to `validated(featureID:mode:surface:platform:)` so encoded contexts cannot bypass checks. Derive returned modes from available `PrismetCapabilityStatus` records in the stable order solo, local, online. Do not duplicate a second switch table. `surface == .parlor` requires an available `.parlorTable` capability and never grants a missing mode.

- [ ] **Step 4: Run focused and package tests**

```bash
swift test --package-path shared/PrismetShared --filter PrismetGameModeContractsTests
swift test --package-path shared/PrismetShared
```

Expected: all tests pass.

- [ ] **Step 5: Commit game-mode contracts**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add shared/PrismetShared/Sources/PrismetShared/PrismetGameModeContracts.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetGameModeContractsTests.swift
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Add shared Prismet game launch contracts"
```

---

### Task 3: Add explicit player identity domains

**Files:**
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetIdentityContracts.swift`
- Create: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetIdentityContractsTests.swift`

- [ ] **Step 1: Write failing identity tests**

Test value semantics and JSON round trips. Prove two identical derived Game Center UUIDs from different developer teams are not equal:

```swift
let account = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let phoneGC = PrismetGameCenterIdentity(developerTeamID: "PHONE_TEAM", accountID: account)
let macGC = PrismetGameCenterIdentity(developerTeamID: "MAC_TEAM", accountID: account)
XCTAssertNotEqual(phoneGC, macGC)
```

Prove local and backend storage scopes remain distinct even when they contain the same UUID. Prove signed-out identity has no cloud scope and signed-in identity returns `.backendAccount` as its cloud scope.

- [ ] **Step 2: Run the focused test and observe failure**

```bash
swift test --package-path shared/PrismetShared --filter PrismetIdentityContractsTests
```

Expected: compile failure because the identity types do not exist.

- [ ] **Step 3: Implement the identity API**

```swift
public enum PrismetStorageScopeKind: String, CaseIterable, Codable, Hashable, Sendable {
    case device
    case backendAccount
}

public struct PrismetStorageScope: Codable, Hashable, Sendable {
    public let kind: PrismetStorageScopeKind
    public let identifier: UUID

    public init(kind: PrismetStorageScopeKind, identifier: UUID) {
        self.kind = kind
        self.identifier = identifier
    }
}

public struct PrismetGameCenterIdentity: Codable, Hashable, Sendable {
    public let developerTeamID: String
    public let accountID: UUID

    public init(developerTeamID: String, accountID: UUID) {
        self.developerTeamID = developerTeamID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.accountID = accountID
    }
}

public struct PrismetPlayerIdentity: Codable, Hashable, Sendable {
    public let localGuestID: UUID
    public let backendAccountID: UUID?
    public let gameCenter: PrismetGameCenterIdentity?

    public init(
        localGuestID: UUID,
        backendAccountID: UUID?,
        gameCenter: PrismetGameCenterIdentity?
    ) {
        self.localGuestID = localGuestID
        self.backendAccountID = backendAccountID
        self.gameCenter = gameCenter
    }

    public var localStorageScope: PrismetStorageScope {
        PrismetStorageScope(kind: .device, identifier: localGuestID)
    }

    public var cloudStorageScope: PrismetStorageScope? {
        backendAccountID.map { PrismetStorageScope(kind: .backendAccount, identifier: $0) }
    }
}
```

Trim surrounding whitespace from `developerTeamID` in its initializer, but keep an empty value representable for legacy sessions whose team is not yet known. Never add a computed `canonicalPlayerID` that silently coalesces these domains.

- [ ] **Step 4: Run focused and package tests**

```bash
swift test --package-path shared/PrismetShared --filter PrismetIdentityContractsTests
swift test --package-path shared/PrismetShared
```

Expected: all tests pass.

- [ ] **Step 5: Commit identity contracts**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add shared/PrismetShared/Sources/PrismetShared/PrismetIdentityContracts.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetIdentityContractsTests.swift
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Model Prismet player identity domains"
```

---

### Task 4: Add versioned opaque save envelopes

**Files:**
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetSaveEnvelope.swift`
- Create: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetSaveEnvelopeTests.swift`

- [ ] **Step 1: Write failing envelope tests**

Use fixed UUIDs, dates, and bytes. Cover:

- Codable round trip retains opaque payload bytes exactly.
- Encoded JSON is deterministic for the same value.
- `isSupportedEnvelopeVersion` accepts version 1 and rejects version 2.
- `wrappingLegacyPayload(_:payloadSchemaVersion:featureID:scope:slotID:score:modifiedAt:deviceMutationID:sourcePlatform:)` does not decode or alter invalid/non-JSON bytes.
- Device and backend scopes remain distinct.
- `slotID` rejects an empty or whitespace-only value.

Construct the complete fixture a second time inside `XCTAssertThrowsError`, changing only `slotID` to three spaces, and assert the error equals `.emptySlotID`; do not attempt to test a process-terminating precondition.

Representative fixture:

```swift
let envelope = try PrismetSaveEnvelope(
    envelopeVersion: 1,
    payloadSchemaVersion: 7,
    featureID: .chess,
    scope: PrismetStorageScope(kind: .device, identifier: deviceID),
    slotID: "window:00000000-0000-0000-0000-000000000001",
    score: nil,
    modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
    deviceMutationID: mutationID,
    sourcePlatform: .macOS,
    payload: Data([0x00, 0xff, 0x7b])
)
```

- [ ] **Step 2: Run the focused test and observe failure**

```bash
swift test --package-path shared/PrismetShared --filter PrismetSaveEnvelopeTests
```

Expected: compile failure because the envelope and codec do not exist.

- [ ] **Step 3: Implement the envelope and codec**

```swift
public struct PrismetSaveEnvelope: Codable, Hashable, Sendable {
    public static let currentEnvelopeVersion = 1

    public let envelopeVersion: Int
    public let payloadSchemaVersion: Int
    public let featureID: PrismetFeatureID
    public let scope: PrismetStorageScope
    public let slotID: String
    public let score: Int?
    public let modifiedAt: Date
    public let deviceMutationID: UUID
    public let sourcePlatform: PrismetPlatform
    public let payload: Data

    public init(
        envelopeVersion: Int = currentEnvelopeVersion,
        payloadSchemaVersion: Int,
        featureID: PrismetFeatureID,
        scope: PrismetStorageScope,
        slotID: String,
        score: Int?,
        modifiedAt: Date,
        deviceMutationID: UUID,
        sourcePlatform: PrismetPlatform,
        payload: Data
    ) throws {
        guard envelopeVersion > 0 else {
            throw PrismetSaveEnvelopeValidationError.invalidEnvelopeVersion(envelopeVersion)
        }
        guard payloadSchemaVersion > 0 else {
            throw PrismetSaveEnvelopeValidationError.invalidPayloadSchemaVersion(payloadSchemaVersion)
        }
        let normalizedSlotID = slotID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlotID.isEmpty else {
            throw PrismetSaveEnvelopeValidationError.emptySlotID
        }
        self.envelopeVersion = envelopeVersion
        self.payloadSchemaVersion = payloadSchemaVersion
        self.featureID = featureID
        self.scope = scope
        self.slotID = normalizedSlotID
        self.score = score
        self.modifiedAt = modifiedAt
        self.deviceMutationID = deviceMutationID
        self.sourcePlatform = sourcePlatform
        self.payload = payload
    }

    public var isSupportedEnvelopeVersion: Bool {
        envelopeVersion == Self.currentEnvelopeVersion
    }

    public static func wrappingLegacyPayload(
        _ payload: Data,
        payloadSchemaVersion: Int,
        featureID: PrismetFeatureID,
        scope: PrismetStorageScope,
        slotID: String,
        score: Int?,
        modifiedAt: Date,
        deviceMutationID: UUID,
        sourcePlatform: PrismetPlatform
    ) throws -> PrismetSaveEnvelope {
        try PrismetSaveEnvelope(
            payloadSchemaVersion: payloadSchemaVersion,
            featureID: featureID,
            scope: scope,
            slotID: slotID,
            score: score,
            modifiedAt: modifiedAt,
            deviceMutationID: deviceMutationID,
            sourcePlatform: sourcePlatform,
            payload: payload
        )
    }
}

public enum PrismetSaveEnvelopeValidationError: Error, Equatable {
    case invalidEnvelopeVersion(Int)
    case invalidPayloadSchemaVersion(Int)
    case emptySlotID
}

public enum PrismetSaveEnvelopeCodec {
    public static func encode(_ envelope: PrismetSaveEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(envelope)
    }

    public static func decode(_ data: Data) throws -> PrismetSaveEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(PrismetSaveEnvelope.self, from: data)
    }
}
```

Use `try` when constructing the fixture. Add private `CodingKeys`, implement `encode(to:)`, and implement `init(from:)` by decoding every field and delegating to the throwing initializer. This ensures malformed encoded envelopes throw the same validation errors instead of bypassing the initializer. The codec validates only the envelope. It must not reject arbitrary payload bytes.

Do not add filesystem or cloud storage protocols here. Those contracts need adapter behavior and local fakes together in the next Workstream 1 plan.

- [ ] **Step 4: Run focused and package tests**

```bash
swift test --package-path shared/PrismetShared --filter PrismetSaveEnvelopeTests
swift test --package-path shared/PrismetShared
```

Expected: all tests pass.

- [ ] **Step 5: Commit save-envelope contracts**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add shared/PrismetShared/Sources/PrismetShared/PrismetSaveEnvelope.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetSaveEnvelopeTests.swift
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Add versioned Prismet save envelopes"
```

---

### Task 5: Document the contract boundary

**Files:**
- Modify: `shared/PrismetShared/README.md`

- [ ] **Step 1: Replace stale repository paths and manifest description**

Document the actual monorepo roots (`ios/`, `macos/`, `shared/PrismetShared/`) and the four modules delivered by this plan. State explicitly:

- the catalog is current observed support, not a promise that every debt is closed;
- platform adapters own Apple frameworks, Supabase, paths, and migrations;
- payload bytes are opaque and may differ by platform;
- local guest, backend account, and team-scoped Game Center IDs must not be collapsed;
- Parlor rules/ledger/history are future shared modules built on these contracts.

- [ ] **Step 2: Run documentation and placeholder checks**

Search the README, shared sources, and shared tests for the two stale absolute repository names shown in the current README and for unfinished-work markers. Resolve every match. Expected: no stale path or unfinished marker remains.

- [ ] **Step 3: Run the full package suite**

```bash
swift test --package-path shared/PrismetShared
```

Expected: all shared tests pass.

- [ ] **Step 4: Commit documentation**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add shared/PrismetShared/README.md
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Document Prismet shared contract boundaries"
```

---

### Task 6: Verify both app graphs and release the claim

**Files:**
- Modify: `docs/AGENT-COORDINATION.md` (append release note only)

- [ ] **Step 1: Verify the shared package from a clean state**

```bash
swift package --package-path shared/PrismetShared clean
swift test --package-path shared/PrismetShared
```

Expected: package builds cleanly and all tests pass.

- [ ] **Step 2: Regenerate and compile the iOS app without signing**

```bash
cd ios
xcodegen generate --quiet
xcodebuild -project Prismet.xcodeproj -scheme Prismet -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/prismet-shared-contracts-ios build
```

Expected: `** BUILD SUCCEEDED **`. If command-line Xcode is blocked solely by an unaccepted host license, record the exact blocker; do not claim the compile smoke passed.

- [ ] **Step 3: Regenerate and compile the Mac app without signing**

```bash
cd ../macos
xcodegen generate --quiet
xcodebuild -project Prismet.xcodeproj -scheme Prismet -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/prismet-shared-contracts-macos build
```

Expected: `** BUILD SUCCEEDED **`. This is a compile smoke, not a claim that the known hosted Mac test-bundle packaging problem is fixed.

- [ ] **Step 4: Confirm regeneration did not introduce unrelated changes**

```bash
cd ..
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git status --short
```

Expected: only an append-only coordination release note remains. If XcodeGen changed tracked project files without a corresponding project input change, restore those generated-only diffs from the feature branch's pre-generation commit before continuing.

- [ ] **Step 5: Append the release note**

```markdown
### PRISM — Shared Parity Contracts — <UTC timestamp>

- **Status:** RELEASED
- **Delivered:** 23-surface catalog, platform capabilities/dispositions, launch-mode contracts, separated identity domains, opaque versioned save envelope
- **Tests:** `swift test --package-path shared/PrismetShared` passed
- **Builds:** iOS no-sign compile <PASS or exact blocker>; macOS no-sign compile <PASS or exact blocker>
- **Next lane:** Workstream 1 service protocols, local fakes, and additive iOS/macOS adapters; no UI composition until active claims release
```

- [ ] **Step 6: Commit the release note and inspect the final range**

```bash
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git add docs/AGENT-COORDINATION.md
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git diff --cached --check
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git commit -m "Release Prismet shared parity contract lane"
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git status --short --branch
/Users/gtrktscrb/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git log --oneline --decorate -8
```

Expected: clean worktree and a reviewable sequence of focused commits. Do not push, merge to another branch, or modify App Store state without a separate instruction.

## Completion Evidence

This plan is complete only when:

- the shared catalog has exactly 23 canonical surfaces and exact legacy mappings;
- every platform support record has an explicit disposition and non-silent debt;
- Parlor launch contexts are rejected until table registration, and the catalog contains no duplicate Parlor-specific IDs for Catan, Chess, or Reversi;
- Game Center identity is team-scoped rather than treated as a universal account key;
- save payload bytes round-trip unchanged inside a versioned envelope;
- all SwiftPM tests pass from a clean package build;
- both generated app graphs compile, or the exact external Xcode-license blocker is recorded without overstating verification;
- the isolated worktree is clean and the coordination claim is released.
