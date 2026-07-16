# Prismet Catan Quick Adventurer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an optional offline level-1 Quick Adventurer creator that personalizes newly started iOS Catan matches and supplies deterministic rules-neutral Hero's Counsel.

**Architecture:** A pure Swift character domain and injected atomic file store remain independent from Catan. New matches snapshot an optional immutable adventurer into `CatanSnapshot`; a pure counsel adapter reads only public human/board state. Two SwiftUI files render the guided creator and compact in-game dock using the existing Prismet design system.

**Tech Stack:** Swift 5, SwiftUI, Foundation Codable/FileManager, XCTest, XcodeGen, iOS 17 deployment target.

## Global Constraints

- Visible product name is `Quick Adventurer`; subtitle is `Level 1 • 5E-compatible`.
- Level is exactly `1`; standard array is exactly `15, 14, 13, 12, 10, 8`; names trim whitespace and contain `1...24` user-perceived characters.
- Include all 12 SRD 5.2.1 class names, nine species names, and four background names listed in the approved spec.
- Use only original Prismet copy/presentation plus SRD 5.2.1 names and rules concepts; copy no external builder code, copy, art, data, layout, or trade dress.
- Catan mechanics are immutable: no resource, dice, trade, cost, placement, AI, hidden-information, victory-point, or win-threshold changes.
- Counsel reads no opponent resource dictionaries, hidden victory-point cards, development-card contents, or RNG state.
- Existing Catan snapshots decode with `adventurer == nil`; editing/deleting an active character affects future matches only.
- Creator and attribution work offline; local writes are atomic; malformed JSON is quarantined; unsupported future schema is never overwritten.
- Accessibility requires native Dynamic Type, 44-point targets, labels/selected state, non-color selection, VoiceOver decision order, and Reduce Motion-safe transitions.
- iOS only. Do not modify Home routing, `project.yml`, macOS, shared package, backend, Casino, ads, App Store metadata, entitlements, or release plumbing.
- Use XcodeGen; never hand-edit `Prismet.xcodeproj`.

---

### Task 1: Character domain and SRD attribution

**Files:**
- Create: `ios/Sources/Core/Characters/CatanAdventurer.swift`
- Create: `ios/Tests/CatanAdventurerTests.swift`
- Create: `ios/docs/SRD-5.2.1-ATTRIBUTION.md`

**Interfaces:**
- Consumes: Foundation only.
- Produces: `CatanAbility`, `CatanAbilityScores`, the class/species/background/crest enums, `CatanCreatorStep`, `CatanAdventurerDraft`, `CatanAdventurer`, `CatanAdventurerValidationError`, and `CatanRulesAttribution`.

- [ ] **Step 1: Write failing domain tests**

