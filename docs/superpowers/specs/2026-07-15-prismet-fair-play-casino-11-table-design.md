# Prismet Fair Play Casino 11-Table Expansion Design

**Status:** Approved by Sage's all-green-lights instruction on 2026-07-15

**Platforms:** iPhone, iPad, and macOS

**Delivery window:** One four-hour implementation pass

## Outcome

Prismet's Casino becomes a calm probability-practice room with 11 genuinely playable tables. Every random result comes from one shared deterministic implementation, every table explains its rules and exact probability model, and no result can acquire financial or transferable value.

The experience should feel like an emerald study room with game tables, not a monetized casino floor. Warm ivory cards, restrained brass focus states, readable diagrams, and clear rules replace flashing lights, manufactured suspense, and reward-loop decoration.

## Product Laws

These are technical requirements, not optional copy:

1. No real money, purchases, wallet, cash-out, external account, transferable value, purchasable value, prize, reward, or redemption path exists in Casino code.
2. No Casino table imports or calls ads, StoreKit, Game Center, leaderboards, cloud sync, social pressure, or account state.
3. Results and completed-round counts live only in memory for the current Casino visit. Reset Session clears them. Leaving the Casino releases them.
4. A new round begins only after the player chooses New Round, Deal Hand, Roll Dice, Draw Numbers, or Reveal Result. No timer, lifecycle event, result observer, or animation starts another round.
5. Random outcomes use `PrismetDeterministicRandom` with rejection sampling or Fisher-Yates shuffle. The player can see the completed round's seed and randomizer version and reproduce it.
6. Balanced games expose exact rational probabilities. Games with ties expose the tie separately. Blackjack explicitly states that it is not a 50/50 game.
7. Animations never fake a near miss, change a selected outcome, delay a result for pressure, flash repeatedly, pulse indefinitely, or trigger confetti.
8. Leave Game is always visible. Reset Session states exactly what it clears. Neither action uses shame, urgency, or loss-recovery language.
9. The Casino surface must not display the app's global advertisement banner while a table is open.
10. All 11 catalog entries must route on iPhone, iPad, and macOS before the pass is called complete.

## Approaches Considered

### Separate engine and view stack for every table

This gives every game maximum bespoke depth, but creates too many controllers, duplicated lifecycle rules, and platform-parity points for a four-hour pass. It is appropriate for later deepening, not this expansion.

### Shared fair-chance engine plus two anchor engines — selected

One catalog and one deterministic fair-chance engine cover the compact card, dice, wheel, and number-draw tables. Existing Blackjack stays intact. Five-Card Draw gets a focused typed engine because hold-and-draw state is genuinely different. iOS/iPadOS and macOS receive thin native SwiftUI shells around the same shared observations.

This produces meaningfully different games without hiding ten cosmetic skins over one random action. It also keeps every probability and randomization rule out of platform views.

### One universal table with ten visual skins

This is fastest, but the games would not have distinct decisions, state, or rules. It fails the requirement for at least ten real games and is rejected.

## Playable Table Roster

| # | Table | Player loop | Exact disclosure |
|---:|---|---|---|
| 1 | Practice Blackjack | Hit, Stand, End Hand, explicit New Hand | Existing visible-information bust fraction; fixed dealer rules; explicit statement that Blackjack is not 50/50 |
| 2 | Five-Card Draw | Deal five, hold any cards, draw once, classify final hand | Every opening five-card set is one of 2,598,960 equally likely combinations; category counts are published |
| 3 | Red or Black | Choose a color, reveal one card | 26/52 for each color |
| 4 | Higher or Lower | Reveal a card, choose higher or lower, reveal the next card | Counts above and below the shown rank out of 51; equal rank is 3/51 and resolves neutrally |
| 5 | High Card | Deal one card to each side | Higher card 8/17, lower card 8/17, equal rank 1/17 |
| 6 | Coin Call | Choose heads or tails, reveal once | 1/2 for each side |
| 7 | Dice Duel | Roll one fair die for each side | Higher 15/36, lower 15/36, tie 6/36 |
| 8 | Over or Under Seven | Choose below seven or above seven, roll two dice | Below 15/36, above 15/36, seven 6/36 and neutral |
| 9 | Odd or Even | Choose odd or even, roll two dice | 18/36 for each parity |
| 10 | Fair Wheel | Choose ivory or emerald, reveal one of 12 equal segments | Six segments per color, so 6/12; each numbered segment is 1/12; there is no zero segment |
| 11 | Number Draw | Choose exactly three values from 1 through 12, draw three without replacement | Match distribution is hypergeometric: 84/220 for zero, 108/220 for one, 27/220 for two, and 1/220 for three |

