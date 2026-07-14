# Prismet Full Parity and Casino Parlor Program Design

**Status:** Approved by Sage on 2026-07-14

**Platforms:** iOS, iPadOS, macOS

**Source products:** Prismet and The Long Now's Gaming/Casino Parlor

**Delivery shape:** Five independently shippable workstreams with separate implementation plans

**Store posture:** Simulated gambling is accepted; Parlor Tokens have no purchase path or real-world value.

## Outcome

Prismet becomes one coherent Apple-platform game cabinet:

- the macOS app carries the phone app's functional features, with native Mac input and presentation;
- Casino Parlor becomes a first-class Prismet destination on iPhone, iPad, and Mac;
- games that already exist in both products converge on one canonical Prismet game rather than appearing twice;
- new Parlor games share deterministic Swift rules across platforms;
- account, save, history, leaderboard, and supported online-friend behavior use common contracts;
- every workstream remains buildable and releasable while the larger program is in progress.

This is a native Swift/SwiftUI integration. Prismet will not embed the Godot runtime and will not maintain parallel platform-specific copies of new rules engines.

## Success Criteria

The program is complete when:

1. Every current user-visible iOS feature has a macOS disposition of **mirrored**, **adapted**, or **not applicable**, with no unexplained parity debt.
2. Catan is playable on Mac with the approved 3D/2D presentation and the same rules and customization behavior as iOS.
3. Mac users can use the supported Prismet account, profile, cloud-save, leaderboard, and online-friend flows available on iOS.
4. Casino Parlor is available on all three Apple form factors with a shared catalog, token ledger, table history, saved-table behavior, and ambient spectators.
5. Existing Prismet Catan, Chess, and Reversi are the Parlor's canonical versions; no duplicate engines or save identities are introduced.
6. Poker, Rune Slots, Liar's Bones, Comet Wheel, Bell Crypt, and Tower & One are native Prismet games backed by deterministic shared rules and platform-adaptive interfaces.
7. No token can be purchased, gifted, sold, cashed out, converted to another entitlement, or redeemed for anything of value.
8. Builds, migrations, accessibility checks, parity gates, and representative live UI smokes pass on iPhone, iPad, and Mac.

## Source-of-Truth Boundaries

### Prismet

`/Users/gtrktscrb/Desktop/Kaleidoscope` remains the product repository and shipping source of truth.

- `shared/PrismetShared/` owns portable contracts and, incrementally, deterministic rules/state.
- `ios/` owns iPhone/iPad presentation and Apple-mobile adapters.
- `macos/` owns Mac presentation and Mac-specific adapters.
- `docs/AGENT-COORDINATION.md` owns cross-agent claims and releases.
- `ios/docs/MAC-IOS-GAME-PARITY.md` remains the parity ledger until a shared replacement is landed.

### Casino Parlor reference

`/Users/gtrktscrb/Desktop/GtrktscrB/gaming/the-long-now` is a read-only product reference for this program unless a separate task explicitly changes it.

Relevant reference surfaces include:

- `game/src/castle/gaming_parlor.*` for room hosting, standing tables, history, focus, and atmosphere;
- `game/src/parlor/` for Catan/Charter, Chess/War Table, Reversi/Moonflip, table settings, and spectators;
- `game/src/casino/` for Poker, Rune Slots, Liar's Bones, Comet Wheel, and Bell Crypt;
- `game/src/castle/tower_one_*` for Tower & One;
- their focused GUT tests as behavioral evidence.

The Swift implementation must reproduce published behavior, not transliterate GDScript line by line. No Godot binary, scene, autoload, save file, or runtime dependency is copied into Prismet.

## Product Model

### One catalog, two ways in

Prismet keeps its existing categorized Home catalog and adds a **Casino Parlor** destination. A user may:

- open a canonical game directly from Home; or
- enter the Parlor, see tables and ambient activity, then sit at a table.

Opening Catan, Chess, or Reversi from the Parlor launches the same game identity, rules, preferences, and persistence used by its Home card. The Parlor supplies presentation context and an optional play-token table contract; it does not create `parlor-catan`, `war-table`, or `moonflip` duplicate games.

### Parlor table set