```swift
import XCTest
@testable import Prismet

final class CatanAdventurerTests: XCTestCase {
    func testSRDChoiceCountsAndNamesArePinned() {
        XCTAssertEqual(CatanAdventurerClass.allCases.map(\.displayName), [
            "Barbarian", "Bard", "Cleric", "Druid", "Fighter", "Monk",
            "Paladin", "Ranger", "Rogue", "Sorcerer", "Warlock", "Wizard"
        ])
        XCTAssertEqual(CatanAdventurerSpecies.allCases.count, 9)
        XCTAssertEqual(CatanAdventurerBackground.allCases.count, 4)
    }

    func testClassRecommendationUsesStandardArrayExactlyOnce() {
        let scores = CatanAbilityScores.recommended(for: .wizard)
        XCTAssertEqual(scores[.intelligence], 15)
        XCTAssertTrue(scores.isStandardArray)
        XCTAssertEqual(scores.values.sorted(by: >), [15, 14, 13, 12, 10, 8])
    }

    func testAbilityModifiersUseFloorSemantics() {
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 15), 2)
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 10), 0)
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 9), -1)
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 8), -1)
    }

    func testMakeTrimsNameAndLocksLevelOne() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = "  Rowan  "
        let character = try CatanAdventurer.make(from: draft)
        XCTAssertEqual(character.name, "Rowan")
        XCTAssertEqual(character.level, 1)
        XCTAssertEqual(character.schemaVersion, 1)
    }

    func testMakeRejectsEmptyLongAndNonStandardDrafts() {
        var draft = CatanAdventurerDraft.new()
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .emptyName)
        }
        draft.name = String(repeating: "A", count: 25)
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .nameTooLong)
        }
        draft.name = "Rowan"
        draft.abilities.strength = 15
        draft.abilities.dexterity = 15
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .invalidStandardArray)
        }
    }

    func testCharacterAndDraftRoundTrip() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        draft.step = .review
        let character = try CatanAdventurer.make(from: draft)
        XCTAssertEqual(try JSONDecoder().decode(CatanAdventurer.self, from: JSONEncoder().encode(character)), character)
        XCTAssertEqual(try JSONDecoder().decode(CatanAdventurerDraft.self, from: JSONEncoder().encode(draft)), draft)
    }

    func testAttributionPinsVersionSourceAndLicense() {
        XCTAssertTrue(CatanRulesAttribution.notice.contains("System Reference Document 5.2.1"))
        XCTAssertTrue(CatanRulesAttribution.notice.contains("creativecommons.org/licenses/by/4.0/legalcode"))
        XCTAssertEqual(CatanRulesAttribution.version, "5.2.1")
    }
}
```

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd ios
xcodegen generate
xcodebuild -quiet -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,id=EBA38985-AB1C-4013-9B0F-D1D3E5C4BE90' \
  -derivedDataPath ~/Library/Caches/Prismet-Catan-Adventurer-DD \
  -only-testing:PrismetTests/CatanAdventurerTests test
```

Expected: compile failure because the new character types do not exist.

- [ ] **Step 3: Implement the pure domain**

Implement this exact ability-score API:

```swift
import Foundation

enum CatanAbility: String, CaseIterable, Codable, Hashable {
    case strength, dexterity, constitution, intelligence, wisdom, charisma
    var displayName: String { rawValue.capitalized }
}

struct CatanAbilityScores: Codable, Equatable, Hashable {
    var strength: Int
    var dexterity: Int
    var constitution: Int
    var intelligence: Int
    var wisdom: Int
    var charisma: Int
    static let standardArray = [15, 14, 13, 12, 10, 8]
    var values: [Int] { CatanAbility.allCases.map { self[$0] } }
    var isStandardArray: Bool { values.sorted(by: >) == Self.standardArray }

    subscript(_ ability: CatanAbility) -> Int {
        get {
            switch ability {
            case .strength: return strength
            case .dexterity: return dexterity
            case .constitution: return constitution
            case .intelligence: return intelligence
            case .wisdom: return wisdom
            case .charisma: return charisma
            }
        }
        set {
            switch ability {
            case .strength: strength = newValue
            case .dexterity: dexterity = newValue
            case .constitution: constitution = newValue
            case .intelligence: intelligence = newValue
            case .wisdom: wisdom = newValue
            case .charisma: charisma = newValue
            }
        }
    }

    static func modifier(forScore score: Int) -> Int { Int(floor(Double(score - 10) / 2.0)) }

    static func recommended(for choice: CatanAdventurerClass) -> Self {
        var result = Self(strength: 8, dexterity: 8, constitution: 8, intelligence: 8, wisdom: 8, charisma: 8)
        for (ability, value) in zip(choice.recommendedAbilityOrder, standardArray) { result[ability] = value }
        return result
    }
}
```

The class/species/background/crest enums conform to `String, CaseIterable, Codable, Hashable, Identifiable`, use `id == rawValue`, exact display names from the spec, original one-line summaries, and SF Symbol strings. Every class defines a complete six-item `recommendedAbilityOrder` permutation.

Implement these exact draft and final-character invariants:

```swift
enum CatanAdventurerValidationError: Error, Equatable { case emptyName, nameTooLong, invalidStandardArray }

