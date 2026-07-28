# Prismet Fair Play Expansion Design

**Status:** Approved by Sage with “green” on 2026-07-14

**Platforms:** iOS, iPadOS, macOS

**Initial games:** Euchre, Lantern Exchange, Practice Blackjack, Five-Card Poker

**Delivery shape:** Shared deterministic rules first, followed by parallel platform-native vertical slices

**Product promise:** Classic table play without money, wagering, manipulative odds, or loss-chasing systems

## Supersession Contract

This design is the current authority for Prismet’s new card, property-strategy, and Casino work. It supersedes every economy or retention mechanic in `2026-07-14-prismet-full-parity-casino-parlor-design.md`, including:

- Parlor Tokens, balances, stakes, debits, payouts, refills, and ledgers;
- token-enabled Catan, Chess, or Reversi;
- wager/return configuration and settlement recovery;
- jackpot, pity, payout, near-miss, or loss-chasing behavior;
- ambient spectator pressure, recent-table feeds, or auto-next-hand loops;
- competitive rankings or profile statistics based on Poker or Blackjack outcomes.

The earlier design remains useful only for its cross-platform parity principles, shared-rule boundaries, native Apple presentation, accessibility requirements, Catan ownership boundary, and build/release discipline. Where the documents conflict, this Fair Play design wins.

## Outcome

Prismet grows into a broader Apple-platform game cabinet while remaining calm, honest, and safe:

- iPhone, iPad, and Mac use the same deterministic rules for every new game;
- Euchre becomes the first shared partnership card game;
- Lantern Exchange supplies an original property-trading strategy game without copying a commercial board, artwork, terminology, or bankruptcy loop;
- Casino becomes a dedicated product destination for practice table games, not an economy;
- Practice Blackjack and Five-Card Poker use disclosed rules and auditable shuffles;
- players can inspect odds, replay a completed hand, and verify the session seed without being encouraged to chase a result;
- small accessibility and recovery fixes improve existing games alongside the expansion;
- active Catan, App Store, and Illuminated Cabinet work remains untouched until its owners release the relevant files.

## Success Criteria

The first program is complete when:

1. `PrismetShared` owns stable card identities, unbiased deterministic randomization, replay records, versioned game-state envelopes, and the four new pure rules engines.
2. Identical ruleset versions, seeds, and command sequences produce identical state hashes on iOS and macOS.
3. Euchre is playable solo with one human and three bots on iPhone, iPad, and Mac.
4. Lantern Exchange is playable solo with bots and locally with two to four players on all three form factors.
5. Casino is a distinct destination containing Practice Blackjack and Five-Card Poker, with no balances, chips, tokens, stakes, purchases, payouts, prizes, streaks, leaderboards, urgency, or automatic next hand.
6. Every Poker and Blackjack session exposes its ruleset, fairness explanation, and completed-hand replay/audit information.
7. iPhone uses a focused touch layout, iPad uses regular-width layouts rather than stretched phone screens, and Mac supports pointer, keyboard, focus, resizing, and menus where appropriate.
8. Existing saves, canonical IDs, account identity, Catan behavior, and release files are not migrated or renamed by this program.
9. Shared tests, focused platform tests, iPhone/iPad builds, the macOS no-sign build, strict parity checks, and representative accessibility smokes pass before a release claim.

## Product Principles

### Fair does not mean fabricated 50/50 outcomes

Poker and Blackjack cannot make every hand exactly 50/50 without changing their rules or manipulating the deck. Prismet defines fair play as:

- an unbiased shuffle independent of prior wins, losses, session length, profile data, or selected actions;
- one published ruleset per released mode;
- no hidden difficulty or outcome adjustment;
- no economic advantage attached to an outcome;
- factual probabilities calculated from the visible state and stated assumptions;
- deterministic replay that reproduces the completed session exactly;
- neutral result language and an explicit stop after each completed hand.

### No simulated economy

Casino models contain no currency-like quantity. Production code must not introduce balances, wagers, stakes, payouts, jackpots, purchasable deals, ad-gated hands, reward meters, streak counters, countdowns, or loss-recovery prompts.

Ordinary game state may still contain rules-native scores such as Euchre match points or Lantern Exchange influence. Those values exist only to determine the current board game and cannot be purchased, transferred, redeemed, or carried into Casino.

### Shared behavior, native presentation

