import XCTest
@testable import Prismet

final class CatanHeroCounselTests: XCTestCase {
    private func character(_ choice: CatanAdventurerClass = .fighter) throws -> CatanAdventurer {
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        draft.chooseClass(choice)
        return try CatanAdventurer.make(from: draft)
    }

    private func updatedGame(_ game: CatanGame, updating update: (inout [String: Any]) -> Void) throws -> CatanGame {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as? [String: Any])
        update(&json)
        return try JSONDecoder().decode(CatanGame.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func buildGame(resources: [CatanResource: Int]) throws -> CatanGame {
        try updatedGame(.newGame(seed: 11)) { json in
            json["phase"] = "build"
            var players = json["players"] as! [[String: Any]]
            players[0]["resources"] = resources.flatMap { [$0.key.rawValue, $0.value] }
            json["players"] = players
        }
    }

    func testNoCharacterProducesNoCounsel() {
        XCTAssertNil(CatanHeroCounsel.advice(for: nil, game: .newGame(seed: 1)))
    }

    func testSameStateProducesDeterministicCounselWithoutMutation() throws {
        let game = CatanGame.newGame(seed: 1)
        let before = game

        let first = CatanHeroCounsel.advice(for: try character(.wizard), game: game)

        XCTAssertEqual(first, CatanHeroCounsel.advice(for: try character(.wizard), game: game))
        XCTAssertEqual(game, before)
        XCTAssertEqual(first?.title, "Wizard's Counsel")
    }

    func testPhaseGuidanceUsesThePublicPhase() throws {
        let setup = CatanHeroCounsel.advice(for: try character(), game: .newGame(seed: 2))
        let rollGame = try updatedGame(.newGame(seed: 2)) { $0["phase"] = "roll" }
        let roll = CatanHeroCounsel.advice(for: try character(), game: rollGame)

        XCTAssertTrue(try XCTUnwrap(setup?.message).localizedCaseInsensitiveContains("settlement"))
        XCTAssertTrue(try XCTUnwrap(roll?.message).localizedCaseInsensitiveContains("roll"))
    }

    func testEveryNonBuildPhaseHasSpecificGuidance() throws {
        let base = CatanGame.newGame(seed: 2)
        let phasesAndTerms = [
            ("setupRoad", "road"),
            ("moveRobber", "robber"),
            ("gameOver", "finished")
        ]

        for (phase, term) in phasesAndTerms {
            let game = try updatedGame(base) { $0["phase"] = phase }
            let message = try XCTUnwrap(CatanHeroCounsel.advice(for: character(), game: game)?.message)
            XCTAssertTrue(message.localizedCaseInsensitiveContains(term), "\(phase): \(message)")
        }
    }

    func testBuildCounselUsesDocumentedVisiblePriority() throws {
        let cases: [([CatanResource: Int], String)] = [
            ([.grain: 2, .ore: 3], "city"),
            ([.brick: 1, .lumber: 1, .wool: 1, .grain: 1], "settlement"),
            ([.brick: 1, .lumber: 1], "road"),
            ([.brick: 4], "bank trade"),
            ([:], "end the turn")
        ]

        for (resources, term) in cases {
            let message = try XCTUnwrap(
                CatanHeroCounsel.advice(for: character(), game: buildGame(resources: resources))?.message
            )
            XCTAssertTrue(message.localizedCaseInsensitiveContains(term), "\(term): \(message)")
        }
    }

    func testOpponentHiddenResourcesCannotChangeCounsel() throws {
        let game = CatanGame.newGame(seed: 3)
        let altered = try updatedGame(game) { json in
            var players = json["players"] as! [[String: Any]]
            players[1]["resources"] = [
                "brick", 99, "lumber", 99, "wool", 99, "grain", 99, "ore", 99
            ]
            players[1]["devCards"] = ["victoryPoint", "victoryPoint"]
            players[1]["newDevCards"] = ["victoryPoint"]
            json["players"] = players
            json["devDeck"] = ["victoryPoint", "victoryPoint", "victoryPoint"]
        }

        XCTAssertEqual(
            CatanHeroCounsel.advice(for: try character(.rogue), game: game),
            CatanHeroCounsel.advice(for: try character(.rogue), game: altered)
        )
    }

    func testAllClassCounselIsOriginalAndRulesNeutral() throws {
        let counsel = try CatanAdventurerClass.allCases.map { choice in
            try XCTUnwrap(CatanHeroCounsel.advice(for: try character(choice), game: .newGame(seed: 4)))
        }
        let prohibitedPromises: Set<String> = ["bonus", "grant", "gain", "extra", "automatic", "free"]

        XCTAssertEqual(Set(counsel.map(\.message)).count, CatanAdventurerClass.allCases.count)
        for advice in counsel {
            let message = advice.message.localizedLowercase
            let words = Set(message.split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: prohibitedPromises), advice.message)
            XCTAssertFalse(message.contains("+"), advice.message)
        }
    }
}