struct CatanAdventurerDraft: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var classChoice: CatanAdventurerClass
    var species: CatanAdventurerSpecies
    var background: CatanAdventurerBackground
    var abilities: CatanAbilityScores
    var crest: CatanAdventurerCrest
    var step: CatanCreatorStep
    var didCustomizeAbilities: Bool

    static func new(id: UUID = UUID()) -> Self {
        Self(id: id, name: "", classChoice: .fighter, species: .human,
             background: .soldier, abilities: .recommended(for: .fighter),
             crest: .shield, step: .calling, didCustomizeAbilities: false)
    }

    mutating func chooseClass(_ choice: CatanAdventurerClass) {
        classChoice = choice
        if !didCustomizeAbilities { abilities = .recommended(for: choice) }
    }

    mutating func swapAbilities(_ first: CatanAbility, _ second: CatanAbility) {
        let old = abilities[first]
        abilities[first] = abilities[second]
        abilities[second] = old
        didCustomizeAbilities = true
    }
}

struct CatanAdventurer: Codable, Equatable, Hashable, Identifiable {
    static let currentSchemaVersion = 1
    var id: UUID
    var schemaVersion: Int
    var name: String
    var classChoice: CatanAdventurerClass
    var species: CatanAdventurerSpecies
    var background: CatanAdventurerBackground
    var abilities: CatanAbilityScores
    var crest: CatanAdventurerCrest
    var level: Int

    static func make(from draft: CatanAdventurerDraft) throws -> Self {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CatanAdventurerValidationError.emptyName }
        guard name.count <= 24 else { throw CatanAdventurerValidationError.nameTooLong }
        guard draft.abilities.isStandardArray else { throw CatanAdventurerValidationError.invalidStandardArray }
        return Self(id: draft.id, schemaVersion: 1, name: name, classChoice: draft.classChoice,
                    species: draft.species, background: draft.background, abilities: draft.abilities,
                    crest: draft.crest, level: 1)
    }

    var editableDraft: CatanAdventurerDraft {
        CatanAdventurerDraft(id: id, name: name, classChoice: classChoice, species: species,
                             background: background, abilities: abilities, crest: crest,
                             step: .calling, didCustomizeAbilities: true)
    }
}
```

Add `CatanRulesAttribution.version`, `sourceURL`, `licenseURL`, and the approved exact notice. Put the same notice plus an original-content statement in the attribution document.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run Step 2. Expected: `CatanAdventurerTests` passes with zero failures.

- [ ] **Step 5: Commit**

```bash
git add ios/Sources/Core/Characters/CatanAdventurer.swift ios/Tests/CatanAdventurerTests.swift ios/docs/SRD-5.2.1-ATTRIBUTION.md
git commit -m "feat: add Quick Adventurer domain"
```

---

### Task 2: Offline resumable character storage

**Files:**
- Create: `ios/Sources/Core/Characters/CatanAdventurerStore.swift`
- Create: `ios/Tests/CatanAdventurerStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 domain.
- Produces: `CatanAdventurerState`, `CatanAdventurerFileStore`, `CatanAdventurerLoadResult`, `CatanAdventurerStoreError`, and `@MainActor CatanAdventurerStore`.

- [ ] **Step 1: Write failing storage tests**

```swift
import XCTest
@testable import Prismet

final class CatanAdventurerStoreTests: XCTestCase {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    func testMissingFileReturnsEmptyState() throws {
        let result = try CatanAdventurerFileStore(rootURL: root()).loadRecovering()
        XCTAssertEqual(result.state, .empty)
        XCTAssertNil(result.quarantinedURL)
    }

    func testActiveAndDraftRoundTrip() throws {
        let store = CatanAdventurerFileStore(rootURL: root())
        var draft = CatanAdventurerDraft.new(); draft.name = "Rowan"
        let state = CatanAdventurerState(active: try CatanAdventurer.make(from: draft), draft: draft)
        try store.save(state)
        XCTAssertEqual(try store.loadRecovering().state, state)
    }

    func testCorruptFileIsQuarantined() throws {
        let root = root()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("state.json"))
        let result = try CatanAdventurerFileStore(rootURL: root, now: { Date(timeIntervalSince1970: 42) }).loadRecovering()
        XCTAssertEqual(result.state, .empty)
        XCTAssertEqual(result.quarantinedURL?.lastPathComponent, "state-corrupt-42.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.quarantinedURL!.path))
    }

    func testFutureSchemaIsNotOverwritten() throws {
        let root = root(); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("state.json")
        let data = Data("{\"schemaVersion\":99,\"active\":null,\"draft\":null}".utf8)
        try data.write(to: file)
        XCTAssertThrowsError(try CatanAdventurerFileStore(rootURL: root).loadRecovering()) {
            XCTAssertEqual($0 as? CatanAdventurerStoreError, .unsupportedSchema(99))
        }
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testDeleteTouchesOnlyCharacterState() throws {
        let root = root(); let sibling = root.deletingLastPathComponent().appendingPathComponent("GameSaves/keep.json")
        try FileManager.default.createDirectory(at: sibling.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: sibling)
        let store = CatanAdventurerFileStore(rootURL: root); try store.save(.empty); try store.delete()
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
    }
}
```