Game rules, randomization, legal actions, bots, replays, and save payloads are shared. Navigation, layout, animation, accessibility composition, lifecycle integration, and input mapping remain platform-native.

## Product Structure

### Cabinet and Casino

Prismet gains two primary destinations:

- **Cabinet** — the existing categorized collection of puzzles, board games, cards, workshop tools, and lenses.
- **Casino** — a focused practice-table destination containing Blackjack and Poker, rules/fairness information, and the current or most recently completed hand audit.

The Casino implementation starts as an additive destination so its rules and views can be built without touching the active Illuminated Cabinet shell. After that lane releases, mobile navigation becomes a top-level Cabinet/Casino tab structure. On macOS, Casino appears as a first-class sidebar destination because a bottom tab bar is not native to the desktop layout.

No existing game is duplicated into Casino. Catan, Chess, Reversi, Solitaire, Spider, Crazy 8, and Euchre remain Cabinet games with their existing or new canonical IDs.

### First game set

| Game | Canonical ID | Category | Initial modes | Competitive services |
| --- | --- | --- | --- | --- |
| Euchre | `euchre` | Cards | Solo bots | No leaderboard or online mode in the first release |
| Lantern Exchange | `lantern-exchange` | Board | Solo bots, local 2–4 players | No leaderboard or online mode in the first release |
| Practice Blackjack | `blackjack` | Casino | Solo practice hand | No economy, leaderboard, profile stats, or online mode |
| Five-Card Poker | `poker` | Casino | Solo practice against a disclosed fixed-policy opponent | No economy, leaderboard, profile stats, or online mode |

`Lantern Exchange` is the shipping display name and `lantern-exchange` is the permanent save ID for this design. A routine pre-release trademark review may adjust store-facing copy, but the canonical ID must never change after saves ship.

## Shared Architecture

`shared/PrismetShared` expands from metadata into focused Foundation-only modules. It does not become a UI package.

### Shared primitives

- **FeatureCatalog** — canonical IDs, categories, platform dispositions, and capability flags.
- **PlayingCards** — stable rank, suit, and card identifiers; 24-card and 52-card deck factories.
- **DeterministicRandom** — versioned generator plus rejection-sampled bounded values and Fisher–Yates shuffle.
- **GameCommandRecord** — typed command envelope with sequence number and actor seat.
- **GameEventRecord** — engine-emitted event envelope with sequence number and state hash.
- **GameReplay** — ruleset version, randomizer version, seed, accepted commands, emitted events, state hashes, and final outcome.
- **VersionedGameState** — canonical game ID, rules version, payload version, encoded payload, and modification metadata.
- **MigrationRegistry** — explicit per-game readers for supported older payload versions.

### Engine contract

Each engine is a pure value-type state machine:

1. The platform creates or restores a versioned state.
2. The view asks the engine for legal commands for the active seat.
3. A human or bot selects one typed command.
4. The engine validates the command without mutation.
5. An accepted command returns a new state and canonical events.
6. The session appends the command, events, and resulting state hash to its replay.
7. The platform persists through its existing local/cloud adapter.

Views never calculate winners, legal actions, card order, bot moves, odds, or scores independently.

### Randomization and audit

The randomizer has an explicit algorithm version. Bounded draws use rejection sampling rather than modulo reduction, and shuffles use the shared Fisher–Yates implementation.

Normal play obtains a seed from the platform’s secure random source. The complete seed and future hidden-card sequence remain concealed until the hand or match ends. After completion, Replay & Fairness may reveal the seed, ruleset version, ordered commands, draw events, and state hashes. Replaying must reproduce the same outcome; an algorithm or ruleset mismatch fails closed with an explanatory message.

Replay exports contain no account ID, profile data, device identifier, purchase data, or unrelated save content.

### Persistence compatibility

iOS keeps its current `GameSaveRecord`, `GameSaveCodec`, `PersistedGameSession`, local path, and optional cloud transport. macOS keeps its current persistence location and window/session integration. Platform adapters store the new `VersionedGameState` as their payload rather than replacing the outer storage systems.

Existing games and saves are not bulk-migrated. The new engines begin at rules version 1 and payload version 1. Unsupported future versions show a non-destructive update-required state; corrupt payloads are preserved for diagnosis and offer Start Fresh rather than being silently overwritten.

## Euchre Design

### Initial ruleset

