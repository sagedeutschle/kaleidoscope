# Kaleidoscope Security Phase 1

Phase 1 adds app-side guardrails around the current Supabase-backed launch surface.
It does not replace Row-Level Security; Supabase RLS remains the real authority for
which account can read or write backend rows.

## Implemented

- Backend startup validates the configured Supabase URL and anon key before creating
  the shared client.
- Supabase config must use HTTPS, point at a Supabase project host, and carry an
  `anon` JWT role. `service_role` or mismatched project-ref keys are rejected.
- Profile writes sanitize public fields before upload:
  - phone is not written by the client profile editor;
  - display names are trimmed, stripped of control characters, and capped;
  - avatar emoji and color fall back to safe defaults when malformed.
- Leaderboard submissions use the same public-field sanitizer before local
  persistence or remote upload.
- App-side rate limits slow repeated profile writes, cloud game-save pushes,
  leaderboard uploads, online match create/join/move writes, and remote public
  content fetches. Local play still works; remote spam is dropped or kept pending.
- Focused XCTest coverage lives in `Tests/AppSecurityTests.swift`.
- `docs/supabase-security-rate-limits.sql` adds the matching server-side rate
  limits, payload caps, room-code shape checks, participant-turn checks,
  leaderboard score bounds, and `updated_at` touch triggers. It was applied to
  the live `kaleidoscope` Supabase project on 2026-07-03.
- `scripts/probe-supabase-security.py` runs a read-only anon-key probe without
  printing secrets, bearer tokens, or raw row values. The post-apply live probe
  returned `200` for `api_rate_limits`, which confirms the hardening table is now
  visible through the schema cache.

## Server-Side Launch Gates

- RLS on `profiles`, `game_saves`, `multiplayer_matches`, and `leaderboard_scores`
  must remain enabled in Supabase.
- Database CHECK constraints were added as `NOT VALID` so old rows do not block
  launch, but PostgreSQL enforces them for new inserts and updates.
- No service-role key should ever be embedded in app source, app config, Info.plist,
  or bundled resources.
- Global leaderboard writes are still only score-shape/rate protected. Strong
  anti-cheat needs Game Center leaderboards or server-side score validation.
- The Wordgame daily object is intentionally public so the app can fetch it with
  no privileged credential. Do not use a public global Wordgame leaderboard unless
  the answer/scoring path is server-validated; keep the current daily/friend-scoped
  behavior.