- [ ] **Step 2: Run storage tests and confirm RED**

Use Task 1's command with `-only-testing:PrismetTests/CatanAdventurerStoreTests`. Expected: missing store types.

- [ ] **Step 3: Implement persistence**

```swift
import Foundation

struct CatanAdventurerState: Codable, Equatable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var active: CatanAdventurer?
    var draft: CatanAdventurerDraft?
    init(schemaVersion: Int = 1, active: CatanAdventurer? = nil, draft: CatanAdventurerDraft? = nil) {
        self.schemaVersion = schemaVersion; self.active = active; self.draft = draft
    }
    static let empty = Self()
}

struct CatanAdventurerLoadResult: Equatable { var state: CatanAdventurerState; var quarantinedURL: URL? }
enum CatanAdventurerStoreError: Error, Equatable { case unsupportedSchema(Int) }

struct CatanAdventurerFileStore {
    let rootURL: URL
    var fileManager: FileManager = .default
    var now: () -> Date = Date.init
    init(rootURL: URL = Self.defaultRootURL(), fileManager: FileManager = .default,
         now: @escaping () -> Date = Date.init) {
        self.rootURL = rootURL; self.fileManager = fileManager; self.now = now
    }
    static func defaultRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Kaleidoscope/CatanAdventurer", isDirectory: true)
    }
}
```

`loadRecovering()` first decodes `schemaVersion`; it throws `.unsupportedSchema(version)` before decoding future payloads. Malformed JSON moves to `state-corrupt-<whole Unix seconds>.json` and returns `.empty` with that URL. `save(_:)` forces schema 1, uses sorted JSON keys, creates the directory, and writes `.atomic`. `delete()` removes only `state.json`.

Add `@MainActor final class CatanAdventurerStore: ObservableObject` with published read-only `active`, `draft`, and `message`, plus `load()`, `beginDraft(editing:)`, `updateDraft(_:)`, `completeDraft() throws -> CatanAdventurer`, and `deleteActive()`. Persist every draft mutation; preserve in-memory data and set a retry message on write failure.

- [ ] **Step 4: Run domain and storage tests**

Run both focused suites. Expected: zero failures.

- [ ] **Step 5: Commit**

```bash
git add ios/Sources/Core/Characters/CatanAdventurerStore.swift ios/Tests/CatanAdventurerStoreTests.swift
git commit -m "feat: persist adventurer drafts offline"
```

---

### Task 3: Deterministic visible-state Hero's Counsel

**Files:**
- Create: `ios/Sources/Core/Games/CatanHeroCounsel.swift`
- Create: `ios/Tests/CatanHeroCounselTests.swift`

**Interfaces:**
- Consumes: `CatanAdventurer`, `CatanGame`.
- Produces: `CatanCounsel` and `CatanHeroCounsel.advice(for:game:)`.

- [ ] **Step 1: Write failing counsel tests**