| Parlor table | Canonical Prismet identity | Treatment |
| --- | --- | --- |
| Catan / Charter | `catan` | Reuse and finish the existing shared iOS/macOS Catan lane. |
| Chess / War Table | `chess` | Reuse Prismet Chess; add a Parlor table skin and optional token match contract. |
| Reversi / Moonflip | `reversi` | Reuse Prismet Reversi; add a Parlor table skin and optional token match contract. |
| Poker | `poker` | New shared deterministic rules and adaptive views. |
| Rune Slots | `rune-slots` | New shared weighted-reel/pity/jackpot rules and adaptive views. |
| Liar's Bones | `liars-bones` | New shared bluffing-dice rules, bot behavior, and adaptive views. |
| Comet Wheel | `comet-wheel` | New shared wheel/odds rules and adaptive views. |
| Bell Crypt | `bell-crypt` | New shared push-your-luck grid rules and adaptive views. |
| Tower & One | `tower-one` | New shared twenty-one-style rules, dealer behavior, and adaptive views. |

Fantasy table names may appear as subtitles or skins, but standard game names and rules language remain visible for legibility.

### Parlor Tokens

Parlor Tokens are a closed, play-only scoring resource.

- They are not an in-app purchase, ad reward, subscription benefit, transferable item, prize, or cash equivalent.
- They unlock no Prismet content and confer no competitive advantage outside Parlor tables.
- A new local ledger starts with **100 Tokens**. Whenever its balance is below the cheapest currently enabled stake (default **2 Tokens**), the player can immediately refill to **100 Tokens**; there is no timer, streak, payment, or ad gate.
- Initial balance, refill floor, wager ranges, and posted returns are versioned configuration, not hard-coded UI values.
- Every debit, credit, and refill is an idempotent ledger transaction with a stable transaction ID and a committed resulting balance.
- A failed or uncertain write leaves the table unresolved and offers a retry; it never silently repeats a debit or payout.

Home launches remain ordinary no-token games. When Catan, Chess, or Reversi is opened from the Parlor, token play is opt-in and local/solo only: a win returns twice the accepted stake, a draw returns the stake, and a loss returns zero. Catan uses the same win/loss contract against its bots. Online-friend matches never accept or settle Parlor Tokens.

The ledger is local for signed-out users. Signed-in users may cloud-sync through the same account boundary as other Prismet state, with conflict handling defined below.

### History and spectators

The Parlor includes:

- a guest book showing recent completed tables in chronological order;
- saved standing tables for supported long games;
- local ambient bot tables for Catan, Chess, Reversi, and Poker;
- pause/resume behavior when the Parlor is not visible;
- deterministic seeds so tests and visual captures can reproduce a table;
- no network traffic for ambient spectators.

History retains the newest **200** completed-table receipts and prunes older receipts after a successful atomic write. It stores game identity, participants, result summary, token delta, completion time, and optional seed. It does not store hidden hands, secret future random values, access tokens, email addresses, or chat content.

## Architecture

### Shared domain layer

`PrismetShared` grows by bounded modules rather than one large catch-all file:

- `FeatureCatalog` — canonical IDs, categories, capabilities, and platform dispositions;
- `GameModeContracts` — solo, local, supported online-friend, and Parlor table context;
- `SaveEnvelope` — schema/version metadata and opaque game payload boundaries;
- `ParlorCatalog` — table descriptors, standard/fantasy names, wager configuration, and capability flags;
- `ParlorLedger` — idempotent token transactions and deterministic conflict resolution;
- `ParlorHistory` — bounded, chronological, codable table receipts;
- one focused rules/state module per new casino game.

Shared code imports Foundation only unless an Apple framework is genuinely required on both platforms. SwiftUI, UIKit, AppKit, SceneKit view adapters, GameKit UI, Supabase clients, and local file locations remain outside the pure rules modules.

### Platform application layers

iOS/iPadOS and macOS each provide:

- navigation and adaptive SwiftUI composition;
- touch versus pointer/keyboard input mapping;
- sound, haptic, and visual feedback adapters;
- local persistence location and lifecycle hooks;
- Game Center authentication/presentation;
- Supabase transport and realtime subscription adapters;
- accessibility environment mapping;
- SceneKit representables where a 3D board is used.

