# Mookie's Arcade: Reynard's Casino Premium Game Overhaul

**Date:** 2026-07-28  
**Status:** Written design ready for final review  
**Platforms:** iPhone, iPad, macOS  
**Campaign size:** 21 games, completed and released one game at a time

## Outcome

Mookie's Arcade will contain Reynard's Casino as a cohesive casino house with 21 distinct game rooms. The lobby establishes the house identity; choosing a game opens a dedicated destination designed around that game's physical objects, gestures, pacing, reveal, and result.

The finished casino must feel like a collection of polished games rather than a catalog of probability forms. Shared house materials and characters make it coherent, while each room's composition and interaction make it immediately recognizable.

The campaign is incremental. One game is redesigned, integrated, tested, installed, visually inspected, committed, and pushed on all three platforms before the next game begins.

## Fixed Product Identity

- The product name is **Mookie's Arcade**.
- Mookie, a cute tuxedo cat in a wizard hat, is the primary arcade guide.
- The casino is **Reynard's Casino**.
- Reynard, a cute fox, is the casino host and dealer.
- Both characters are visibly present in every casino game without obstructing play.
- Prismet may appear only as a quiet studio credit such as **from Prismet**.
- User-facing **Prismet Arcade** branding is removed. Internal package and type names may remain when renaming them would add migration risk without changing the experience.

## Scope

This campaign delivers:

- a dedicated production destination for every stable casino game ID;
- a unique room, table or play surface, props, controls, motion language, and result treatment for every game;
- responsive compositions for iPhone, iPad, and macOS;
- touch-first interaction on iPhone and iPad, plus pointer and keyboard interaction on macOS;
- visible, expressive Mookie and Reynard character placement in every room;
- a consistent Reynard's Casino navigation and accessibility contract;
- immediate tri-platform release and remote push after each completed game.

Presentation and interaction may be redesigned completely. Existing shared engines remain authoritative for shuffling, dealing, rolling, spinning, choices, rules, probabilities, deterministic seeds, and restored state.

## Non-Goals and Safety Boundaries

The campaign does not add:

- real money, purchases, wallets, payouts, prizes, redeemable rewards, or wagering;
- retention mechanics such as streak pressure, countdowns, autoplay, loss chasing, or near-miss manipulation;
- outcome tuning for visual drama;
- a replacement probability engine;
- automatic store submission;
- copied third-party artwork, layouts, sound, or motion;
- a broad new audio system. Scenes may expose sound-ready event hooks, but graphics, interaction, motion, accessibility, and tasteful mobile haptics are the release focus.

The existing age threshold must run before casino session state is created. Practice-only and educational language remains visible where needed.

## Experience Architecture

### House flow

```text
Mookie's Arcade
    -> Reynard's Casino lobby
        -> choose a game
            -> dedicated game destination
                -> play / inspect rules and odds
                -> return to casino lobby
        -> leave casino
```

The lobby is not the gameplay screen. It presents the house, Reynard as host, Mookie as companion, and a clear doorway or table card for each game. Every game opens as a distinct destination with an explicit return to the lobby.

### Routing

The casino route owns a selected game ID, conceptually:

```swift
enum CasinoRoute: Hashable {
    case lobby
    case game(PrismetPracticeCasinoGameID)
}
```

Each platform maintains an exhaustive registry from the shared stable game ID to its concrete scene. Exhaustiveness is tested against `PrismetPracticeCasinoGameID.allCases`.

Migration is intentionally incremental:

1. A game keeps its legacy route until its premium scene passes the full release gate.
2. The migrated ID is switched to its dedicated scene in the integration checkpoint.
3. Remaining IDs may temporarily continue through legacy renderers while their turns are pending.
4. At campaign completion, no stable production game ID routes through the generic Blackjack, poker, chance, or study-lab shells.

The commander alone edits the shared routing registries and high-conflict hub files.

### State ownership

The shared package remains the source of truth for:

- the catalog and stable IDs;
- rules and probability disclosures;
- decks, dice, wheels, draws, and deterministic random sources;
- legal actions and phase changes;
- result classification;
- persistence and recovery.

Platform scenes own presentation-only state such as:

- card positions and face orientation;
- drag offsets and hover focus;
- dice anticipation and settling;
- wheel rotation needed to display an already-selected result;
- character pose;
- transient particles, highlights, banners, and camera emphasis.