```swift
import XCTest
@testable import Prismet

final class CatanHeroCounselTests: XCTestCase {
    private func character(_ choice: CatanAdventurerClass = .fighter) throws -> CatanAdventurer {
        var draft = CatanAdventurerDraft.new(); draft.name = "Rowan"; draft.chooseClass(choice)
        return try CatanAdventurer.make(from: draft)
    }

    func testNoCharacterProducesNoCounsel() {
        XCTAssertNil(CatanHeroCounsel.advice(for: nil, game: .newGame(seed: 1)))
    }

    func testSameStateProducesDeterministicCounselWithoutMutation() throws {
        let game = CatanGame.newGame(seed: 1); let before = game
        let first = CatanHeroCounsel.advice(for: try character(.wizard), game: game)
        XCTAssertEqual(first, CatanHeroCounsel.advice(for: try character(.wizard), game: game))
        XCTAssertEqual(game, before)
        XCTAssertEqual(first?.title, "Wizard's Counsel")
    }

    func testSetupCounselIsAdviceNotBonus() throws {
        let counsel = CatanHeroCounsel.advice(for: try character(), game: .newGame(seed: 2))
        XCTAssertTrue(counsel!.message.localizedCaseInsensitiveContains("settlement"))
        XCTAssertFalse(counsel!.message.contains("+1"))
    }

    func testOpponentHiddenResourcesCannotChangeCounsel() throws {
        let game = CatanGame.newGame(seed: 3)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as? [String: Any])
        var players = try XCTUnwrap(json["players"] as? [[String: Any]])
        players[1]["resources"] = ["brick": 99, "lumber": 99, "wool": 99, "grain": 99, "ore": 99]
        json["players"] = players
        let altered = try JSONDecoder().decode(CatanGame.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(CatanHeroCounsel.advice(for: try character(.rogue), game: game),
                       CatanHeroCounsel.advice(for: try character(.rogue), game: altered))
    }
}
```

- [ ] **Step 2: Run counsel tests and confirm RED**

Use Task 1's command with `-only-testing:PrismetTests/CatanHeroCounselTests`. Expected: missing counsel types.

- [ ] **Step 3: Implement the pure adapter**

```swift
import Foundation

struct CatanCounsel: Equatable { var title: String; var message: String }

enum CatanHeroCounsel {
    static func advice(for adventurer: CatanAdventurer?, game: CatanGame) -> CatanCounsel? {
        guard let adventurer else { return nil }
        let message: String
        switch game.phase {
        case .setupSettlement:
            message = "Place a settlement where strong numbers diversify the resources you can gather."
        case .setupRoad:
            message = "Point your road toward open intersections that preserve more than one expansion route."
        case .roll:
            message = "Roll first; then let the island's result shape the plan instead of spending ahead of chance."
        case .moveRobber:
            message = "Move the robber onto a productive visible number while keeping your own routes clear."
        case .build:
            message = buildAdvice(for: game)
        case .gameOver:
            message = "Read the finished island: the strongest path balanced production, reach, and timing."
        }
        return CatanCounsel(title: "\(adventurer.classChoice.displayName)'s Counsel",
                            message: flavored(message, for: adventurer.classChoice))
    }
}
```

`buildAdvice(for:)` uses only player 0 resources, public score, pieces left, and public `canAfford`; prioritize city, settlement, road, bank-trade preparation, then ending turn. `flavored(_:for:)` adds a short original prefix for each class and never claims a mechanical effect.

- [ ] **Step 4: Run counsel tests and confirm GREEN**

Run Step 2. Expected: zero failures.

- [ ] **Step 5: Commit**

```bash
git add ios/Sources/Core/Games/CatanHeroCounsel.swift ios/Tests/CatanHeroCounselTests.swift
git commit -m "feat: add rules-neutral Catan counsel"
```

---

### Task 4: Backward-compatible Catan identity snapshot

**Files:**
- Modify: `ios/Sources/Core/Games/CatanGame.swift`
- Modify: `ios/Sources/Core/Games/GameSnapshots.swift`
- Create: `ios/Tests/CatanAdventurerIntegrationTests.swift`

**Interfaces:**
- Consumes: Task 1 domain.
- Produces: `CatanGame.newGame(playerCount:seed:humanName:)` and `CatanSnapshot(game:adventurer:)`.

- [ ] **Step 1: Write failing integration tests**