The platform views consume the same rules snapshots and command APIs. A view must not independently calculate payouts, legal moves, winners, random outcomes, or ledger balances.

### Service boundaries

The application layer depends on protocols for:

- identity/profile;
- local and cloud save storage;
- leaderboard submission/query;
- online match transport;
- Parlor token storage;
- Parlor history storage;
- clock and random-seed sources.

Existing iOS implementations are adapted behind these boundaries before Mac parity is wired. The goal is shared behavior and test fixtures, not necessarily one source file for every Apple service.

## Workstream 1: Shared Contracts and Mac Parity Foundation

This workstream makes later feature ports safe.

1. Replace ad-hoc parity comparisons with a shared feature/capability manifest covering every game, lens, account surface, and platform-specific disposition.
2. Introduce shared save-envelope and game-mode contracts without changing existing persisted payloads.
3. Put iOS account/profile, cloud-save, leaderboard, and online-match behavior behind explicit interfaces.
4. Add macOS adapters using the existing Mac account and leaderboard foundations.
5. Keep iOS ads, consent UI, haptics, and touch-only affordances explicitly `notApplicable` on Mac; provide Mac-appropriate feedback and input instead.
6. Add contract tests that run against local fakes for both targets.

No user-facing casino table ships in this workstream. It ends with a reliable parity inventory and working Mac service seams.

## Workstream 2: Existing Phone Features and Catan on Mac

This workstream closes current known product gaps before adding more games.

- Complete the already-planned Catan macOS 3D/2D port after the active Catan lane releases its files.
- Mirror supported online-friend room flows for Mac games that currently remain phone-first.
- Mirror account-scoped cloud saves and conflict/error presentation.
- Align profile, leaderboard, settings, themes/skins, result slips, and AI/mode controls where the current parity ledger identifies weaker Mac behavior.
- Preserve Mac advantages: pointer hover, menus, keyboard shortcuts, resizable layouts, and window-safe focus restoration.
- Do not add mobile ads or a mobile remove-ads purchase flow to Mac.

This workstream updates the parity ledger row by row and must leave no newly introduced casino code.

## Workstream 3: Casino Parlor Shell

This workstream ships a useful Parlor before all new games are ready.

- Add the Parlor destination and category art on iPhone, iPad, and Mac.
- Build a responsive room/table browser using Prismet's approved Illuminated Cabinet semantic materials, with warm amber pixel-art cues from The Long Now.
- Register Catan, Chess, and Reversi as the first canonical tables.
- Add the play-only token ledger, free refill, posted odds disclosure, guest book, and standing-table storage.
- Add deterministic ambient spectators for the first reusable tables.
- Add reduced-motion, high-contrast, Dynamic Type, VoiceOver, keyboard, and focus behavior from the first commit.

The Parlor shell depends on the visual-facelift primitives but does not take ownership of that lane's files. It consumes released components or defines narrow Parlor-local components until the facelift lane lands.

## Workstream 4: New Casino Tables

New tables land as small vertical slices in this order:

1. **Comet Wheel** — smallest deterministic wager/return loop; proves ledger settlement.
2. **Rune Slots** — weighted reels, pity behavior, jackpot configuration, and disclosure.
3. **Tower & One** — multi-action round, double-down, dealer behavior, and settlement retry.
4. **Liar's Bones** — hidden information and bot bluffing.
5. **Poker** — larger hidden-state/turn-flow surface and ambient spectating.
6. **Bell Crypt** — distinct push-your-luck/grid interaction and final visual polish pass.

Each slice contains:

- shared rules/state and deterministic tests;
- codable snapshot/migration coverage;
- iPhone/iPad adaptive SwiftUI view;
- macOS adaptive SwiftUI view and keyboard/pointer behavior;
- Parlor registration and posted rules/odds;
- local save/history/ledger integration;
- representative visual evidence on both platform families.

No new casino table gains online wagering or online token transfer. Online multiplayer is not inferred from the existence of Prismet's friend-match infrastructure; it requires a separate approved design.

## Workstream 5: Release, Migration, and Quality Gates

The final workstream closes the program rather than hiding remaining debt.

