# Prismet Catan Quick Adventurer Design

**Status:** Approved by Sage on 2026-07-15

## Outcome

Prismet's iOS Catan game gains an optional, offline level-1 character creator named **Quick Adventurer**. A completed character personalizes the human player's name and crest in newly started matches and supplies short, deterministic **Hero's Counsel** based on visible Catan state. The integration does not alter Catan rules, odds, resources, trades, placements, bots, victory points, or hidden information.

## Market-informed product choices

The first slice adopts interaction patterns that are common in current builders while keeping all Prismet code, copy, layout, and presentation original:

- D&D Beyond Quickbuilder: large choices, smart defaults, optional depth, and prevention of common level-1 mistakes.
- Roll20 Charactermancer: guided steps and visible progress.
- PrismScroll and Fight Club 5e: offline ownership, mobile readability, local editing, and resumable work.

No external code, text, artwork, screenshots, datasets, trade dress, or extracted compendium content enters the repository.

## First-release scope

Quick Adventurer supports:

- level 1 only;
- the 12 SRD 5.2.1 class names: Barbarian, Bard, Cleric, Druid, Fighter, Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock, and Wizard;
- the nine SRD 5.2.1 species names: Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling, Human, Orc, and Tiefling;
- the four SRD 5.2.1 background names: Acolyte, Criminal, Sage, and Soldier;
- the standard ability array `15, 14, 13, 12, 10, 8`;
- class-smart default assignment with manual value swapping;
- a player-entered name and one of six original Prismet crests;
- a five-step guided flow with automatic local draft persistence;
- a compact review sheet, rules attribution, edit, and delete/reset behavior;
- one active character with a stable UUID, leaving room for a future character library.

Explicit non-goals are spells, spell slots, subclasses, feats, equipment, proficiencies, derived combat statistics, PDF export, cloud sync, remote accounts, homebrew import, multiplayer effects, and mechanical Catan powers.

## Creator journey

The creator is a sheet opened from Catan. It never blocks standard play.

1. **Calling** — choose a class from large cards. Selecting a class applies its recommended standard-array order unless the player has manually customized scores.
2. **Origin** — choose species and background from separate card groups.
3. **Abilities** — review six ability rows and swap assigned values. The creator accepts only a permutation of the standard array.
4. **Identity** — enter a trimmed name of 1–24 user-perceived characters and select a crest.
5. **Review** — see the final crest, level, choices, ability scores, and modifiers; open Rules & Credits; save for the next match.

The step indicator exposes the current step in text and accessibility labels. Back navigation preserves later valid choices. Closing the sheet preserves the current draft. Completing a character clears the draft and makes the character active.

## Domain model

The character domain lives under `ios/Sources/Core/Characters/` and does not depend on SwiftUI.

`CatanAdventurer` is `Codable`, `Equatable`, `Hashable`, and `Identifiable` with:

- `id: UUID`
- `schemaVersion: Int` fixed to `1`
- `name: String`
- `classChoice: CatanAdventurerClass`
- `species: CatanAdventurerSpecies`
- `background: CatanAdventurerBackground`
- `abilities: CatanAbilityScores`
- `crest: CatanAdventurerCrest`
- `level: Int` fixed to `1`

`CatanAdventurerDraft` contains the same editable choices plus `step`, `didCustomizeAbilities`, and its stable draft UUID. `CatanAdventurer.make(from:)` validates and trims the draft. Empty/overlong names and non-standard arrays return typed validation errors.

`CatanAbilityScores` has named integer fields for Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma. It exposes safe subscripting, `isStandardArray`, `modifier(for:)`, and `assigning(_ values: [Int], in order: [CatanAbility])`. Negative modifiers must use floor semantics: score 8 produces -1.

The original one-line choice summaries and SF Symbol names are computed Prismet metadata. They are not SRD prose.

## Local persistence

`CatanAdventurerStore` writes one versioned `CatanAdventurerState` JSON file under Application Support using atomic replacement. The state contains `active` and `draft`. No login or network is required.

The store accepts an injected root URL for tests. It must:

- return an empty state when no file exists;
- round-trip an active character and draft;
- save after every draft mutation;
- use stable UUID identity;
- quarantine malformed JSON beside the original file and return an empty recovery state with a user-visible recovery message;
- reject unsupported future schema versions instead of silently replacing them;
- delete only character state, never Catan saves.

The default path retains Prismet's existing legacy Application Support root convention: `Kaleidoscope/CatanAdventurer/state.json`.

## Catan integration

The only Catan model change is an additive `humanName` parameter on `CatanGame.newGame`, defaulting to `"You"`. No existing caller changes behavior unless it supplies a character name.

`CatanSnapshot` gains an optional `adventurer: CatanAdventurer?` with a custom decoder that defaults missing data to `nil`. Therefore all existing snapshots remain valid and behaviorally unchanged.

`CatanView` owns the local character store and a `matchAdventurer` value:

- At setup, the active character is applied only to the fresh unsaved match. Any local or cloud snapshot restore replaces it with the snapshot's optional character.
- Starting a new match snapshots the current active character and passes its name to `CatanGame.newGame`.
- Saving writes `CatanSnapshot(game: game, adventurer: matchAdventurer)`.
- Editing or deleting the active character never mutates the current match snapshot. It affects future matches only.
- A player with no character continues to see and play standard Catan as `You`.