Five-Card Draw uses the standard mutually exclusive five-card category counts: straight flush 40, four of a kind 624, full house 3,744, flush 5,108, straight 10,200, three of a kind 54,912, two pair 123,552, one pair 1,098,240, and high card 1,302,540. A royal flush is presented as a named straight-flush subtype rather than double-counted.

## Shared Architecture

### `PrismetPracticeCasinoCatalog.swift`

Owns stable game IDs, titles, short descriptions, SF Symbol names, semantic visual families, selection rules, rules versions, exact fairness explanations, and game kind. The catalog imports Foundation only and contains no platform colors, navigation, persistence, or services.

Public concepts:

- `PrismetPracticeCasinoGameID`
- `PrismetPracticeCasinoGameDescriptor`
- `PrismetPracticeSelectionRule`
- `PrismetPracticeChoice`
- `PrismetPracticeCasinoCatalog.all`

The catalog contains exactly 11 entries and treats `blackjack` and `fiveCardDraw` as typed anchor games. The other nine entries route through the fair-chance engine.

### `PrismetFairChanceEngine.swift`

Owns all compact-table randomization, input validation, outcome text, reveal tokens, exact fractions, seed, rules version, and terminal state.

Public concepts:

- `PrismetProbabilityFraction`, reduced by greatest common divisor while preserving numerator and denominator.
- `PrismetPracticeRoundRequest`, containing one game ID and selected choice IDs.
- `PrismetPracticeRoundResult`, containing the game ID, seed, randomizer version, reveal tokens, neutral result title/body, and probability lines.
- `PrismetFairChanceEngine.play(_:seed:)`.

The engine is a pure function. Calling it twice with the same request and seed returns the same result. Invalid choice counts, duplicate number choices, out-of-range choices, unsupported game IDs, and attempts to route Blackjack or Poker through the compact engine return typed errors without a partial result.

### `PrismetFiveCardPoker.swift`

Owns a shuffled 52-card deck, the five displayed cards, held indices, draw phase, final category, and audit seed.

Public concepts:

- `PrismetPokerCategory`
- `PrismetFiveCardPokerState`
- `PrismetFiveCardPokerEngine.deal(seed:)`
- `PrismetFiveCardPokerEngine.togglingHold(at:in:)`
- `PrismetFiveCardPokerEngine.drawing(_:)`
- `PrismetFiveCardPokerEngine.evaluate(_:)`

The opening hand is dealt from a Fisher-Yates shuffled deck. The player may toggle any of the five holds until Draw. Draw replaces every unheld card exactly once from the unused deck. A completed hand cannot draw again. Deal Again is an explicit platform-session action that creates a new seed.

## Platform Presentation

### Shared interaction shell

Each platform controller stores:

- selected game ID;
- current compact-game request/result;
- current Five-Card Draw state;
- in-memory completed-round count;
- an injectable seed source for tests and `SystemRandomNumberGenerator` for live explicit rounds.

Changing tables clears the previous table's transient result. Reset Session clears all Casino session state and returns to a pre-round screen; it does not automatically deal. Leaving releases the controller with the view hierarchy.

### iPhone

The hub begins with a horizontally compact game picker and a single-column table. The safety disclosure and Leave Game remain above the scrollable game area. Choice controls and the primary action are at least 44 by 44 points. At widths below 360 points, action groups stack. Completed results place New Round, Rules & Fairness, Reset Session, and Leave Game within reachable scroll or safe-area controls.

### iPad

At 760 points or wider, the view uses a game library rail, table canvas, and a 300–340 point rules/odds inspector. Narrow Split View falls back to the iPhone-style stack. The table and inspector can scroll independently, and Dynamic Type cannot force horizontal clipping.

### macOS

At 860 points or wider, the existing Casino sidebar becomes a scrollable 11-table library. Narrow windows use a compact scrollable strip above the table. Every primary action has a keyboard equivalent where it is unambiguous; Escape invokes the calm leave path. Pointer hover changes border/fill only. Focus order is game picker, choices/holds, primary action, rules, reset, leave.

## Visual System

The design uses semantic tokens mirrored in each platform's `CasinoTheme.swift`:

- deep emerald `#0B3D34` for table surfaces;
- ink emerald `#102A26` for high-contrast text and chrome;
- warm ivory `#F7F4EA` for cards and rules panels;
- muted ivory `#E8E4D8` for dividers and disabled surfaces;
- restrained brass `#D7A84A` for selection and focus;
- dark brass `#8A5A00` for accessible accent text on ivory;
- mint `#BFE6D5` for neutral-positive information;
- oxblood `#7E1F2D` only for errors or over-21 states;
- blue `#245B78` for neutral information.