```swift
import XCTest
@testable import Prismet

final class CatanAdventurerIntegrationTests: XCTestCase {
    private func character() throws -> CatanAdventurer {
        var draft = CatanAdventurerDraft.new(); draft.name = "Rowan"
        return try CatanAdventurer.make(from: draft)
    }

    func testNewGameUsesProvidedHumanNameAndDefaultStaysYou() {
        XCTAssertEqual(CatanGame.newGame(seed: 1).players[0].name, "You")
        XCTAssertEqual(CatanGame.newGame(seed: 1, humanName: "Rowan").players[0].name, "Rowan")
    }

    func testSnapshotRoundTripPreservesAdventurer() throws {
        let snapshot = CatanSnapshot(game: .newGame(seed: 2, humanName: "Rowan"), adventurer: try character())
        XCTAssertEqual(try JSONDecoder().decode(CatanSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }

    func testLegacySnapshotDefaultsToNoAdventurer() throws {
        let legacy = try JSONEncoder().encode(["game": CatanGame.newGame(seed: 3)])
        let decoded = try JSONDecoder().decode(CatanSnapshot.self, from: legacy)
        XCTAssertNil(decoded.adventurer)
        XCTAssertEqual(decoded.game.players[0].name, "You")
    }

    func testEditsCannotMutateExistingSnapshot() throws {
        let original = try character()
        let snapshot = CatanSnapshot(game: .newGame(seed: 4, humanName: original.name), adventurer: original)
        var edited = original.editableDraft; edited.name = "Mira"; _ = try CatanAdventurer.make(from: edited)
        XCTAssertEqual(snapshot.adventurer?.name, "Rowan")
        XCTAssertEqual(snapshot.game.players[0].name, "Rowan")
    }
}
```

- [ ] **Step 2: Run integration tests and confirm RED**

Use Task 1's command with `-only-testing:PrismetTests/CatanAdventurerIntegrationTests`. Expected: missing `humanName` and snapshot field.

- [ ] **Step 3: Add the name seam without changing defaults**

Change only the factory signature and names array:

```swift
static func newGame(playerCount: Int = 3,
                    seed: UInt64,
                    humanName: String = "You") -> CatanGame {
    // Existing board/deck setup remains behaviorally unchanged.
    let count = max(2, min(4, playerCount))
    let names = [humanName, "Amber", "Jade", "Garnet"]
    // Existing player construction follows unchanged.
}
```

- [ ] **Step 4: Add the optional snapshot and legacy decoder**

```swift
struct CatanSnapshot: Codable, Equatable {
    var game: CatanGame
    var adventurer: CatanAdventurer?

    init(game: CatanGame, adventurer: CatanAdventurer? = nil) {
        self.game = game; self.adventurer = adventurer
    }

    private enum CodingKeys: String, CodingKey { case game, adventurer }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(CatanGame.self, forKey: .game)
        adventurer = try container.decodeIfPresent(CatanAdventurer.self, forKey: .adventurer)
    }
}
```

- [ ] **Step 5: Run integration, Catan, and persistence suites**

```bash
xcodebuild -quiet -project ios/Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,id=EBA38985-AB1C-4013-9B0F-D1D3E5C4BE90' \
  -derivedDataPath ~/Library/Caches/Prismet-Catan-Adventurer-DD \
  -only-testing:PrismetTests/CatanAdventurerIntegrationTests \
  -only-testing:PrismetTests/CatanGameTests \
  -only-testing:PrismetTests/AllGamePersistenceTests test
```

Expected: all three suites pass; standard Catan stays green.

- [ ] **Step 6: Commit**

```bash
git add ios/Sources/Core/Games/CatanGame.swift ios/Sources/Core/Games/GameSnapshots.swift ios/Tests/CatanAdventurerIntegrationTests.swift
git commit -m "feat: snapshot adventurer identity in Catan"
```

---

### Task 5: Guided SwiftUI creator and Catan dock

**Files:**
- Create: `ios/Sources/Features/Games/CatanAdventurerCreatorView.swift`
- Create: `ios/Sources/Features/Games/CatanAdventurerDock.swift`
- Modify: `ios/Sources/Features/Games/CatanView.swift`
- Modify: `ios/Tests/CatanAdventurerIntegrationTests.swift`

