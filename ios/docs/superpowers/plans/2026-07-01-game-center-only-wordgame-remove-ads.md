# Game Center Only, Wordgame, Remove Ads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Game Center the only account identity, rename user-facing Wordle labels to Wordgame, and make the $4.99 Remove Ads purchase path testable and clear.

**Architecture:** Preserve existing account-id plumbing so game save and leaderboard code keeps working. Replace phone/SMS auth surfaces with Game Center-derived account UUIDs. Add a StoreKit configuration for the Remove Ads product and explicit unavailable-state copy when Apple-side product loading fails.

**Tech Stack:** SwiftUI, GameKit, StoreKit 2, XcodeGen, XCTest, Supabase backend plumbing where already present.

## Global Constraints

- iOS and macOS apps are both in scope for Game Center-only account surfaces.
- Phone number, SMS code, OTP, and Twilio-dependent user paths must not remain visible.
- Visible Wordle/Daily Wordle labels become Wordgame/Daily Wordgame.
- Practice mode behavior stays unchanged.
- The $4.99 product id remains `com.spocksclub.kaleidoscope.removeads`.
- Real TestFlight/App Store purchase still requires App Store Connect IAP, Paid Applications Agreement, and banking/tax setup.
- Do not change AdMob placement or banner unit configuration.
- Run `xcodegen generate` after adding/removing Swift or StoreKit files.

---

### Task 1: iOS Game Center Identity Replaces Phone Auth

**Files:**
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources/App/RootView.swift`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources/Backend/AuthManager.swift`
- Delete: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources/Features/Auth/PhoneSignInView.swift`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources/Features/Profile/MeView.swift`
- Test: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Tests/GameCenterIdentityTests.swift`

**Interfaces:**
- Consumes: `GameCenterIdentity.accountID`, `GameCenterIdentity.displayName`, `GameCenterIdentity.State`.
- Produces: `AuthManager.useGameCenterAccount(_:)`, `AuthManager.markGameCenterUnavailable(_:)`, existing `AuthManager.State.signedIn(UUID)`.

- [ ] Write failing tests for deterministic Game Center UUID and no phone auth API expectations.
- [ ] Run focused tests and confirm failure before production edits.
- [ ] Change `AuthManager` into a Game Center session adapter with no Supabase OTP methods.
- [ ] Change `RootView` to authenticate through `GameCenterIdentity`, present Game Center unavailable copy instead of phone sign-in, and load profile by Game Center-derived UUID.
- [ ] Remove `PhoneSignInView.swift` from the iOS source tree.
- [ ] Remove phone display/sign-out affordance from `MeView`.
- [ ] Run focused auth/profile tests.

### Task 2: macOS Game Center Only Account Surface

**Files:**
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/Sources/App/ContentView.swift`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/Sources/Account/AccountViews.swift`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/Sources/Account/AuthManager.swift`
- Test: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/Tests/GameCenterLeaderboardTests.swift`

**Interfaces:**
- Consumes: `GameCenterAuthenticationController.state`.
- Produces: no visible phone sign-in view, no SMS/OTP user copy.

- [ ] Write failing macOS tests or static assertions for no phone sign-in copy.
- [ ] Run focused tests and confirm failure before production edits.
- [ ] Convert/remove the account panel so Game Center is the only account surface.
- [ ] Remove phone OTP methods from macOS `AuthManager` or make them unavailable to UI.
- [ ] Run focused Game Center/account tests.

### Task 3: Wordgame Visible Naming

**Files:**
- Modify iOS files with user-facing Wordle labels under `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources`
- Modify macOS files with user-facing Wordle labels under `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/Sources`
- Test existing registry/session tests where labels are asserted.

**Interfaces:**
- Consumes: existing Wordle/WordPuzzle implementation types.
- Produces: visible app labels `Wordgame` and `Daily Wordgame`.

- [ ] Add failing tests or grep-backed assertions for visible Wordgame labels.
- [ ] Replace user-facing labels and status copy from Wordle to Wordgame.
- [ ] Keep internal type names unless a compile-time reference requires a narrow rename.
- [ ] Run focused game registry/session tests.

### Task 4: iOS Remove Ads $4.99 StoreKit Path

**Files:**
- Create: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Configuration/RemoveAds.storekit`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/project.yml`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources/Core/Ads/AdEntitlementStore.swift`
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Sources/Core/Ads/RemoveAdsView.swift`
- Test: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope/Tests/AdEntitlementStoreTests.swift`

**Interfaces:**
- Consumes: `AdConfig.removeAdsProductID`, StoreKit `Product.products`.
- Produces: clear purchase unavailable message and local StoreKit config for Debug purchase testing.

- [ ] Write failing entitlement/purchase-state tests for product unavailable messaging or injectable purchase client.
- [ ] Run focused tests and confirm failure before production edits.
- [ ] Add StoreKit configuration with non-consumable product id `com.spocksclub.kaleidoscope.removeads` at `$4.99`.
- [ ] Wire XcodeGen scheme StoreKit configuration if supported by current project patterns.
- [ ] Update `RemoveAdsView` copy so unavailable product explains App Store Connect setup instead of a dead-feeling button.
- [ ] Run focused ad entitlement tests.

### Task 5: Regenerate, Verify, Deploy Where Practical

**Files:**
- Modify coordination docs in both repos.

**Interfaces:**
- Consumes: all prior task outputs.
- Produces: regenerated projects, passing focused tests, and clear final status.

- [ ] Run `xcodegen generate` in both repos.
- [ ] Run iOS focused tests for auth, Wordgame naming, and ad entitlement.
- [ ] Run macOS focused tests for account/Game Center and Wordgame naming.
- [ ] Run a focused iOS build with `CODE_SIGNING_ALLOWED=NO`.
- [ ] Run a focused macOS build/test where touched files require it.
- [ ] Update `docs/AGENT-COORDINATION.md` in both repos with a PRISM release note.