- Run the strict iOS/macOS parity gate and require a disposition for every manifest item.
- Migrate existing game saves in place and preserve canonical identities.
- Verify signed-out to signed-in adoption for local saves, Parlor balance, and history.
- Refresh App Store age-rating answers and disclose simulated gambling accurately.
- Update screenshots, description, privacy/support copy, and region-specific availability requirements as necessary.
- Verify iPhone, iPad, and Mac builds from generated projects.
- Run focused and full test suites in proportion to each target's reliable host behavior.
- Install/launch on the Mac and available physical iOS devices, plus representative simulators.
- Perform accessibility and interruption/recovery smokes before release staging.

No App Store submission occurs implicitly as part of feature implementation. Uploading, attaching a build, changing regional availability, or submitting for review remains an explicit release action.

## Data Flow

### Launching a table

1. Home or Parlor selects a canonical `FeatureID`.
2. The shared catalog returns supported modes and Parlor capability.
3. The platform coordinator loads the canonical save envelope and player identity.
4. If a token table is requested, the ledger validates the requested stake and reserves/debits it atomically.
5. The shared rules state starts from a recorded seed and emits snapshots.
6. The platform view renders snapshots and sends typed commands.
7. Completion produces one settlement receipt, one history receipt, and an updated save state.

### Cloud saves

- Local state is always written first through an atomic replace operation.
- Cloud upload is asynchronous and visible when pending or failed.
- Save envelopes contain schema version, canonical game ID, account scope, modification time, device mutation ID, and payload.
- Identical mutation IDs are idempotent.
- For ordinary game saves, a newer valid envelope wins unless the game supplies an explicit merge strategy.
- For token transactions, balances are never resolved by last-write-wins. Transactions are deduplicated by ID and the balance is derived from the accepted ledger sequence.
- Conflicts that cannot be proven safe stop settlement and show a retry/recovery state.

### Online friend play

- Mac uses the same canonical game/mode catalog and match payload contracts as iOS.
- Realtime updates remain fail-soft with polling as a recovery path.
- A match command includes match ID, revision, actor identity, and idempotency key.
- Stale revisions and duplicate commands are rejected without mutating local state.
- Casino token balances never travel through friend-match payloads.

## Failure Handling

- Missing/corrupt local saves fall back only after preserving the unreadable payload for diagnosis; they are not silently overwritten.
- Unsupported future schemas show a non-destructive update-required state.
- Failed token debits prevent a round from starting.
- Failed token payouts preserve the resolved table and expose an idempotent retry.
- Reopening after a crash resumes an unresolved settlement before accepting another wager.
- Cloud/network failure never blocks offline solo/local play unless that exact mode requires the network.
- Missing spectator data hides the ambient table rather than blocking the Parlor.
- Missing art uses a canonical glyph and accessible label.
- Authentication loss returns to signed-out local storage without deleting account-scoped records.

## Migration

1. Keep all existing canonical game IDs and storage keys stable.
2. Wrap legacy payloads in the new save envelope on successful read; do not bulk-rewrite every save at launch.
3. Treat existing macOS local scores and saves as device-local records eligible for explicit signed-in adoption.
4. Catan, Chess, and Reversi keep one save identity regardless of whether they were launched from Home or the Parlor.
5. New Parlor records begin at schema version 1 and include migration readers before any schema bump ships.
6. No The Long Now `user://` file is imported automatically. A future explicit importer would require a separate design because the products use different engines, identities, and economies.

## Visual and Interaction Design

- The Parlor uses the approved Illuminated Cabinet material roles rather than introducing a second app-wide theme.
- Its distinctive layer is warm amber light, dark wood/ink, compact pixel-art table scenes, and readable gilt signage.
- Standard game names remain primary or immediately visible; fantasy names are flavor, not required vocabulary.
- iPhone uses focused table cards and full-screen play.
- iPad may show the table list and live preview side by side when width permits.
- Mac uses a resizable room/browser, hover previews, strong keyboard focus, shortcuts, and pointer-appropriate table controls.
- All important controls remain at least 44 points on touch platforms and comfortably targetable on Mac.
- Motion never carries rules information; Reduce Motion substitutes state changes without transforms or particle effects.

