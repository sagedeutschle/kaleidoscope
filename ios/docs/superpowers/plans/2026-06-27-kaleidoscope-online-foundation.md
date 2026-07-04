# Kaleidoscope Online — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) tracking.

**Goal:** A compiling iOS app where you sign in by phone number, set a profile, and play 2048 — with the Supabase backend wiring in place for friends/multiplayer later.

**Architecture:** New XcodeGen iOS app at `mobile-development/Kaleidoscope`. Pure‑Swift game models + the parchment design system are COPIED from the macOS app (no rewrite). Supabase (phone OTP auth + `profiles` table + RLS) via the supabase‑swift SPM package. Config lives in a gitignored `Secrets.swift`; the app shows a setup screen until keys are filled.

**Tech Stack:** Swift 5 / SwiftUI, iOS 17+, XcodeGen, supabase‑swift, Xcode 26, devicectl ("Poopoohead").

**Build/verify gate (no signing needed):**
`cd mobile-development/Kaleidoscope && xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'generic/platform=iOS Simulator' -derivedDataPath ~/Library/Caches/KaleidoscopeiOS/DD CODE_SIGNING_ALLOWED=NO build`

---

## Task 1: XcodeGen project + app shell
**Files:** Create `project.yml`, `Sources/App/KaleidoscopeApp.swift`, `Sources/App/RootView.swift`, `scripts/deploy.sh`, `.gitignore`, `Resources/Assets.xcassets/`.
- [ ] `project.yml`: name Kaleidoscope; iOS deploymentTarget "17.0"; team `ZW9HBTRLRT`; bundle `com.spocksclub.kaleidoscope`; SPM package `supabase-swift` (url `https://github.com/supabase/supabase-swift`, from 2.0.0) with product `Supabase`; sources `Sources`, resources `Resources`.
- [ ] `KaleidoscopeApp.swift`: `@main` App with `WindowGroup { RootView() }`.
- [ ] `RootView.swift`: temporary `Text("Kaleidoscope")` placeholder (replaced in Task 4).
- [ ] `.gitignore`: `*.xcodeproj`, `Sources/Backend/Secrets.swift`, build dirs.
- [ ] `scripts/deploy.sh`: xcodegen + build + `xcrun devicectl device install/launch` to UDID `00008120-001278982192201E` (mirror AlarmClock's deploy.sh; DerivedData under `~/Library/Caches`).
- [ ] Build (simulator gate) → succeeds (empty app).

## Task 2: Copy Core (game model + design system) + port 2048
**Files:** Create `Sources/Core/Games/Game2048.swift` (+ `SeededGenerator`), `Sources/Core/Design/KaleidoDesign.swift`, `Sources/Features/Games/Game2048View.swift`, `Tests/Game2048Tests.swift`.
- [ ] Copy `Game2048.swift` + `SeededGenerator` verbatim from the macOS app (`apps/chess-hotswap/Sources/Model/Game2048.swift`).
- [ ] Copy the design tokens (`Kaleido` enum, `FacetBackdrop`/`facetBackground`, `GameHeader`, `StatBadge`, `kaleidoCard`, button styles, `KaleidoPaper`) into `KaleidoDesign.swift`, dropping macOS‑only bits (`.windowToolbar`); keep it iOS‑clean.
- [ ] Port `Game2048View` to iOS: swipe `DragGesture` + on‑screen arrows, board uses `.topLeading` containment fix, accent from a local constant (no FacetRegistry yet).
- [ ] Copy `Game2048Tests` into the test target; build the test target.

## Task 3: Supabase backend client + auth + profile
**Files:** Create `Sources/Backend/Secrets.example.swift`, `Secrets.swift` (gitignored), `SupabaseClient.swift`, `AuthManager.swift`, `Profile.swift`, `ProfileStore.swift`; `docs/supabase-setup.sql`, `docs/SETUP.md`.
- [ ] `Secrets.example.swift`: `enum Secrets { static let supabaseURL = "https://YOUR.supabase.co"; static let supabaseAnonKey = "YOUR_ANON_KEY" }`; copy to `Secrets.swift` (real values later) with an `isConfigured` flag.
- [ ] `SupabaseClient.swift`: lazily build `SupabaseClient(supabaseURL:supabaseKey:)` from Secrets; expose `Backend.client`.
- [ ] `Profile.swift`: `Codable` struct {id, phone, display_name, avatar_emoji, avatar_color, created_at}.
- [ ] `AuthManager: ObservableObject`: `@Published var state: AuthState (.loading/.signedOut/.signedIn(userID))`; `restore()`, `sendOTP(phone:)`, `verify(phone:code:)`, `signOut()` using `client.auth.signInWithOTP(phone:)` + `verifyOTP(phone:token:type:.sms)`.
- [ ] `ProfileStore: ObservableObject`: `@Published var me: Profile?`; `loadMine()`, `upsert(...)` against `profiles`.
- [ ] `docs/supabase-setup.sql`: `create table profiles (...)`, enable RLS, policy `auth.uid() = id` for select/insert/update.
- [ ] `docs/SETUP.md`: step‑by‑step — create Supabase project, enable Phone auth, configure Twilio Verify, run the SQL, paste URL+anon key into `Secrets.swift`.
- [ ] Build (simulator gate) → succeeds (SPM resolves supabase‑swift).

## Task 4: Auth gate + flow UI + home
**Files:** Create `Sources/Features/Auth/PhoneSignInView.swift`, `Sources/Features/Profile/ProfileSetupView.swift`, `Sources/Features/Profile/MeView.swift`, `Sources/Features/Home/HomeView.swift`; modify `RootView.swift`.
- [ ] `RootView`: owns `@StateObject AuthManager` + `ProfileStore`; switches on auth state: setup‑needed screen if `!Secrets.isConfigured`; `.loading` → splash; `.signedOut` → `PhoneSignInView`; `.signedIn` w/o profile → `ProfileSetupView`; else `HomeView`.
- [ ] `PhoneSignInView`: phone field → "Send code" → OTP field → "Verify"; errors inline; parchment styled.
- [ ] `ProfileSetupView`: name + emoji + color → save (upsert) → enters app.
- [ ] `HomeView`: parchment games grid (just "2048" live; others "soon") + a Me button (sheet → `MeView` with sign out) + a disabled Friends tab placeholder.
- [ ] `MeView`: shows profile, edit name/avatar, Sign Out.
- [ ] Build (simulator gate) → succeeds.

## Task 5: Verify + handoff
- [ ] Full simulator build green; run model tests.
- [ ] Write `docs/HANDOFF.md` (state, prereqs, how to run, what's next: friends #2).
- [ ] Report to user the exact external steps (Supabase + Twilio + paste keys) to make auth live on device.

## Self-Review
- Spec coverage: identity/auth (T3/T4), backend+RLS (T3), iOS shell (T1/T4), one game (T2), shared‑core copy (T2), setup docs (T3/T5). ✓
- Placeholders: none — file contents/SQL/SPM specified.
- Type consistency: `Secrets.supabaseURL/anonKey/isConfigured`, `AuthManager.state`, `ProfileStore.me`, `Profile` fields are referenced consistently across tasks.