**Interfaces:**
- Consumes: Tasks 1–4 and `PrismetDesign`.
- Produces: `CatanAdventurerCreatorView`, `CatanAdventurerDock`, `CatanCrestMedallion`, and `CatanRulesCreditsView`.

- [ ] **Step 1: Add a failing source-contract test**

```swift
func testCreatorAndDockExposeRequiredAccessibleCopy() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let creator = try String(contentsOf: root.appendingPathComponent("Sources/Features/Games/CatanAdventurerCreatorView.swift"))
    let dock = try String(contentsOf: root.appendingPathComponent("Sources/Features/Games/CatanAdventurerDock.swift"))
    XCTAssertTrue(creator.contains("Quick Adventurer"))
    XCTAssertTrue(creator.contains("Level 1 • 5E-compatible"))
    XCTAssertTrue(creator.contains("Rules & Credits"))
    XCTAssertTrue(creator.contains("accessibilityAddTraits"))
    XCTAssertTrue(dock.contains("Hero's Counsel"))
    XCTAssertTrue(dock.contains("Ready for next match"))
}
```

- [ ] **Step 2: Run integration suite and confirm RED**

Run Task 4's integration suite. Expected: file-read failure because the two UI files are missing.

- [ ] **Step 3: Implement the creator from the approved brief**

Read `/tmp/prismet-catan-adventurer-0sBWmf8i/brief.md`. Implement this public surface:

```swift
import SwiftUI

struct CatanAdventurerCreatorView: View {
    @ObservedObject var store: CatanAdventurerStore
    var onSaved: (CatanAdventurer) -> Void
    var onCancel: () -> Void
}

struct CatanCrestMedallion: View {
    let crest: CatanAdventurerCrest
    let classChoice: CatanAdventurerClass
    var size: CGFloat = 88
}

struct CatanRulesCreditsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rules & Credits").font(PrismetDesign.title(28))
                Text(CatanRulesAttribution.notice)
                Link("Open SRD 5.2.1", destination: CatanRulesAttribution.sourceURL)
                Link("Creative Commons BY 4.0", destination: CatanRulesAttribution.licenseURL)
            }
            .padding(20)
        }
        .facetBackground(Color(red: 0.80, green: 0.52, blue: 0.24), multiHue: true)
    }
}
```

The body provides five steps and a visible progress rail. Choice cards use `LazyVGrid`, 44-point minimum targets, checkmark, border-width change, `.accessibilityLabel`, `.accessibilityValue`, and `.accessibilityAddTraits(.isSelected)`. Abilities use two selected rows plus `Swap values`; `Restore smart assignment` resets customization. Every mutation calls `store.updateDraft`. Review catches typed validation errors inline and calls `store.completeDraft()` before `onSaved`.

Use `@Environment(\.accessibilityReduceMotion)` so crest/progress transitions become opacity-only under Reduce Motion. Use no external images or dependencies.

- [ ] **Step 4: Implement the three-state dock**

```swift
import SwiftUI

struct CatanAdventurerDock: View {
    let matchAdventurer: CatanAdventurer?
    let activeAdventurer: CatanAdventurer?
    let counsel: CatanCounsel?
    var onCreate: () -> Void
    var onEdit: () -> Void
    var onBegin: () -> Void
}
```

Render create, `Ready for next match`, and in-match states. In-match shows medallion, name, `Level 1 <Class>`, species/background, and a nested `Hero's Counsel` card. Ready state has `Begin as <name>`. Buttons have explicit accessibility labels and a 44-point minimum.

- [ ] **Step 5: Wire CatanView**

Add:

```swift
@StateObject private var adventurerStore = CatanAdventurerStore()
@State private var matchAdventurer: CatanAdventurer?
@State private var showAdventurerCreator = false
```

Place `CatanAdventurerDock` immediately after `scoreboard`, add a toolbar character button, and present:

```swift
.sheet(isPresented: $showAdventurerCreator) {
    CatanAdventurerCreatorView(store: adventurerStore) { _ in
        showAdventurerCreator = false
    } onCancel: {
        showAdventurerCreator = false
    }
}
```

Call `beginDraft(editing:)` before opening. During setup load the store, seed only the fresh unsaved match, and let any restored snapshot replace both values:

