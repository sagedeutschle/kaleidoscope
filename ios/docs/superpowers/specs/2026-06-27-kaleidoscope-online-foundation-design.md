# Kaleidoscope Online — Sub‑project #1: Identity & Backend Foundation

Date: 2026-06-27
Status: Approved (design) — implementing

## Vision

Turn Kaleidoscope (the local macOS games app) into an **iOS social games app**: sign in
with your phone number, set up a profile, add friends by number, and play the games
against each other. This spec covers **only the foundation** — accounts, the backend,
the iOS app shell, and one playable game — that the later sub‑projects build on.

## Locked decisions

- **Platform:** iOS‑first (SwiftUI). Reuse the pure‑Swift game *models*; rebuild the
  AppKit‑bound *views* for iOS. macOS can adopt the shared core later.
- **Backend:** Supabase — Postgres + phone/SMS auth (OTP) + Realtime + Row‑Level Security.
- **Scale:** Personal (me + friends/family). TestFlight, lean, small SMS budget.
- **Friend‑finding:** manual add by phone number (no contacts upload). Contact‑match is later.

## Build order (whole effort; this spec = #1)

| # | Sub‑project | Depends on |
|---|-------------|-----------|
| **1 (this spec)** | Identity + backend foundation + iOS shell + 1 game | — |
| 2 | Friends by phone number (requests/accept) | 1 |
| 3 | Multiplayer plumbing (invite → shared session → realtime sync) | 1 |
| 4 | Per‑game versus (Chess first; race/attack modes for others) | 3 |

## Architecture (sub‑project #1)

```
mobile-development/Kaleidoscope/         # new XcodeGen iOS app (like AlarmClock/Helm)
  project.yml                            # team spocksclub, com.spocksclub.kaleidoscope, iOS 18+
  scripts/deploy.sh                      # build + install + launch on "Poopoohead"
  Sources/
    App/            KaleidoscopeApp.swift, RootView.swift (auth gate)
    Core/           # COPIED pure-Swift from the macOS app — no rewrite of logic
      Games/        Game2048.swift, SeededGenerator, (more games added in later ports)
      Design/       KaleidoDesign.swift  # parchment design system (SwiftUI, portable)
    Backend/        SupabaseClient.swift, Secrets.swift (gitignored), AuthManager.swift,
                    ProfileStore.swift, Profile.swift
    Features/
      Auth/         PhoneSignInView.swift  (number → OTP → verified)
      Profile/      ProfileSetupView.swift, MeView.swift
      Home/         HomeView.swift  (games grid)
      Games/        Game2048View.swift  (iOS port of the first game)
  Resources/Assets.xcassets/  (app icon, accent)
  docs/                       (this spec, attributions)
```

- **Why copy Core, not share a package yet:** Agent‑B is actively developing the macOS
  app; moving its files would clobber that work. iOS is an additive parallel workstream.
  Once the macOS churn settles we extract a real `KaleidoscopeCore` SwiftPM package both
  apps depend on. The game *logic* is identical (copied), so there's no behavioral fork —
  only the views differ per platform.
- **Supabase Swift SDK** added via SPM in `project.yml` (`supabase/supabase-swift`).

## Backend (Supabase)

- One Supabase project (free tier). **Phone auth** enabled, backed by **Twilio Verify**
  (the only cost: a few ¢ per SMS).
- `profiles` table:
  | column | type | notes |
  |---|---|---|
  | `id` | uuid PK | = `auth.users.id` |
  | `phone` | text unique | E.164, from the verified auth identity |
  | `display_name` | text | shown to friends |
  | `avatar_emoji` | text | simple emoji avatar |
  | `avatar_color` | text | hex accent |
  | `created_at` | timestamptz default now() | |
- **RLS:** enabled. A row is readable/updatable only by `auth.uid() = id` for #1.
  (#2 adds a policy letting accepted friends read each other's `display_name`/avatar.)
- A trigger (or client upsert on first run) creates the `profiles` row after first sign‑in.

## iOS app flow (sub‑project #1)

1. **Launch → session check.** `AuthManager` restores the Supabase session from Keychain.
2. **Signed out → `PhoneSignInView`:** enter phone → Supabase sends SMS OTP → enter code →
   verify. On success, a session is stored.
3. **First run → `ProfileSetupView`:** pick display name + emoji/color avatar → upsert
   `profiles` row.
4. **Signed in → `HomeView`:** the games grid in the parchment design system (High‑Contrast
   default), with a **Me** entry (edit profile / sign out) and a placeholder **Friends** tab
   (wired in #2).
5. **Play:** tap **2048** → the ported `Game2048View` (proves the shared core + iOS UI).

## Components & contracts

- `SupabaseClient` — single configured `SupabaseClient` from `Secrets` (URL + anon key).
- `AuthManager: ObservableObject` — `@Published var session`; `sendOTP(phone:)`,
  `verify(phone:, code:)`, `signOut()`, `restore()`.
- `ProfileStore: ObservableObject` — `loadMine()`, `upsert(_ profile:)`; `@Published var me: Profile?`.
- `Secrets` — `static let supabaseURL/anonKey`; committed as `Secrets.example.swift`, real
  `Secrets.swift` is gitignored. App shows a clear "add your Supabase keys" screen if unset.
- Game models copied verbatim; `Game2048View` rebuilt in SwiftUI for touch (swipe + buttons).

## Prerequisites (user — I'll guide each click)

1. Create a Supabase project → copy **Project URL** + **anon public key** into `Secrets.swift`.
2. Create **Twilio Verify** service → paste SID/token into Supabase Auth → Phone settings.
3. Confirm the **Apple PLA** is current on the `spocksclub` team (or Ben re‑agrees) so
   profiles issue for device installs. (Simulator builds need no signing.)

## Out of scope (#1)

Friends‑by‑number (#2) · multiplayer (#3/#4) · porting the AppKit‑heavy games
(chess SceneKit, Rubik's, Minesweeper click target, Brick Bench) · contacts matching ·
macOS adopting the shared package · push notifications.

## Testing & verification

- **Game model tests** copied with the core run in the iOS test target.
- **Compile gate:** `xcodebuild build` for the **iOS Simulator** (no signing) must succeed.
- **Auth/profile:** unit‑test `ProfileStore`/parsing where mockable; phone OTP + RLS are
  verified **on device** (real SMS can't be auto‑tested).
- **Deploy:** `scripts/deploy.sh` installs to "Poopoohead"; DerivedData kept in
  `~/Library/Caches` (never iCloud/Desktop — breaks code‑signing).

## Risks

- **SMS provider setup + cost** is the one external dependency; until Supabase+Twilio are
  configured, auth can't run (the app builds + shows a setup screen).
- **iOS PLA** can block device installs until the account holder re‑agrees.
- **Core duplication** with the macOS app is intentional and temporary (reconcile into a
  shared package later).