- Four fixed clockwise seats in two partnerships: seats 0/2 versus 1/3.
- A 24-card deck containing 9 through Ace.
- Five cards per player with a kitty and turned upcard.
- Two bidding rounds: order up the upcard suit, then call another suit after all pass.
- Right and left bowers follow standard trump ordering and effective-suit rules.
- Players must follow the effective led suit when able.
- The maker team scores 1 for three or four tricks, 2 for a march, and defenders score 2 for a euchre.
- First to 10 match points wins.
- Initial configuration uses stick-the-dealer after a passed second round so bot games do not stall.
- Loner hands are excluded from the first playable slice and can be added later as a versioned rules option.

### Modes and bots

The first release is one human at seat 0 with three deterministic bots. Bot decisions receive only information legally visible to their seat and a separate derived decision seed. Tests verify that a bot cannot inspect hidden hands or future deck order.

Local four-player pass-and-play and online partnership play are not inferred from the existing two-player match system. Pass-and-play may follow after the solo slice proves hidden-hand transitions; online Euchre requires a separate reconnect, privacy, and four-seat lobby design.

### State phases

`deal → firstBid → secondBid → dealerDiscard → trickPlay → handScoring → nextHand → matchComplete`

Deal, scoring, and phase advancement are engine-generated transitions. Player commands are limited to bidding, discarding, playing a legal card, and confirming the next hand.

## Lantern Exchange Design

Lantern Exchange is a clean-room property and route strategy game, not a branded-board recreation.

### Identity

- Board: three concentric rings of ten districts connected by six radial interchanges.
- Theme: nocturnal civic cartography, brass route lines, stained-glass lantern markers, and inked district maps.
- Vocabulary: district, charter, works, route permit, exchange, influence, and civic project.
- Explicit exclusions: no copied square perimeter, railroads, utility pairs, color-set names, chance/community copy, rent tables, jail loop, player elimination, or bankruptcy objective.

### Initial ruleset

- Two to four players; solo fills empty seats with deterministic bots.
- Each turn rolls two route dice. The player chooses one die for ring movement and may use the other to activate an interchange, district action, or project contribution when legal.
- Unchartered districts can be claimed by spending influence.
- A chartered district can receive up to two works, increasing its route benefit and project contribution.
- Landing on another player’s district grants that owner influence but never creates debt or removes a player.
- Players may make one voluntary charter or route-permit trade at the beginning of their turn.
- Public civic projects request combinations of district types and works. Completing three civic projects wins immediately.
- If no player completes three projects after 18 rounds, completed projects break ties before total influence.
- All players remain active until the game ends.

### Bots and testability

Bots use an explicit strategy tier and choose only from public legal commands. A deterministic fixture must be able to drive a complete two-, three-, and four-player game to a legitimate winner without an infinite loop.

## Casino Design

### Practice Blackjack ruleset

- One standard 52-card deck, reshuffled before each independent practice hand.
- Player acts first with Hit or Stand.
- Dealer stands on all 17s, including soft 17.
- A two-card natural 21 beats a non-natural 21.
- Equal final values are a tie.
- Split, double, insurance, surrender, side bets, and multi-hand play are excluded from version 1.
- The dealer follows the published rule without regard to player history or session outcome.

The interface explains hard/soft totals, currently visible remaining-card counts, and bust probability for Hit. It does not present a generic guaranteed “win chance.”

### Five-Card Poker ruleset

- One player and one fixed-policy opponent receive five cards from one 52-card deck.
- The player may exchange zero through three cards once.
- The opponent uses a published deterministic hold policy based only on its hand classification.
- Standard five-card hand categories and kicker comparisons determine the result.
- There is no betting round, pot, blind, chip stack, payout, or bankroll.
- A completed hand stops on a neutral result screen with New Hand, Replay, Rules, and Leave actions.

The interface shows the player’s current classification and factual outs for improving to named categories. Any opponent-outcome estimate must state the fixed-policy and unseen-card assumptions beside it.

### Fair Play panel

Before the first hand, both games show:

- “No money, purchases, wagering, prizes, or rewards.”
- the exact ruleset name and version;
- shuffle algorithm and randomizer version;
- dealer or opponent policy;
- what the displayed probabilities do and do not mean;
- a link to Rules & Fairness.

After a completed hand, Replay & Fairness shows the seed, command timeline, revealed draw order, state-hash verification, and a replay action. Hidden information remains hidden while the hand is active.

