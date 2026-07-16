import XCTest
@testable import Prismet

final class CatanAdventurerIntegrationTests: XCTestCase {
    func testCreatorAndDockExposeRequiredAccessibleCopy() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let creator = try String(contentsOf: root.appendingPathComponent("Sources/Features/Games/CatanAdventurerCreatorView.swift"))
        let dock = try String(contentsOf: root.appendingPathComponent("Sources/Features/Games/CatanAdventurerDock.swift"))
        let catan = try String(contentsOf: root.appendingPathComponent("Sources/Features/Games/CatanView.swift"))

        XCTAssertTrue(creator.contains("Quick Adventurer"))
        XCTAssertTrue(creator.contains("Level 1 • 5E-compatible"))
        XCTAssertTrue(creator.contains("Rules & Credits"))
        XCTAssertTrue(creator.contains("accessibilityAddTraits"))
        XCTAssertTrue(creator.contains("accessibilityReduceMotion"))
        XCTAssertFalse(creator.contains(".animation(reduceMotion ? .easeInOut"))
        XCTAssertTrue(creator.contains(".animation(reduceMotion ? nil :"))
        XCTAssertTrue(creator.contains("dynamicTypeSize.isAccessibilitySize"))
        XCTAssertTrue(creator.contains("scrollDismissesKeyboard"))
        XCTAssertTrue(creator.contains("minHeight: 44"))
        XCTAssertTrue(creator.contains("Reset adventurer"))
        XCTAssertTrue(creator.contains("confirmationDialog"))
        XCTAssertTrue(creator.contains("store.deleteActive()"))
        XCTAssertTrue(dock.contains("Hero's Counsel"))
        XCTAssertTrue(dock.contains("Ready for next match"))
        XCTAssertTrue(dock.contains("ViewThatFits"))
        XCTAssertTrue(dock.contains("accessibilityLabel"))
        XCTAssertTrue(
            dock.contains("Text(\"Hero's Counsel\").font(.headline)\n                        .fixedSize(horizontal: false, vertical: true)"),
            "Counsel heading must wrap instead of truncating at accessibility text sizes"
        )
        let identitySource = try XCTUnwrap(dock.range(of: "private func identity"))
        let editButtonSource = try XCTUnwrap(dock.range(of: "private func editButton"))
        XCTAssertTrue(
            dock[identitySource.lowerBound..<editButtonSource.lowerBound]
                .contains(".fixedSize(horizontal: false, vertical: true)"),
            "Dock identity copy must wrap instead of truncating at accessibility text sizes"
        )
        XCTAssertTrue(catan.contains("matchAdventurer = snap.adventurer"))
        XCTAssertTrue(catan.contains("adventurer: matchAdventurer"))
        XCTAssertTrue(catan.contains("humanName: matchAdventurer?.name ?? \"You\""))
    }

    func testValidationRecoveryReturnsInvalidArraysToAbilities() {
        XCTAssertEqual(
            CatanAdventurerCreatorView.recoveryStep(for: .invalidStandardArray, from: .review),
            .abilities
        )
        XCTAssertEqual(
            CatanAdventurerCreatorView.recoveryStep(for: .emptyName, from: .review),
            .review
        )
        XCTAssertEqual(
            CatanAdventurerCreatorView.recoveryStep(for: .nameTooLong, from: .identity),
            .identity
        )
    }

    private func character() throws -> CatanAdventurer {
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        return try CatanAdventurer.make(from: draft)
    }

    func testNewGameUsesProvidedHumanNameAndDefaultStaysYou() {
        XCTAssertEqual(CatanGame.newGame(seed: 1).players[0].name, "You")
        XCTAssertEqual(CatanGame.newGame(seed: 1, humanName: "Rowan").players[0].name, "Rowan")
    }

    func testSnapshotRoundTripPreservesAdventurer() throws {
        let snapshot = CatanSnapshot(
            game: .newGame(seed: 2, humanName: "Rowan"),
            adventurer: try character()
        )

        XCTAssertEqual(
            try JSONDecoder().decode(CatanSnapshot.self, from: JSONEncoder().encode(snapshot)),
            snapshot
        )
    }

    func testLegacySnapshotDefaultsToNoAdventurer() throws {
        let legacy = try JSONEncoder().encode(["game": CatanGame.newGame(seed: 3)])
        let decoded = try JSONDecoder().decode(CatanSnapshot.self, from: legacy)

        XCTAssertNil(decoded.adventurer)
        XCTAssertEqual(decoded.game.players[0].name, "You")
    }

    func testEditsCannotMutateExistingSnapshot() throws {
        let original = try character()
        let snapshot = CatanSnapshot(
            game: .newGame(seed: 4, humanName: original.name),
            adventurer: original
        )
        var edited = original.editableDraft
        edited.name = "Mira"
        let editedCharacter = try CatanAdventurer.make(from: edited)

        XCTAssertEqual(editedCharacter.name, "Mira")
        XCTAssertEqual(snapshot.adventurer?.name, "Rowan")
        XCTAssertEqual(snapshot.game.players[0].name, "Rowan")
    }
}
