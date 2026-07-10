# Prismet — Release Gates

## Launch-Day Update: 2026-07-09

v1.0 build 12 is live on the App Store and downloadable from
`https://apps.apple.com/us/app/kaleidescope/id6785993194`. The old build-8 vs
build-11 review fork below is historical, not the current release state.

Current next-update gates:

- **[x] v1.0 public launch:** App Store Connect is `READY_FOR_SALE`, build 12
  attached and downloadable.
- **[x] Wordgame daily endpoint:** app code points at `https://prismet.xyz/api/wordle`;
  proxy and Supabase source both returned the 2026-07-09 payload during the
  launch-day smoke check.
- **[x] Wordgame broker schedule restored:** local LaunchAgent
  `com.gtrktscrb.wordle-broker.daily` is loaded with 01:15, 02:15, and 10:00
  local runs. Broker source lives in `oracle/wordle-broker/`.
- **[x] v13 Task 8 local rename:** app/source/package/project/display names now
  use Prismet; bundle identifiers, IAP product ID, Supabase refs, Game Center IDs,
  and legacy persistence paths remain frozen.
- **[x] v13 Task 9 version bump:** iOS and macOS now resolve to marketing version
  1.1 and build 13 under the `Prismet` schemes.
- **[x] Next App Store update submitted:** iOS v1.1 build 13 uploaded, attached,
  metadata refreshed, and submitted to App Review. ASC version id
  `88c88227-ddc2-4766-a966-cb2d1d703363`; build id
  `4e231958-05cc-4cc2-87d1-6d5123ccf093`; review submission id
  `ba52e847-a300-415f-a111-e0e983ddc443`. State:
  `WAITING_FOR_REVIEW` as of 2026-07-10T01:57:16Z.
- **[~] v14 started:** source now targets v1.2/build 14 for the next post-review
  update. v1.1 remains the submitted App Store artifact.

**As of 2026-07-04.** The remaining blockers to (A) a public iOS launch and
(B) macOS parity. Grouped by area; each item has a status. Companion:
`docs/HANDOFF.md` (full current-state).

Status legend: **[x] done · [~] in progress / partial · [ ] blocked or not
started.**

---

## A. App Store (iOS public launch)