### Interruption and recovery

- Backgrounding, termination, or window closure saves the current deterministic state atomically.
- Reopening offers Resume Hand, End Hand, and Rules & Fairness.
- Resume never redeals or changes the remaining deck.
- End Hand records an abandoned result without a win/loss framing.
- A corrupt or unsupported save offers Preserve Diagnostic Copy and Start Fresh.
- Completion never starts another hand automatically.

## Platform Adaptation

### iPhone

- Cabinet and Casino become the two primary destinations after the active shell lane releases.
- Casino uses compact table cards, full-screen play, thumb-reachable actions, and sheets for rules/audit details.
- Cards and controls reflow for Dynamic Type and never require landscape.

### iPadOS

- Regular-width Casino uses a table list with a live rules/preview panel.
- Active games use a two-region layout: table state and action/rules sidebar.
- Portrait and landscape preserve readable card sizes and line lengths rather than stretching an iPhone column.

### macOS

- Casino is a sidebar destination with Blackjack and Poker children or table cards.
- Every action supports keyboard and pointer input, visible focus, Escape/back behavior, and resizable narrow/standard/wide layouts.
- Rules & Fairness may use an inspector or sheet without hiding the current table state.
- No mobile ad, haptic, or touch-only assumptions are copied to Mac.

## Rough-Edge Workstream

These improvements are independent of the shared game foundation and may proceed in parallel after exact file claims:

1. Convert iOS profile emoji/color gestures into native buttons with selected traits, spoken color names, and 44×44 touch regions.
2. Add semantic tile state, error announcements, and Reduce Motion behavior to Wordgame.
3. Add row, column, occupant, selection, and legal-move semantics to iOS Checkers cells.
4. Add visible keyboard focus, tile position/value labels, and Reduce Motion behavior to macOS Sliding Puzzle.
5. Add value, given/editable, selected, and conflict semantics to macOS Sudoku cells.
6. Add descriptive loading, adjacent retry, and useful empty-state copy to macOS leaderboards.

This workstream excludes Home/catalog layouts, shared visual tokens, Catan files, App Store files, and any file actively claimed by the Illuminated Cabinet or Catan lanes.

## Accessibility

- Every card has a spoken rank and suit; hidden cards announce only “face-down card.”
- Suit meaning never depends on red/black color alone.
- VoiceOver order follows turn and trick order, with decorative table art hidden.
- All legal actions are native controls with labels, values, hints where useful, and selected/disabled traits.
- Dynamic Type reflows rules, action panels, and result screens without clipping.
- High Contrast strengthens card edges, focus, selection, and board boundaries.
- Reduce Motion removes shakes, flips, particle effects, parallax, and scale travel while preserving state changes.
- Reduce Transparency replaces translucent surfaces with opaque semantic materials.
- Mac supports full keyboard play and visible focus for every required action.
- Odds are spoken with their assumptions and do not rely on visual charts alone.

## Error Handling

- Invalid commands return a typed reason and cannot mutate state or consume random values.
- Replay mismatch identifies the first mismatched command/event and refuses to claim verification.
- Unsupported rules or randomizer versions show an update-required message without overwriting the save.
- Missing art falls back to a canonical glyph and accessibility label.
- Cloud failure does not block offline play; local state remains authoritative until the existing sync adapter succeeds.
- A failed local write keeps the in-memory state visible and offers retry or safe exit.
- Bot failure falls back to a deterministic legal-command selector and records the fallback in the replay.

## Testing Strategy

### Shared package

- unique and stable canonical IDs;
- 24-card and 52-card deck integrity;
- rejection-sampling boundaries and deterministic Fisher–Yates fixtures;
- same-seed, same-command replay equivalence;
- Codable round trips and supported migration fixtures;
- illegal-command non-mutation and randomizer non-consumption;
- Euchre bowers, follow-suit, bidding, trick winners, scoring, and full bot matches;
- Lantern Exchange movement, claiming, works, trades, projects, tie breaks, and complete bot games;
- Blackjack soft/hard totals, naturals, dealer policy, busts, ties, and interruptions;
- Poker every hand category, wheel straight, kickers, exchanges, ties, fixed bot policy, and outs;
- bot hidden-information visibility tests;
- replay state-hash tamper detection;
- model scans confirming no Casino economy or retention fields.

### Platform targets