Every selected card, choice, or number uses a brass outline plus a checkmark or Selected label. Color never carries meaning alone. Probability values use monospaced digits. Table cards use an ivory face and simple geometric decoration. Motion is limited to 160–240 ms reveal/fade transitions and is removed under Reduce Motion. There is no repeated pulsing, bouncing, confetti, flashing, reel motion, or artificial result delay.

## Data Flow

1. The player selects a table from the shared catalog.
2. The platform controller creates an empty table-specific request or poker state; no outcome exists yet.
3. The player makes the required choice or hold selection.
4. An explicit action asks the controller for a fresh seed and calls the appropriate shared engine.
5. The shared engine validates the request, consumes deterministic random values, and returns a terminal observation with exact probability disclosure.
6. The platform view renders only that observation, announces the result, and moves focus to the explicit next action.
7. New Round clears the terminal observation and waits for input. Reset Session clears all in-memory Casino state. Leave Game dismisses the Casino.

No app service, network call, advertisement, purchase state, account, leaderboard, or persistent history participates in this flow.

## Errors and Recovery

- Invalid selections remain on the current pre-round screen with a plain explanation and no RNG consumption.
- Engine failures preserve the previous visible state and present a retryable error; they never substitute a random outcome.
- Poker rejects invalid card indices and a second Draw without changing the hand.
- Random seed creation failure is not expected from `SystemRandomNumberGenerator`; deterministic test seed sources still fail closed when exhausted.
- Existing Blackjack persistence remains isolated and unchanged in this pass. Reset Session starts a fresh Blackjack session only after explicit confirmation and removes only its local practice save.
- Switching games during an active Blackjack hand uses the existing neutral End Hand path before clearing the view.

## Accessibility

- VoiceOver announces table title, phase, choices, result, exact probability and assumptions, and the consequences of Reset Session and Leave Game.
- Card labels speak rank and suit. Hidden Blackjack information remains “Face-down card.”
- Every touch action is at least 44 by 44 points.
- Dynamic Type at accessibility sizes keeps all safety copy and primary actions reachable.
- Differentiate Without Color adds symbols and text to all selected/result states.
- Reduce Motion removes travel, scale, and animated gradients without removing state changes.
- macOS keyboard traversal reaches every interactive element with a visible focus ring.

## Test Strategy

The work follows red-green-refactor in three isolated lanes.

### Shared package

- Catalog test proves exactly 11 unique stable IDs and complete rules/probability disclosures.
- Every compact game has deterministic fixtures and exact integer-fraction assertions.
- Card games prove deck conservation and no duplicate cards.
- Dice/wheel/coin enumerators prove outcome-space counts rather than relying on simulations.
- Number Draw proves unique selection/draw and all four hypergeometric fractions sum to one.
- Poker fixture tests cover every category, ace-low straight, hold replacement, conservation, invalid actions, and deterministic replay.
- Safety tests reflect over public models and source terms to prevent an economy or automatic-play field from entering the shared module.

### iPhone/iPadOS

- Source/policy tests prove all 11 routes, 44-point targets, compact and regular layouts, explicit leave/reset controls, no automatic next round, reduced-motion and non-color cues, and no ad surface inside Casino play.
- Focused session tests use deterministic seeds for selection, result, reset, and table-switch behavior.
- Simulator builds and launches cover iPhone portrait, iPad portrait, and iPad landscape/regular width.

### macOS

- Source/policy tests prove all 11 routes, stacked/split layouts, keyboard hints, focus ring, explicit leave/reset controls, and no automatic continuation.
- Focused session tests mirror the deterministic mobile behavior.
- A no-sign build plus installed local app launch covers narrow and wide window states.

### Final gate

Run the full shared package suite, focused Casino suites, strict Mac/iOS parity check, iPhone simulator build/launch, iPad simulator build/launch, and macOS build/install/launch. Visually inspect at least one compact random table, Five-Card Draw, and Blackjack on all three form factors. Static-scan production Casino source for prohibited economic, pressure, advertising, timer, and auto-play dependencies.

## Store and Release Boundary

This implementation pass does not change version/build numbers, upload a binary, or alter the current review submission. Before the expanded Casino is submitted, App Store Connect age-rating answers must honestly reflect frequent simulated gambling. Apple's current rating definitions place frequent simulated gambling in the 18+ chance-based-activities tier on current operating systems; metadata must still emphasize practice, transparent probability, no money, and no transferable value.

## Non-Goals

- Real-money gaming, purchases, prizes, currency, redemption, or wallet integration.
- Persistent results, daily challenges, streaks, leaderboards, achievements, social pressure, or unlocks.
- Slots, weighted reels, pity systems, jackpots, fake near misses, or autoplay.
- Online multiplayer or spectator tables.
- Baccarat, Craps, Bingo, or Monopoly in this four-hour pass.
- Replacing or weakening the existing audited Blackjack engine.
- Uploading or submitting a new App Store build without a separate release instruction.
