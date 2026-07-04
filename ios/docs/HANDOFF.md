# Kaleidoscope (iOS) — Handoff

**What this is:** the iOS social-games app (phone accounts → add friends → play head-to-head),
built from the macOS Kaleidoscope. This repo is **sub-project #1: the foundation.**

## Status — foundation COMPLETE (compiles for iOS + Supabase SDK)
- XcodeGen app at `mobile-development/Kaleidoscope` (team `spocksclub`, `com.spocksclub.kaleidoscope`).
- `** BUILD SUCCEEDED **` for iOS Simulator, including all Supabase calls.
- Phone-OTP auth (`AuthManager`), profile load/save (`ProfileStore`, `Profile`), Supabase client.
- Auth gate (`RootView`): setup screen → sign-in → profile setup → home.
- Home grid (`HomeView`) with the current phone game set routed through touch views.
- Account-scoped game memory is wired for **2048**, **Snake**, and **Lights Out**:
  local saves survive switching games on the phone, and cloud rows use the shared
  `game_saves` table so the desktop app can read/write the same account/game record.
  Run the latest `docs/supabase-setup.sql` before expecting real cross-device sync.
- Parchment design system copied from macOS (`Sources/Core/Design`), 2048 model + tests copied.
- Mandatory parity rule: every user-visible iOS change must also have a macOS
  decision before deploy/release. Run `./scripts/check-mac-ios-parity.sh --strict`;
  then either mirror into `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap`,
  mark not applicable with a reason, or update `docs/MAC-IOS-GAME-PARITY.md` with
  tracked parity debt.

## To make sign-in work on the phone (your steps — see `SETUP.md`)
1. Create a Supabase project; run `supabase-setup.sql`; enable Phone auth via Twilio Verify.
2. Paste Project URL + anon key into `Sources/Backend/Secrets.swift` (gitignored).
3. `./scripts/deploy.sh` → installs/launches on "Poopoohead".

Until keys are added the app builds and shows an "Almost there" setup screen.

## Layout
```
Sources/App        KaleidoscopeApp, RootView (auth gate)
Sources/Backend    Secrets, SupabaseClient(Backend), Profile, AuthManager, ProfileStore, GameCloudSyncStore
Sources/Core       Games/(models + GameSync), Design/(KaleidoDesign, Color+Hex)
Sources/Features   Auth/PhoneSignInView, Profile/(ProfileSetupView, MeView), Home/HomeView, Games/*
Tests              Game2048Tests, GameSyncTests
docs               spec, plan, SETUP.md, supabase-setup.sql, Secrets.example.swift
```

## Next sub-projects
- **#2 Friends by phone number:** request/accept; add a `friendships` table + RLS so accepted friends read each other's display info.
- **#3 Multiplayer plumbing:** invite a friend → shared game session → realtime move sync (Supabase Realtime).
- **#4 Per-game versus:** Chess first (port the engine + a touch board), then race/attack modes.
- Also: keep iOS and macOS in lockstep per `docs/MAC-IOS-GAME-PARITY.md`; later
  reconcile the copied core into a shared SwiftPM package both apps use.
