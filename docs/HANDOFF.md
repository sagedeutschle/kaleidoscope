# Kaleidoscope — Monorepo Handoff

**Snapshot date: 2026-07-04.** This is the single current-state doc for the whole
project. It supersedes the two per-app handoffs (`ios/docs/HANDOFF.md`,
`macos/docs/HANDOFF.md`) — read this first; treat those as history.

Companion doc: **`docs/RELEASE-GATES.md`** — the launch blocker checklist. This
file is the "what it is / what's shipping"; that file is the "what's left."

---

## 0. What Kaleidoscope is

A calm, parchment-styled home for ~18 classic games (Chess, 2048, Sudoku,
Minesweeper, Snake, Solitaire, Sea Battle, Gomoku, Reversi, Checkers, Connect
Four, Wordgame, Rubik's Cube, and more), plus a 3D LEGO-style brick builder and a
daily "Oracle" decree. It ships as **two native apps that share a design and a
game roster** — one iOS, one macOS — backed by a Supabase account/multiplayer
layer and a decree backend. Cross-platform parity between the two apps is an
explicit, enforced release gate, not a nice-to-have.

## 1. Repo layout (consolidated monorepo)

Root: `/Users/gtrktscrb/Desktop/Kaleidoscope`

```
ios/      Shipping iOS app (SwiftUI, iOS 17, XcodeGen + SPM). The lead app.
macos/    Desktop Kaleidoscope (formerly "chess-hotswap"). Parity target.
shared/   KaleidoscopeShared — local Swift package both apps depend on
          (each project.yml references ../shared/KaleidoscopeShared).
oracle/   Wizard King's Decree backend (Python 'wkd'). Feeds both apps.
docs/     THIS doc, RELEASE-GATES.md, AGENT-COORDINATION.md (lane protocol).
```

### Sync model — read before you touch anything
- **Canonical = a private GitHub repo.** The NAS shared folder, Sage's desktop
  (`/Users/gtrktscrb/Desktop/Kaleidoscope`), and Ben's machine are all **clones**
  that sync through GitHub.
- Workflow: **`git pull --rebase` before work, `git push` after.** Always **build
  on your LOCAL clone**, never on the NAS SMB mount (see build rules).

---

## 2. iOS app (`ios/`) — the one shipping

- **What it is:** SwiftUI, iOS 17, universal (iPhone + iPad,
  `TARGETED_DEVICE_FAMILY = 1,2`). XcodeGen-generated project + Swift Package
  Manager.
- **Identity:** bundle `com.spocksclub.kaleidoscope`, team **`ZW9HBTRLRT`**
  (SpocksClub). Account holder = **Ben** (Sage's dad); **Sage is Admin**.
- **App Store Connect app record id:** `6785993194`.
- **Games:** ~18 playable, each with its own material identity (felt tables,
  walnut trays, neon arcades, newsprint puzzles). Recent additions: **Gomoku,
  Spider, Crazy 8, Sea Battle**.
- **Backend:** Supabase — accounts, leaderboards, online head-to-head
  multiplayer, and cloud saves (shared `game_saves` table so macOS and iOS can
  read/write the same account/game record). Security Phase 1 (app-side
  sanitization + rate limits) is in, and matching server-side RLS + rate limits
  were **applied to the live `kaleidoscope` Supabase project on 2026-07-03**.
- **Auth for v1:** **Apple Game Center + anonymous. NO login wall.** Phone-OTP
  sign-in exists in the codebase but is **disabled for the review build** (don't
  declare phone-number collection in App Privacy while it's off).
- **Ads for v1:** AdMob banner is wired (Google Mobile Ads SDK) but **GATED OFF**
  — the build ships ads-free using Google test IDs, real IDs not yet swapped in.
- **Oracle feature:** reads the public decree gist published by `oracle/` (below).

### App Store review status (the important part)
There are two builds in play and one **open decision that is Sage's to make**:

- **Build 8** is **attached** to App Store version **v1.0**, which is currently
  **`WAITING_FOR_REVIEW`** (Apple's 1–3 day clock).
- **Build 11** — the current, much-improved app (~18 games, the new titles,
  online head-to-head, real sound + haptics, the v10/v11 material-identity
  redesign) — is **uploaded and VALID but UNATTACHED**. Apple locks the
  in-review version, so build 11 cannot be attached to v1.0 while it sits in
  `WAITING_FOR_REVIEW`.
- **The fork decision (A/B/C) is Sage's:**
  - **A — Ride build 8:** let v1.0 clear review on the older build, then ship
    build 11 as **1.0.1**. A full runbook for this path (create 1.0.1, attach
    build 11 id `82554947-3f20-469b-a8db-7f0b1b44ce54`, push the polished
    metadata + 6.9" screenshots, submit) is staged in
    `ios/docs/APP-STORE-LISTING.md` under "1.0.1 SHIP RUNBOOK." Apple blocks
    creating 1.0.1 until v1.0 leaves `WAITING_FOR_REVIEW` (approved or rejected).
  - **B — Pull v1.0 from review** and re-attach build 11 to v1.0 so the *first*
    public release is the good build.
  - **C — Reject/replace** via Apple's flow to swap the build.
  This is not yet decided. Do not force one; surface it to Sage.

### iOS layout
```
Sources/App        KaleidoscopeApp, RootView (auth gate)
Sources/Backend    Secrets, SupabaseClient, Profile, AuthManager, ProfileStore, GameCloudSyncStore
Sources/Core       Games/(models + GameSync), Design/(KaleidoDesign, Color+Hex), Ads/*
Sources/Features   Auth/*, Profile/*, Home/HomeView, Games/*
Tests              per-game model tests + AppSecurityTests, AdEntitlementStoreTests
docs               APP-STORE-LISTING, MAC-IOS-GAME-PARITY, ADMOB-LIVE-ADS, REMOVE-ADS-CODES, SECURITY-PHASE-1, SETUP
```

---

## 3. macOS app (`macos/`) — the parity target

- **What it is:** the desktop Kaleidoscope, formerly **`chess-hotswap`**. SwiftUI,
  XcodeGen. Launches to a Home "lens grid" of facets.
- **Identity:** bundle `com.gtrktscrb.kaleidoscope`, team **`YJR3ABV3H4`**
  (Sage's own — different team from iOS).
- **Deploy:** `macos/scripts/deploy-mac.sh` → builds and installs to
  `~/Applications/Kaleidoscope.app`.
- **State:** stable and playable. Chess, Brick Bench (with BrickLink
  import/export), Wordle, Oracle, Rubik's, 2048, Lights Out, Minesweeper, Snake,
  Sliding-15, Sudoku, Nonogram, Reversi and more are ready facets. ~180 model
  tests passing at last full run.
- **Parity debt (tracked):** macOS **lags iOS on the v10/v11 design pass.** Open
  gaps, per `ios/docs/MAC-IOS-GAME-PARITY.md`:
  - **New games not yet ported to macOS:** **Spider, Crazy 8, Sea Battle** (and
    the new **Gomoku** model/view mirror).
  - **Material-identity redesigns not yet mirrored:** walnut 2048 tray, club
    Checkers board, Chess plaques/swatches, Oracle ledger card, Solitaire baize +
    real card faces, Brick Bench workshop chrome, Gomoku goban.
  - **Full-color `tile_<game>` Home art:** iOS uses it; macOS launcher still uses
    its old icon treatment (tracked debt).
  - Per-game skin pickers, Home category regroup (macOS `FacetRegistry`).
  - Already mirrored in the v10 pass: DARK default paper, Debt Clock trend
    banner, and the Brick Bench green-baseplate stud fix.

**Parity is a hard gate.** Every user-visible iOS change must carry a macOS
decision in the same turn: **mirrored**, **not applicable (with reason)**, or
**tracked debt (owner + next action)**. Before any iOS tester/review deploy, run
`ios/scripts/check-mac-ios-parity.sh --strict`. Path mapping and the current
matrix live in `ios/docs/MAC-IOS-GAME-PARITY.md`. Shared, non-UI contracts belong
in the `KaleidoscopeShared` SwiftPM package (both apps depend on it; first
contract is `KaleidoscopeFeatureManifest`).

---

## 4. Oracle backend (`oracle/`) — the decree service

- **What it is:** the **Wizard King's Decree** backend, a Python package `wkd`.
  Conceptually: a council of chat models commits to no-hedge prophecies about
  upcoming news, an independent Court Historian grades each against reality, and
  the running record is an auditable, self-grading forecasting experiment (full
  design in `oracle/SPEC.md`, which is authoritative).
- **How it runs today:** a **daily `launchd` job** runs the local **`claude` CLI
  (no API keys)** to forge and grade decrees, exports `decrees.json`, and
  publishes it to a **PUBLIC GitHub gist**. Entry point:
  `oracle/run-daily-mac.sh` (needs `claude` + `gh` + `python3` on PATH; gist id in
  `oracle/.gist-id`).
- **Read/write model:** **single writer = Sage's laptop; public read = everyone.**
  Both apps' Oracle feature fetches the same public gist, so no per-app
  credential is needed.
- **Handoff note:** when the monorepo moves to its canonical home, the launchd
  job that points at the old path must be **repointed to `oracle/` in the new
  clone** and re-verified (this is an open thread — see below).

---

## 5. Build rules (hard-won — do not skip)

These apply to the iOS target especially and have each cost a debugging session:

1. **Build into `~/Library/Caches` derived-data, NEVER a path inside the
   project.** iCloud / file-provider xattrs cause `CodeSign failed`. And **never
   build on the NAS SMB mount.**
2. **Release archive with `SWIFT_COMPILATION_MODE=incremental`.** Whole-module
   optimization crashes `swift-frontend` on this target.
3. **`Info.plist` is regenerated by XcodeGen from `project.yml` on every
   `xcodegen generate`.** Put Info.plist keys in
   `project.yml` → `targets.<T>.info.properties`. **Never** hand-edit
   `Info.plist` and **never** use `INFOPLIST_KEY_*` (won't merge).
4. **`.xcodeproj` is generated from `project.yml` and is gitignored.** Run
   **`xcodegen generate` after every clone/pull** before building.
5. **iOS device build+deploy is delegated to the codex CLI**
   (`/Applications/Codex.app/Contents/Resources/codex`). Fallback: direct
   `xcodebuild` + `xcrun devicectl device install/launch --device <CoreDevice-id>`.

### Registered test devices (team `ZW9HBTRLRT`)
- **iPhone 15 Plus "Poopoohead"** — hardware UDID
  `00008120-001278982192201E`, CoreDevice `B2081DF4-7D29-5F35-8CC4-18227227036B`.
- **iPad Air 13" M3** — hardware UDID `00008122-001E79A20EB9801C`, CoreDevice
  `F4E0AAC6-BAAC-5213-A50D-EB233908A105`.
- Gotcha: **install commands want the CoreDevice id**, not the hardware UDID.
  Only pre-registered devices install.

---

## 6. Who works here, and how (agent coordination)

- **Collaborators:** **Sage** (owner — `artists@deutschleartistry.com`, GitHub
  `sagedeutschle`) and **Ben** (Sage's dad, iOS account holder), who is **now
  joining with his own agents.** Onboard Ben + his agents from zero using this
  doc, `docs/RELEASE-GATES.md`, and `docs/AGENT-COORDINATION.md`.
- **Lane split (PRISM protocol):**
  - **Codex** = wiring / function / backend / data.
  - **Claude & Fable** = design / polish / visual.
  - Both may work vertically, but **must coordinate via
    `docs/AGENT-COORDINATION.md`**: claim a lane, log every file touched, and do a
    grep-marker sweep before building. If a file you need is lane-claimed, don't
    edit through the claim — log it and carry it as tracked debt until released.
- **Kaleidoscope iOS builds:** prefer delegating build+deploy to the **codex CLI**
  (per build rule 5).

---

## 7. Top open threads

1. **App Store fork decision A/B/C (Sage's call).** Build 11 is the app people
   should get; build 8 is what's in review. Decide ride-8-then-1.0.1 vs.
   pull-and-reattach vs. reject/replace. Runbook for the 1.0.1 path is staged.
2. **macOS parity debt.** Port Spider / Crazy 8 / Sea Battle / Gomoku to macOS and
   mirror the six-game material-identity redesign + tile art. This gates "macOS
   parity," which itself gates release.
3. **Repoint + verify the Oracle daily launchd job** at `oracle/` in the canonical
   clone after the monorepo move.
4. **Ads/IAP still parked for later:** live AdMob IDs blocked on a working Google
   account; Remove-Ads IAP blocked on the Paid Applications Agreement (only Ben,
   the account holder, can accept it). Both are post-v1.
5. **Onboard Ben's agents** into the PRISM lane protocol and the pull-rebase /
   build-local / push sync flow.

See `docs/RELEASE-GATES.md` for the itemized blocker checklist with status.