Presentation state never calculates, modifies, replaces, or rerolls an outcome. A gesture dispatches a typed engine action; the engine returns authoritative state; the scene choreographs that state.

```text
gesture or command
    -> typed shared action
        -> authoritative engine transition
            -> scene animation plan
                -> stable rendered state
                    -> optional rules / exact odds disclosure
```

If an animation is interrupted, backgrounded, resized, or restored, the scene reconciles to the latest authoritative state. It never issues the action again.

### Scene composition

Every dedicated destination has the same conceptual layers, with layouts tailored to the game:

1. **Room backdrop** — the game's unique place inside Reynard's Casino.
2. **Play stage** — cards, dice, wheel, draw machine, or other central object.
3. **Character layer** — Reynard hosts or deals; Mookie reacts or assists.
4. **Control rail** — clear legal actions with disabled states explained.
5. **Result layer** — an unmistakable outcome using text, shape, motion, and character response.
6. **Information drawer** — rules and exact odds available on demand, not dominating the play surface.
7. **House navigation** — game title, practice status, accessibility controls where applicable, and return to lobby.

Shared primitives may include felt and wood materials, card faces, chip-free markers, character framing, result banners, information drawers, and reduced-motion transitions. Shared primitives must not force all rooms into the same layout.

## Per-Game Premium Contract

A game cannot pass merely because it uses a new background. Each migrated game must provide:

- a dedicated scene type and dedicated production route;
- a recognizable environment and prop language;
- controls arranged around the game's actual decisions;
- at least one game-specific direct interaction where it improves clarity;
- authored dealing, rolling, spinning, drawing, holding, splitting, or street-reveal choreography;
- a result presentation specific to the game's outcome vocabulary;
- visible Mookie and Reynard poses that respond to play without covering cards or controls;
- rules and exact odds in a secondary disclosure;
- no dependency on color alone for suits, choices, state, or results;
- Dynamic Type without clipped decisions or concealed results;
- useful VoiceOver labels, values, hints, order, and result announcements;
- a complete Reduce Motion path that lands directly on the authoritative final state;
- touch targets of at least 44 by 44 points on iPhone and iPad;
- keyboard traversal, activation, escape/back behavior, pointer feedback, and resizable layout on macOS;
- original or properly vetted visual assets.

The scene must remain understandable at the smallest supported phone size, both representative tablet orientations, and a compact and expanded Mac window.

## Sequential Room Roster

This is the release order. It deliberately establishes reusable card language first, expands through multi-card and study tables, then develops dice, wheel, and draw primitives. Only one row may be in flight.

