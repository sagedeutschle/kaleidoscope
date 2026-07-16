import XCTest
@testable import Prismet

final class CatanAdventurerIntegrationTests: XCTestCase {
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
        _ = try CatanAdventurer.make(from: edited)

        XCTAssertEqual(snapshot.adventurer?.name, "Rowan")
        XCTAssertEqual(snapshot.game.players[0].name, "Rowan")
    }
}
