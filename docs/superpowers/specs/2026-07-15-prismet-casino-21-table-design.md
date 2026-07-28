# Prismet Casino 21-Table Age-Gateway Expansion Design

**Status:** Approved by Sage's 2026-07-15 green light

**Platforms:** iPhone, iPad, and macOS

**Release target:** Submission-ready by 10 PM America/New_York on 2026-07-15

## Outcome

Prismet's Casino becomes a visibly separate, 18+ probability-practice segment with 21 playable tables. The existing 11-table foundation remains intact. Ten new educational Labs/Practice tables add authentic card, dice, and wheel rules without importing money, chips, payouts, rewards, or loss-chasing mechanics.

The Casino entry threshold is shown before any table host or game state is created. For this release it is an honest in-memory 18+ self-attestation gateway; it does not claim identity verification or save a birth date. A later verified-age provider replaces only the access-policy seam and can never influence seeds, decks, actions, or outcomes.

## Permanent product laws

1. Casino code contains no real money, purchase, wallet, chip balance, wager, payout, prize, reward, redemption, cash-out, purchasable value, or transferable value.
2. Casino play has no ads, account dependency, cloud result history, leaderboard, persistent aggregate statistics, timer, automatic next round, streak, urgency, fake near miss, or outcome tuning.
3. Every random action is explicit, deterministic from an auditable seed, versioned, and implemented with rejection sampling or Fisher-Yates.
4. Every result exposes exact counts/fractions or an exact combinatorial model. House-edge games are never called 50/50.
5. Tables use resolution, comparison, qualification, classification, and neutral language rather than betting outcomes.
6. Reset clears only the current in-memory compact/Poker/Lab visit state. The pre-existing Blackjack active-hand audit save remains isolated and is never described as a balance or result history.
7. All 21 IDs route on iPhone, iPad, and macOS only after the age gateway.

## Authoritative 21-table roster

The existing 11 remain: Practice Blackjack, Five-Card Draw, Red or Black, Higher or Lower, High Card, Coin Call, Dice Duel, Over or Under Seven, Odd or Even, Fair Wheel, and Number Draw.

The ten new stable IDs are:

| # | Stable ID | User-facing title | Honest scope |
|---:|---|---|---|
| 12 | `three-card-poker-lab` | Three-Card Poker Hand Lab | Deal and compare two three-card hands with exact category counts; no ante, fold, or payout table |
| 13 | `texas-holdem-lab` | Texas Hold'em Hand Lab | Reveal hole cards and community streets, then classify best five of seven; no pot, blind, opponent equity, or wagering |
| 14 | `caribbean-stud-qualification-lab` | Caribbean Stud Qualification Lab | Compare five-card hands and explain reference-hand qualification; no ante, call, side option, or payout |
| 15 | `pai-gow-split-lab` | Pai Gow Split Lab | Set a two-card low and five-card high hand from a 53-card deal; no banker, commission, or house way |
| 16 | `omaha-hand-lab` | Omaha Hand Lab | Reveal four hole cards and a board, then classify using exactly two hole plus three board cards |
| 17 | `mini-baccarat-practice` | Mini-Baccarat Outcome Lab | Advance through fixed Punto Banco tableau rules and observe Player/Banker/tie frequencies; no selections or commission |
| 18 | `casino-war-practice` | Casino War Practice | Compare one card, then explicitly resolve a single war on an initial tie; no stake or recursive pressure loop |
| 19 | `craps-point-lab` | Craps Point Lab | Observe come-out and point resolution with exact two-dice probabilities; no pass line or side options |
| 20 | `sic-bo-outcome-lab` | Sic Bo Outcome Lab | Roll three dice and inspect total/pattern distributions; no prediction or payout menu |
| 21 | `european-roulette-lab` | European Roulette Lab | Spin a single-zero 37-pocket wheel and show 18/37 red, 18/37 black, 1/37 zero; no chips or selections |

Spanish 21 is deliberately deferred. Its authentic doubles, surrender, bonus-21 rules, and regional variations are too broad for a trustworthy same-day implementation without importing payout-like concepts. Omaha fills the tenth slot with a precise, educational rule that reuses the audited poker evaluator.

## Shared architecture

`PrismetPracticeCasinoCatalog` becomes the sole 21-ID registry. New descriptors use a `.studyLab` kind and a bounded renderer family (`cards`, `dice`, or `wheel`) so platform apps do not maintain a second rules registry.

Each new engine owns typed state, action, phase, result, validation error, rules version, randomizer version, seed, and canonical audit state. Multi-step labs shuffle once and reveal only already-determined cards after explicit actions; later reveals never consume a new seed. Decode validation recomputes canonical state and rejects altered decks, dice, cursors, phases, redaction, or derived categories.

A shared `PrismetCasinoStudyLabState` and `PrismetCasinoStudyLabAction` adapter may wrap the ten strongly typed engines for platform sessions, but it must not erase their individual invariants or move rules/math into SwiftUI.

Comparable poker helpers provide category plus lexicographic tie-break ranks and best-five subset evaluation. Three-card ranking remains separate because a straight outranks a flush. Pai Gow keeps a dedicated joker-aware evaluator. Omaha evaluates exactly 60 valid two-hole/three-board combinations.

## Platform presentation

The gateway is a full emerald/ivory/brass threshold with the 12-part probability seal, explicit 18+ language, the permanent no-money disclosure, a calm `I'm 18+ — Enter Practice Casino` action, and `Not Now`. The decision lasts only for the current view lifetime. Copy states that verified-age access is planned before public release and never says the player has been verified.

Inside the hub, one shared catalog drives the picker. A generic Study Lab host renders:

- card layouts with rank/suit VoiceOver labels, hidden-card counts, phase actions, and comparison/classification ledgers;
- dice layouts with textual die values, totals, patterns, and exact distributions;
- wheel layouts with numbered/color text equivalents and the native probability rosette.

iPhone uses a compact horizontal picker and single-column table. iPad uses library/table/rules columns at regular width. macOS uses split/stacked layouts, Return for the current primary action, Escape for Leave, and visible focus. All actions meet 44-point targets; Dynamic Type, Reduce Motion, and Differentiate Without Color remain first-class.

## Safety and release gates

- Shared tests prove exactly 21 unique stable IDs, every engine's deterministic replay, exact count sums, invalid-action immutability, canonical decode validation, and no automatic outcomes.
- Platform tests prove every ID routes behind the threshold and that no table host exists before access.
- Static scans cover source and visible copy for economic, pressure, ad, timer, persistence, and fake-verification dependencies.
- Run the full shared and iOS suites, macOS app-plus-test-source build, strict parity gate, fresh iPhone/iPad/macOS builds, installs, launches, and representative accessibility/visual smokes.
- App Store Connect metadata must answer frequent simulated-gambling age-rating questions honestly. Release notes emphasize practice, transparent odds, no money, and no transferable value.
- A signed iOS/iPad archive and a validated macOS release artifact are required for the submission-ready claim. Actual upload/submission uses the existing release lane only after all gates pass.