- **[~] Resolve the build-8 vs build-11 fork (Sage's decision — A/B/C).**
  v1.0 is `WAITING_FOR_REVIEW` with **build 8 attached**; **build 11 is VALID but
  UNATTACHED** (Apple locks the in-review version). Options: **A** ride build 8,
  ship build 11 as 1.0.1; **B** pull v1.0 from review and re-attach build 11; **C**
  reject/replace. *No path chosen yet.* App record `6785993194`; build 11 id
  `82554947-3f20-469b-a8db-7f0b1b44ce54`.
- **[x] App record created** under SpocksClub (team `ZW9HBTRLRT`), Sage = Admin.
- **[x] Release build archived + uploaded** (both build 8 and build 11 are on App
  Store Connect; build 11 is VALID).
- **[ ] Privacy Policy URL + Support URL live and public.** Required by Apple.
  Host `docs/PRIVACY-POLICY.md` as HTML (GitHub Pages or a one-pager). Support
  contact: `artists@deutschleartistry.com`.
- **[~] Screenshots.** 6.9" 1320×2868 set staged for the build-11 metadata in
  `ios/docs/appstore-screenshots-1.0.1/`; confirm the required 6.7"/6.5" sets for
  whichever version actually submits.
- **[~] Listing metadata.** Draft copy + the polished build-11 metadata (subtitle,
  promo text, keywords, description, What's New) are in
  `ios/docs/APP-STORE-LISTING.md`. Confirm final app **name availability** in ASC
  (Prismet may be taken; backups listed there).
- **[ ] Age rating + App Privacy answered** in ASC. Target 10+ (mild fantasy
  violence lever). **Do not** declare phone-number collection or AdMob/IDFA while
  those features are off in the shipping build.
- **[x] Game Center capability** present in the app; confirm it's enabled on the
  ASC record.
- **[ ] Submit for review** (the chosen build). 1.0.1 path requires v1.0 to first
  leave `WAITING_FOR_REVIEW`; full runbook in `ios/docs/APP-STORE-LISTING.md`.

## B. Backend (Supabase + Oracle)

- **[x] Supabase live project** (`kaleidoscope`) with accounts, leaderboards,
  online multiplayer, cloud saves (shared `game_saves` table for iOS↔macOS).
- **[x] Security Phase 1 applied.** App-side sanitization + rate limits shipped;
  server-side RLS + rate limits + CHECK constraints applied to the live project
  **2026-07-03**. RLS must stay enabled on `profiles`, `game_saves`,
  `multiplayer_matches`, `leaderboard_scores`. No service-role key in app/source.
- **[~] Leaderboard anti-cheat.** Only score-shape + rate protected today. Strong
  anti-cheat needs Game Center leaderboards or server-side score validation before
  any public global score board is trusted. Wordgame daily stays public/friend-
  scoped only.
- **[x] Oracle decree pipeline working** — daily `launchd` job runs the local
  `claude` CLI (no API keys), exports `decrees.json`, publishes to the public
  gist both apps read (`oracle/run-daily-mac.sh`).
- **[ ] Repoint the Oracle launchd job** to `oracle/` in the canonical clone after
  the monorepo move, and verify a clean daily run + gist publish.

## C. Ads (AdMob — post-v1)

- **[x] AdMob banner wired** (Google Mobile Ads SDK) but **gated OFF** for v1;
  ships with Google test IDs, banner hidden.
- **[ ] Real AdMob account + App ID + banner unit ID.** **Blocked:** the saved
  Google account shows "Account deleted"; need a valid Google account at
  `apps.admob.com`. When ready, put IDs in `project.yml`
  (`GADApplicationIdentifier`, `PrismetAdMobBannerUnitID`) and pass
  `scripts/check-admob-live.sh --require-live` (prints `ADMOB_STATUS=LIVE_READY`).
- **[ ] Re-do App Privacy / IDFA / ATT answers** before submitting any ads-on
  build.
- Not required for the v1 (ads-off) launch.

## D. IAP — Remove Ads (post-v1)

- **[x] Remove-Ads plumbing done.** StoreKit unlock + SHA-256-hashed tester/family
  codes (`PrismetAdUnlockCodeHashes`); Remove-Ads UI hidden in v1.
- **[ ] Paid Applications Agreement accepted + banking/tax filled.** **Only Ben
  (account holder) can accept it.** Required before any paid IAP.
- **[ ] Create the IAP product** in ASC: non-consumable,
  `com.spocksclub.kaleidoscope.removeads`, $4.99, "Remove Ads" (must match
  `project.yml`). Reviewed alongside the build that enables it.
- Not required for the v1 (ads-off) launch.

## E. Parity (macOS ↔ iOS — hard release gate)

- **[x] Port new games to macOS:** Gomoku, Sea Battle, Crazy 8, and Spider are
  native ready facets with sessions, save/reload wiring, and focused model tests.
- **[~] Mirror the v10/v11 material-identity redesign to macOS:** major surfaces
  are mirrored (walnut 2048, club Checkers, Chess plaques/swatches, Oracle ledger,
  Solitaire baize/cards, Brick Bench workshop chrome, Gomoku goban, Home category
  regroup). Remaining v14 polish: per-game skin pickers and a few result-slip/AI
  parity gaps.
- **[x] Mirror full-color `tile_<game>` Home art** to the macOS launcher.
- **[x] Already mirrored (v10 pass):** DARK default paper, Debt Clock trend banner,
  Brick Bench green-baseplate stud fix.
- **[x] Parity gate enforced in process:** every user-visible iOS change carries a
  macOS decision; `ios/scripts/check-mac-ios-parity.sh --strict` runs before any
  iOS tester/review deploy. Matrix + path map in `ios/docs/MAC-IOS-GAME-PARITY.md`.

## F. Testing / build hygiene

- **[x] macOS build green** under the Prismet scheme after the rename/version bump.
- **[x] Focused macOS parity tests green** for Gomoku, Sea Battle, Crazy 8, and
  Spider.
- **[~] iOS test suite.** Per-game model tests + `AppSecurityTests` +
  `AdEntitlementStoreTests` exist; run the full suite green on the build that
  ships.
- **[~] Device install verification.** v14 Debug installed and launched on macOS
  and Poopoohead. Benjamin's iPhone and MommaPhone installed but launch was
  blocked by lock state. iPad Air was unavailable/asleep. Remaining: unlock
  family devices, confirm launch, Oracle non-empty UI, and online friend room
  smoke.
- **[x] Build rules documented** (derived-data location, incremental archive,
  `project.yml`-owned Info.plist, `xcodegen generate` after pull, codex-delegated
  device deploy) — see `docs/HANDOFF.md` §5. Follow them or builds fail.
- **[ ] Canonical GitHub repo + clone/sync flow confirmed** for all machines
  (Sage desktop, NAS, Ben) — pull-rebase / build-local / push.