```swift
if let active = adventurerStore.active {
    matchAdventurer = active
    game = CatanGame.newGame(seed: UInt64.random(in: 1...UInt64.max), humanName: active.name)
}
persistence.configure(accountID: accountID, cloudStore: .shared) { snap in
    game = snap.game
    matchAdventurer = snap.adventurer
}
```

`startNewGame()` snapshots `adventurerStore.active` and supplies its name. `save()` writes `CatanSnapshot(game: game, adventurer: matchAdventurer)`. Edit never mutates `matchAdventurer`; begin starts a new match.

- [ ] **Step 6: Run focused suites and generic simulator build**

```bash
cd ios
xcodegen generate
xcodebuild -quiet -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,id=EBA38985-AB1C-4013-9B0F-D1D3E5C4BE90' \
  -derivedDataPath ~/Library/Caches/Prismet-Catan-Adventurer-DD \
  -only-testing:PrismetTests/CatanAdventurerTests \
  -only-testing:PrismetTests/CatanAdventurerStoreTests \
  -only-testing:PrismetTests/CatanHeroCounselTests \
  -only-testing:PrismetTests/CatanAdventurerIntegrationTests \
  -only-testing:PrismetTests/CatanGameTests \
  -only-testing:PrismetTests/AllGamePersistenceTests test
xcodebuild -quiet -project Prismet.xcodeproj -scheme Prismet \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ~/Library/Caches/Prismet-Catan-Adventurer-Build build
```

Expected: focused suites and generic simulator build exit 0.

- [ ] **Step 7: Perform visual/accessibility QA**

Install and launch on the iPhone 17 simulator. Inspect empty dock, five steps, long labels, ability swap, review/credits, ready state, and in-match counsel. Repeat at Accessibility XXXL and with Reduce Motion. Save untracked screenshots under `/tmp/prismet-catan-adventurer-qa/`.

- [ ] **Step 8: Commit**

```bash
git add ios/Sources/Features/Games/CatanAdventurerCreatorView.swift \
  ios/Sources/Features/Games/CatanAdventurerDock.swift \
  ios/Sources/Features/Games/CatanView.swift \
  ios/Tests/CatanAdventurerIntegrationTests.swift
git commit -m "feat: integrate Quick Adventurer with Catan"
```

---

### Task 6: Whole-branch verification, coordination release, and push

**Files:**
- Modify: `docs/AGENT-COORDINATION.md`

**Interfaces:**
- Consumes: Tasks 1–5 complete and reviewed.
- Produces: fresh evidence, released PRISM claim, and remote branch.

- [ ] **Step 1: Run full iOS suite**

```bash
cd ios
xcodegen generate
xcodebuild -quiet -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,id=EBA38985-AB1C-4013-9B0F-D1D3E5C4BE90' \
  -derivedDataPath ~/Library/Caches/Prismet-Catan-Adventurer-DD test
```

Expected: `PrismetTests` exits 0 with zero failures.

- [ ] **Step 2: Run final static and device-build gates**

```bash
git diff --check
git status --short
xcodebuild -quiet -project ios/Prismet.xcodeproj -scheme Prismet \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath ~/Library/Caches/Prismet-Catan-Adventurer-DeviceBuild build
```

Expected: clean diff check, only intended files before final commit, generic device build exit 0.

- [ ] **Step 3: Append PRISM release entry**

Record commits, files, test counts, build results, visual QA paths, attribution, iOS-only parity decision, and explicit unchanged Catan mechanics; release the claim.

- [ ] **Step 4: Commit docs and push**

```bash
git add docs/AGENT-COORDINATION.md docs/superpowers/specs/2026-07-15-prismet-catan-adventurer-design.md docs/superpowers/plans/2026-07-15-prismet-catan-adventurer.md
git commit -m "docs: release Quick Adventurer integration"
git push -u origin codex/prismet-catan-adventurer
```

- [ ] **Step 5: Verify publication**

```bash
git status --short --branch
git ls-remote origin refs/heads/codex/prismet-catan-adventurer
```

Expected: clean branch tracking origin; remote SHA equals local `HEAD`.