| Order | Stable ID | Room direction | Signature interaction and reveal |
|---:|---|---|---|
| 1 | `blackjack` | **Practice Blackjack — Reynard's Grand Table:** deep emerald semicircular felt, walnut dealer rail, shoe and discard tray, warm brass task lights | Cards travel from the shoe; Hit and Stand live on the rail; Mookie tracks the learner hand while Reynard conducts the dealer reveal |
| 2 | `five-card-draw` | **Five-Card Draw — Velvet Draw Room:** plum felt, fan-shaped card alcove, stitched hold markers | Tap or drag cards into a held row, then pull the draw control for a single replacement sweep |
| 3 | `high-card` | **High Card — Foxfire Showdown:** intimate two-seat table, mirrored card pools, amber foxfire edge light | Drag one sealed card to each crest and tap the center seal for a synchronized flip |
| 4 | `red-black` | **Red or Black — Scarlet Gallery:** lacquered red and charcoal panels, oversized prediction plaques | Slide Mookie's marker to a color plaque, then let Reynard turn one theatrical card |
| 5 | `higher-lower` | **Higher or Lower — Clockwork Stair:** vertical brass rank track and rising card pedestal | Choose a direction on the stair and swipe the next card into place for comparison |
| 6 | `casino-war-practice` | **Casino War Practice — Twin Banners Hall:** opposing card standards and a central tie bridge | Each side deals to a banner; an initial tie opens the bridge for the one allowed resolution |
| 7 | `three-card-poker-lab` | **Three-Card Poker Hand Lab — Triad Salon:** triangular inlays and compact three-card fans | Reveal paired three-card fans, then focus category lines as the comparison resolves |
| 8 | `texas-holdem-lab` | **Texas Hold'em Hand Lab — Community Table:** long oval felt, five illuminated board sockets, private card wings | Advance flop, turn, and river from a street rail; the chosen best five receives a clear outline |
| 9 | `caribbean-stud-qualification-lab` | **Caribbean Stud Qualification Lab — Island Conservatory:** teal glass, warm cane details, reference-hand display | Deal two five-card spreads and lift the reference shield to stage qualification and comparison |
| 10 | `pai-gow-split-lab` | **Pai Gow Split Lab — Lantern Partition Room:** red lacquer dividers and two bordered hand zones | Drag exactly two cards to the low hand; the remaining five settle into the high hand before validation |
| 11 | `omaha-hand-lab` | **Omaha Hand Lab — Riverstone Table:** slate-blue felt, four-card hand dock, stone board channel | Select exactly two hole and three board cards; legal selections join in a five-card evaluation ribbon |
| 12 | `mini-baccarat-practice` | **Mini-Baccarat Outcome Lab — Moonlit Tableau:** midnight blue cloth, ivory tableau lanes, restrained gold phase track | Advance one explicit tableau phase at a time while Reynard places each rule-directed card |
| 13 | `coin-call` | **Coin Call — Brass Observatory:** round celestial table with a suspended engraved coin | Drag the coin downward to charge the toss, release it, and watch it settle on the authoritative face |
| 14 | `dice-duel` | **Dice Duel — Mookie's Dice Dock:** two velvet dice cups and opposing illuminated trays | Shake or activate the paired cups; dice tumble into separate trays and compare in the center |
| 15 | `over-under-seven` | **Over or Under Seven — Seven Bridges:** arched number bridge with below and above landing zones | Place a prediction marker on one side, roll two dice, and light the sum's bridge position |
| 16 | `odd-even` | **Odd or Even — Parity Parlor:** checkerboard floor, paired parity crests, sum pedestal | Choose a crest, cast two dice, and route the resulting total through the matching patterned lane |
| 17 | `craps-point-lab` | **Craps Point Lab — Point Workshop:** educational rail with come-out and point mechanisms | Roll into a tactile tray; the puck-like lesson marker moves between come-out, point, and resolution states |
| 18 | `sic-bo-outcome-lab` | **Sic Bo Outcome Lab — Triple Lantern Room:** three covered dice under a translucent lantern dome | Lift the dome after the three-die tumble; total and pattern illuminate as separate readable results |
| 19 | `fair-wheel` | **Fair Wheel — Ivory & Emerald Rotunda:** twelve equal architectural segments and a fixed brass pointer | Swipe or activate the wheel; it animates to the already-selected equal segment and names number plus color |
| 20 | `european-roulette-lab` | **European Roulette Lab — Single-Zero Gallery:** full 37-pocket wheel, museum-style probability display | Spin from the rim; the ball settles in the authoritative pocket while red, black, and zero classification appears |
| 21 | `number-draw` | **Number Draw — Twelve-Door Vault:** twelve numbered cabinet doors and a three-slot selection tray | Place exactly three choices in the tray, turn the vault handle, and open three authoritative drawn doors |

## First Release: Game 01

The opening release establishes the quality and architecture template:

- an immersive, responsive semicircular felt table rather than a vertical form;
- a real dealer rail, card shoe, discard tray, hand zones, and legible cards;
- Reynard positioned as the active dealer;
- Mookie positioned beside the learner hand as guide and expressive companion;
- authored opening deal, player Hit, Stand, dealer hole-card reveal, dealer draw, and final comparison;
- a result banner that remains readable after motion completes;
- a secondary rules-and-odds drawer;
- full touch, pointer, keyboard, VoiceOver, Dynamic Type, and Reduce Motion behavior.

This release may create reusable house chrome and card-motion primitives. Those primitives become tools for later rooms, not a universal layout.

## Legion Campaign Contract

The campaign uses the verified launcher at:

```text
/Users/gtrktscrb/Desktop/GtrktscrB/gaming/the-long-now/legion.sh
```

Each game receives its own bounded run with four contiguous assignments:

```text
TERRA COHORT I — iPhone Century
TERRA COHORT II — iPad Century
TERRA COHORT III — macOS Century
LUNA AUDIT — independent parity, safety, and evidence review
```

### Platform lanes

Each Terra Century receives:

- the approved per-game slice of this design;
- one platform and an exclusive set of new or narrowly scoped scene files;
- the existing shared engine API as a read-only contract unless the commander explicitly assigns a shared change;
- required platform tests, build command, representative viewport, and evidence artifact;
- an instruction not to commit, push, or edit generated project files.

