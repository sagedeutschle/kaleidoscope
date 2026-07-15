# Prismet Casino 21-Table Implementation Plan

> **For agentic workers:** Execute through repo-local `legion.sh` cohorts with exclusive file portfolios. Tests first; do not commit or push from worker cohorts.

**Goal:** Add ten honest no-money Casino Labs/Practice tables, route all 21 behind the 18+ gateway on iPhone, iPad, and macOS, and produce submission-ready release artifacts.

**Design:** `docs/superpowers/specs/2026-07-15-prismet-casino-21-table-design.md`

## Task 1: lock gateway foundation

- Verify the session-only threshold, 18+ and planned-verification copy, no persistence, and no table restoration before entry.
- Run focused iOS presentation/safety/session tests and macOS app-plus-test-source build.
- Build, install, launch, and visually inspect all three form factors.
- Commit the clean foundation before new engine cohorts touch shared routing.

## Task 2: build Craps, Sic Bo, Hold'em, and Mini-Baccarat engines

- Create isolated shared source/test pairs for each engine.
- Exhaust the 36 and 216 dice spaces.
- Lock Hold'em street order, burn cards, 21-subset evaluation, and seven-card category counts.
- Lock eight-deck Baccarat shoe identity, tableau rules, exact outcome counts, phase actions, and canonical state validation.
- Run focused tests, then the full shared package suite; review math and state safety before committing.

## Task 3: build the remaining six engines

- Add comparable five-card values and the Three-Card and Caribbean Stud labs.
- Add joker-aware Pai Gow split validation and Omaha's exact two-plus-three evaluator.
- Add single-war Casino War and single-zero European Roulette.
- Run focused/exhaustive tests, full package tests, prohibited-term scan, and independent read-only review before committing.

## Task 4: expand the authoritative catalog and shared adapter

- Add the ten stable IDs and `.studyLab` renderer metadata.
- Replace every 11-entry count/route assertion with an exact 21-ID contract derived from the shared registry.
- Add a typed Study Lab state/action adapter without moving engine rules into platform code.
- Prove unique IDs, complete descriptors, exact disclosure copy, seed discipline, and reset behavior.

## Task 5: integrate iPhone and iPad

- Extend `PracticeCasinoSession` with typed Study Lab state and explicit actions.
- Add one adaptive `PracticeStudyLabView` with bounded card/dice/wheel renderers.
- Route all ten new IDs, remove the hard-coded 11-string audit list, and keep all routes behind the gateway.
- Test compact/regular layouts, every route and phase, VoiceOver labels, Dynamic Type, 44-point targets, Reduce Motion, no-color cues, reset/leave, and no banner in play.
- Run focused and full iOS tests, then build/install/launch iPhone and iPad.

## Task 6: integrate macOS

- Mirror the typed Study Lab session and bounded renderers.
- Route all 21 IDs behind the gateway with narrow/wide layouts, Return primary actions, Escape leave, and visible focus.
- Run presentation/safety/session tests where hosting permits, `swiftc -parse`, and full no-sign app-plus-test-source build.
- Install and launch the fresh Mac app.

## Task 7: final review and release readiness

- Run the full shared package and full iOS suite from clean Derived Data.
- Run the strict Mac/iOS parity gate, `git diff --check`, source safety scans, and independent code/design review.
- Capture live gateway and representative card/dice/wheel screenshots on all three form factors.
- Update coordination/progress/parity docs with exact Legion run IDs, test counts, artifacts, launches, and blockers.
- Bump release/build metadata only after product gates pass; produce signed archives and validate export/upload prerequisites.
- Push the reviewed branch. Upload/submit through the existing Apple release lane when the validated artifacts and honest 18+ metadata are attached.
