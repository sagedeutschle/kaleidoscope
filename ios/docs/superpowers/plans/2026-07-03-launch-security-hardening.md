# Launch Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seal the App Store launch backend surface without disrupting current users or deleting existing Supabase data.

**Architecture:** Keep the client as a public anon-key app and make Supabase RLS, triggers, constraints, and rate limits the authority. Add a local audit script so the same read-only and authenticated probes can be rerun without exposing secrets. Apply production SQL only after preflight confirms the migration is additive and compatible with existing rows.

**Tech Stack:** Swift/XCTest, Supabase PostgREST/Auth, SQL/Postgres, Bash/Python audit helpers, XcodeGen/xcodebuild.

## Global Constraints

- Do not print or persist Supabase service-role keys, JWTs, or access tokens.
- Do not delete, rewrite, or migrate existing user rows.
- Keep app-side throttles as UX guardrails only; server-side SQL is the real protection.
- Prefer idempotent SQL: `create if not exists`, `drop trigger if exists`, guarded `do $$` blocks.
- Run focused tests and an iOS build before claiming completion.

---

### Task 1: Harden Supabase SQL Migration

**Files:**
- Modify: `docs/supabase-security-rate-limits.sql`
- Test: `Tests/AppSecurityTests.swift`

**Interfaces:**
- Consumes: existing `profiles`, `game_saves`, `multiplayer_matches`, and optional `leaderboard_scores` tables.
- Produces: idempotent SQL for `api_rate_limits`, write-rate triggers, payload caps, status/room-code checks, score bounds, timestamp update triggers, and safer RLS policies.

- [ ] Add failing XCTest assertions that the SQL defines `api_rate_limits`, rate-limit triggers, multiplayer payload/status/room-code constraints, leaderboard score constraints, and no destructive `delete from`/`truncate` statements.
- [ ] Run `xcodebuild ... -only-testing:KaleidoscopeTests/AppSecurityTests/testSupabaseSecurityMigrationContainsLaunchHardening`.
- [ ] Update `docs/supabase-security-rate-limits.sql` to satisfy the test.
- [ ] Re-run the focused AppSecurity test selector.

### Task 2: Add Live Security Probe Script

**Files:**
- Create: `scripts/probe-supabase-security.py`
- Test: `Tests/AppSecurityTests.swift`

**Interfaces:**
- Consumes: `Sources/Backend/Secrets.swift` for project URL and anon key.
- Produces: redacted JSON/stdout audit results covering read-only table visibility, public Wordgame object reachability, anonymous auth availability, and non-mutating schema/rate-limit presence checks.

- [ ] Add failing XCTest assertions that the probe script exists and redacts sensitive markers.
- [ ] Run the focused test and confirm failure.
- [ ] Implement the script with no secret printing.
- [ ] Re-run focused tests.

### Task 3: Production Preflight and Apply

**Files:**
- Use: `docs/supabase-security-rate-limits.sql`
- Use: `scripts/probe-supabase-security.py`

**Interfaces:**
- Consumes: Supabase CLI authenticated session or linked project access.
- Produces: production Supabase hardening applied only if preflight is compatible.

- [ ] Run the probe in read-only mode and record table/status findings.
- [ ] Check Supabase CLI project access without printing credentials.
- [ ] Apply the SQL migration through the safest available Supabase CLI path.
- [ ] Re-run the probe and confirm `api_rate_limits` exists and public object access still works.

### Task 4: Verification and PRISM Handoff

**Files:**
- Modify: `docs/SECURITY-PHASE-1.md`
- Modify: `docs/AGENT-COORDINATION.md`

**Interfaces:**
- Consumes: test output and live probe output.
- Produces: launch-security status note with residual risks.

- [ ] Run focused `AppSecurityTests`.
- [ ] Run an iOS Debug build on simulator or generic iOS.
- [ ] Update security docs with applied/live status and remaining launch checklist.
- [ ] Add PRISM release note with commands/results and any blocked item.