- catalog/category and route coverage for each additive ID;
- save isolation and restore behavior;
- Fair Play disclosure copy and reachability;
- no automatic next-hand transition;
- interruption, corrupt-save, and replay-unavailable states;
- accessibility labels and control traits;
- iPhone compact, iPad regular-width, and Mac narrow/wide layout contracts;
- Mac keyboard/focus behavior.

### Verification gates

1. `swift test` in `shared/PrismetShared`.
2. XcodeGen regeneration in both app directories after source additions.
3. Focused iOS model/view-contract tests, followed by the full reliable iOS suite.
4. iPhone simulator build and iPad simulator build in portrait and landscape destinations.
5. Focused macOS tests plus a Debug build with signing disabled.
6. `ios/scripts/check-mac-ios-parity.sh --strict` from the iOS directory.
7. Visual inspection in Dark, Parchment, and High Contrast with large text and Reduce Motion.
8. Keyboard-only Mac smoke and VoiceOver smoke on representative game states.
9. Physical iPhone/iPad install and launch when available; App Store upload or submission remains separately authorized.

## Parallel Delivery and Dependencies

### Foundation gate

The shared primitives, feature IDs, randomizer, replay envelope, and persistence adapters land first because all four games consume them.

### Parallel implementation lanes after the gate

- **Lane A — Rough edges:** the six non-catalog accessibility/recovery slices.
- **Lane B — Euchre:** shared rules, bots, fixtures, then mobile and Mac views.
- **Lane C — Lantern Exchange:** shared rules, bots, fixtures, then mobile and Mac views.
- **Lane D — Casino:** shared Blackjack/Poker rules and fairness audit, then the additive Casino destination and platform views.

Within each game lane, iPhone/iPad presentation and macOS presentation may proceed in parallel only after shared golden fixtures are green. Registry and root-navigation files receive a short, coordinated integration claim after the active Catan and Illuminated Cabinet owners release them.

## Coordination Boundaries

- **Catan:** all `Catan*` source, Catan registration, screenshots, and macOS parity files remain owned by the active Catan lane.
- **App Store:** `ios/project.yml`, listing copy, screenshot harness/assets, archive/upload, public name, and review submission remain owned by the active release lane.
- **Illuminated Cabinet:** shared design tokens, Home/catalog facelift, and shell/sidebar surfaces remain owned by that lane until released.
- **The Long Now:** remains a read-only inspiration source; no Godot source, runtime, saves, or token economy is copied into Prismet.
- **Shared integration hotspots:** `PrismetFeatureManifest`, iOS `CanonicalGameID`/snapshots/Home routes, macOS `FacetRegistry`/`ContentView`, and parity docs require exact PRISM claims immediately before edits.

Every implementation lane must append its owned files to `docs/AGENT-COORDINATION.md`, re-read claimed files immediately before editing, stage only owned paths, and record tests/builds when releasing the claim.

## Rollout

1. Shared deterministic foundation and cross-platform golden fixtures.
2. Safe rough-edge fixes in non-contended files.
3. Euchre vertical slice on iPhone, iPad, and Mac.
4. Practice Blackjack and Five-Card Poker vertical slices plus additive Casino destination.
5. Lantern Exchange vertical slice on all platforms.
6. Final Cabinet/Casino navigation integration after shell claims release.
7. Full parity, accessibility, device, metadata, and release-readiness verification.

Each stage must remain buildable and may ship independently. No feature implementation implicitly authorizes an App Store upload, metadata change, regional availability change, or submission.

## Explicit Non-Goals

- Real-money play, prizes, sweepstakes, cash value, or transferable value.
- Play-money balances, chips, tokens, wagers, stakes, payouts, jackpots, refills, or ledgers.
- Streaks, daily rewards, countdown pressure, near-miss messaging, loss recovery, or automatic next hands.
- Casino leaderboards, win/loss profile statistics, or online Casino play.
- Slots, wheels, pity systems, or other chance-only reward loops in this program.
- Copying a protected property-trading game’s name, board, art, copy, space sequence, or elimination economy.
- Four-player online Euchre in the first release.
- Replacing existing save IDs or bulk-migrating unrelated games.
- Editing through active Catan, App Store, or Illuminated Cabinet claims.
- Embedding the Godot runtime or importing The Long Now saves.
- Uploading or submitting a build without a separate explicit release order.