The iPhone lane owns the compact touch composition. The iPad lane owns the larger touch composition in both representative orientations. The macOS lane owns resizable layout, keyboard, pointer, hover, focus, and native window behavior.

### Commander-only integration

The commander owns:

- coordination records and file leases;
- shared package edits;
- casino hub and route registries;
- high-conflict navigation and app entry files;
- project-generation inputs and generated project refreshes;
- cross-platform integration;
- final tests, builds, installs, launches, and screenshots;
- the per-game commit and push.

Workers do not modify ignored or generated project files. The commander regenerates projects once after accepted platform changes so Century receipts describe only durable source.

### Independent audit

The Luna audit begins read-only and checks:

- the migrated stable ID reaches a dedicated scene on all platforms;
- the three scenes express the same rules, legal actions, phases, and authoritative result;
- no presentation code chooses or changes an outcome;
- Mookie's Arcade and Reynard's Casino branding is correct;
- both characters are visible and nonblocking;
- the scene is distinguishable from already migrated rooms;
- accessibility and reduced-motion paths are implemented;
- evidence is complete and reproducible;
- generated, temporary, secret, and unrelated files are absent from the checkpoint.

An audit finding blocks release until resolved or explicitly descoped in a revised approved design.

## Error and Recovery Design

- An illegal or unavailable action leaves authoritative state unchanged and explains the next legal action inline.
- Rapid repeated input is ignored or coalesced while an engine transition is in flight; it never causes a second outcome.
- Backgrounding, window resizing, or interrupted animation lands on the latest authoritative state.
- Restored sessions render their current phase without replaying random actions.
- Existing corrupt-save recovery behavior for the opening card game remains intact.
- A missing decorative asset uses a themed shape-and-material fallback rather than leaving a blank or blocking play.
- Reduce Motion replaces travel, spin, tumble, and flourish with short fades, state changes, and static emphasis.
- A failed platform build, install, launch, or remote push blocks the release claim for that game.

## Per-Game Release Gate

The following gate is repeated for every row in the roster:

1. The dedicated scene and its platform adaptations are complete.
2. Focused shared-engine and regression tests pass.
3. Route coverage proves the stable ID opens the dedicated scene on all three platforms.
4. Interaction tests prove gestures and commands dispatch the intended typed actions exactly once.
5. Animation-contract tests prove motion renders authoritative state and never generates outcomes.
6. The migrated ID no longer uses a generic production renderer.
7. iPhone, iPad, and macOS builds succeed from the integrated source state.
8. The running UI is visually inspected at representative compact and expanded sizes.
9. VoiceOver labels and order, Dynamic Type, no-color cues, target sizes, keyboard behavior, and Reduce Motion are checked.
10. The signed iPhone build is installed and launched on FASCES at the migrated game.
11. `git diff --check` and source/manifest safety scans pass.
12. The exact reviewed checkpoint is committed and pushed to the tracked remote branch.
13. Coordination leases are released and the ledger records the evidence.
14. Only then may the next game begin.

The immediate release promise applies to testable builds and the tracked branch. Store submission remains a separately authorized action.

## Campaign Completion Gate

The casino overhaul is complete only when:

- all 21 stable IDs route to dedicated production scenes on iPhone, iPad, and macOS;
- no generic production gameplay route remains for a stable casino ID;
- the full shared, mobile, and macOS test suites pass;
- all three platform builds succeed from the same source checkpoint;
- parity, accessibility, reduced-motion, and practice-only safety audits pass;
- the final signed build is installed and launched on FASCES;
- the final reviewed checkpoint is present on the tracked remote branch.

## Evidence Artifacts

Every game checkpoint records:

- the stable game ID and route proof;
- focused test summaries;
- three platform build results;
- one representative screenshot per platform, plus additional sizes when the layout materially changes;
- a short interaction and accessibility checklist;
- FASCES install and launch confirmation;
- commit hash and remote branch confirmation;
- any intentional limitations approved before release.

Evidence is stored outside generated build products and must identify the exact source checkpoint it proves.

## Implementation Handoff

After this written design is approved, the next artifact is a detailed implementation plan for Game 01. That plan will identify exact source files, tests, Legion lane ownership, integration order, device commands, visual proof, commit boundaries, and rollback points. No later game begins until Game 01 has passed the complete release gate.