The Catan screen shows a compact adventurer dock beneath the scoreboard:

- no character: explanation and `Create adventurer`;
- active but not in current match: `Ready for next match` and `Begin as <name>`;
- match character: crest, name, level/class, and Hero's Counsel;
- edit action: opens the creator with a draft copied from the active character and clearly labels that changes apply next match.

## Rules-neutral Hero's Counsel

`CatanHeroCounsel.advice(for:game:)` is a pure function returning a title and one short sentence. It reads only:

- the human player's phase, visible score, pieces, and resource counts;
- the visible board and legal action availability;
- the snapshotted character class.

Advice prioritizes the current phase first and then uses original class-flavored phrasing. It must never inspect opponents' resource dictionaries, hidden victory-point cards, development-card contents, or RNG state. It must not mutate the game. The same character and game state always produce the same advice.

Examples of the advice categories are placement diversity during setup, rolling before action, affordable settlement/city/road opportunities, legal robber movement, and a finished-game reflection. All language is advisory; no action is automatically executed.

## Visual direction

The creator uses Prismet's existing dark cabinet and illuminated-manuscript vocabulary:

- deep ink-blue `PrismetDesign` panels and warm Catan amber actions;
- jewel-tone crest medallions built from SwiftUI shapes, gradients, and SF Symbols;
- serif ceremony headings with rounded numeric statistics;
- visible progress, strong selection borders, checkmarks, and readable summaries;
- no raster images or external image dependencies.

The crest medallion is the memorable visual: it changes symbol and jewel tone with the selected crest and returns in the Catan dock.

## Accessibility

- Dynamic Type uses native text styles and layouts that wrap rather than clip.
- All interactive targets are at least 44 points.
- Selection is communicated by text/checkmark/border as well as color.
- Each choice exposes its name, original summary, and selected state to VoiceOver.
- VoiceOver order follows the five-step decision order.
- Reduce Motion replaces crest/progress movement with opacity-only changes.
- No creator or counsel behavior requires connectivity.
- The creator supports keyboard dismissal and does not trap focus.

## Licensing and credits

Only names and rules concepts available in SRD 5.2.1 are used. Prismet supplies all explanatory copy and presentation.

The following attribution must appear verbatim in the offline Rules & Credits sheet and in `ios/docs/SRD-5.2.1-ATTRIBUTION.md`:

> This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

The visible feature name is `Quick Adventurer` with the subtitle `Level 1 • 5E-compatible`. It must not claim official affiliation or use external logos, artwork, screenshots, or branded trade dress.

## Error behavior

- Invalid name: remain on Identity/Review and show an inline explanation without clearing any choice.
- Invalid standard array: remain on Abilities and offer `Restore smart assignment`.
- Disk write failure: preserve the in-memory draft and show a retryable message.
- Corrupt state: quarantine it, start with a safe empty state, and show a non-destructive recovery message.
- Unsupported future schema: show that the character was created by a newer Prismet version; do not overwrite the file.
- Rules/Credits links may open externally, but all required attribution remains readable offline.

## File boundary

Create:

- `ios/Sources/Core/Characters/CatanAdventurer.swift`
- `ios/Sources/Core/Characters/CatanAdventurerStore.swift`
- `ios/Sources/Core/Games/CatanHeroCounsel.swift`
- `ios/Sources/Features/Games/CatanAdventurerCreatorView.swift`
- `ios/Sources/Features/Games/CatanAdventurerDock.swift`
- `ios/Tests/CatanAdventurerTests.swift`
- `ios/Tests/CatanAdventurerStoreTests.swift`
- `ios/Tests/CatanHeroCounselTests.swift`
- `ios/Tests/CatanAdventurerIntegrationTests.swift`
- `ios/docs/SRD-5.2.1-ATTRIBUTION.md`

Modify narrowly:

- `ios/Sources/Core/Games/CatanGame.swift`
- `ios/Sources/Core/Games/GameSnapshots.swift`
- `ios/Sources/Features/Games/CatanView.swift`
- `docs/AGENT-COORDINATION.md`

Do not touch Home routing, `project.yml`, macOS, shared package, backend, Casino, ads, App Store metadata, entitlements, or release plumbing.

## Acceptance criteria

1. A signed-out player can create, close, resume, complete, edit, and reset a character offline.
2. The completed character uses only supported SRD choices, one standard array, a valid name, level 1, and an original crest.
3. A new Catan match displays and persists the active character's name and crest.
4. Editing the active character does not change a currently saved match.
5. Legacy Catan snapshots decode with `adventurer == nil` and preserve `You`.
6. Hero's Counsel is deterministic, visible-state-only, and rules-neutral.
7. Standard Catan remains playable without creating a character.
8. Required SRD attribution is readable offline.
9. Focused domain/store/counsel/integration tests pass, then the full iOS suite and generic iOS build pass.
10. Simulator visual QA covers creator and in-match dock on iPhone, including a large Dynamic Type pass and VoiceOver labels in source review.