## Accessibility

- Every game exposes rules, stake, possible return, current balance, turn, result, and recovery state as text—not color or animation alone.
- VoiceOver order follows play order and never enters decorative room art.
- Hidden-information games expose only information legitimately available to that player.
- Dynamic Type reflows rather than clips fixed table canvases.
- Mac keyboard play includes a discoverable shortcut/help surface and visible focus.
- High Contrast strengthens board boundaries, text, selected state, and focus rings.
- Reduce Transparency and Reduce Motion receive deterministic fallbacks.
- Sound and haptics are optional feedback channels with independent controls; no action requires them.

## Privacy, Safety, and Store Constraints

- Simulated gambling is declared accurately in App Store Connect.
- Parlor Tokens have no purchase, advertisement-reward, transfer, cash-out, prize, entitlement, or external-value path.
- Odds and returns are visible before a wager; random outcomes come from tested deterministic rules seeded by a system random source in normal play.
- Analytics, if present, record game/table events without hidden hands, exact personal balances, or raw profile data.
- Online-friend safety and account deletion behavior remain consistent across platforms.
- No real-money gaming, sweepstakes, raffles, or user-funded prize pool is introduced.

## Testing Strategy

### Shared package

- deterministic golden tests for every rules engine;
- state-machine legality and invariant tests;
- codable round-trip and migration fixtures;
- seeded full-game simulations where practical;
- ledger property tests for idempotency, insufficient funds, retry, and conflict ordering;
- catalog completeness and unique-ID tests.

### Platform targets

- route/catalog tests on iOS and macOS;
- view-model tests using fake identity, storage, transport, clock, and ledger services;
- snapshot or source-contract tests for critical adaptive layouts;
- input tests for touch, keyboard, pointer, focus restoration, and Escape/back behavior;
- accessibility-label/order tests for table and settlement controls;
- offline/realtime-failure recovery tests.

### Integration and live verification

- strict parity check;
- XcodeGen regeneration before build judgments;
- iOS generic/simulator build and reliable focused/full test suites;
- macOS no-sign build plus focused tests, with hosted-test packaging failures distinguished from source failures;
- live Mac launch and representative iPhone/iPad simulator captures;
- physical iOS install/launch when devices are available;
- forced crash/relaunch around unresolved token settlement and cloud-save upload.

## Coordination and Ownership

This program must coexist with current lanes:

- **Catan:** the existing planned Catan-to-macOS files remain owned by the Catan lane until it posts a release or explicit handoff. Workstream 2 consumes that result and does not edit through the claim.
- **Illuminated Cabinet facelift:** Parlor presentation consumes released semantic components. It does not absorb or overwrite the active facelift spec/source lane.
- **Online catalog/matches:** existing remote or active online-lobby work is reconciled before changing match contracts.
- **The Long Now:** remains read-only reference. Its dirty shared checkout, active claims, and GDScript are not staging sources for Prismet commits.

Before each implementation workstream, append an exact file claim to `docs/AGENT-COORDINATION.md`, confirm the branch and worktree state, and stage only owned files.

## Rollout and Commit Boundaries

Each workstream receives its own detailed implementation plan and lands in reviewable vertical slices:

1. Shared contracts and Mac parity foundation.
2. Existing phone-feature parity and Catan on Mac.
3. Cross-platform Casino Parlor shell.
4. One new casino game per independently testable slice.
5. Final migration, accessibility, parity, device, and store gates.

Generated projects are regenerated when source/project inputs change, but unrelated generated artifacts, DerivedData, local secrets, visual scratch files, and The Long Now changes are never included in Prismet feature commits.

## Explicit Non-Goals

- Embedding Godot in Prismet.
- Automatic import of The Long Now saves or Wizard Token balances.
- Real-money gambling or prizes.
- Purchasing, transferring, gifting, or redeeming Parlor Tokens.
- Online wagering or online casino multiplayer in this program.
- Replacing Prismet's existing Catan, Chess, or Reversi with duplicate Parlor IDs.
- Copying iOS ads, touch gestures, or haptics literally onto Mac.
- Submitting a build to App Review without a separate explicit release instruction.
