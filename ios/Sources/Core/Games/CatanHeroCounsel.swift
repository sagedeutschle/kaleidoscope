import Foundation

struct CatanCounsel: Equatable {
    var title: String
    var message: String
}

/// A read-only, presentation-only guide for the human seat. It never performs a game action.
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

        return CatanCounsel(
            title: "\(adventurer.classChoice.displayName)'s Counsel",
            message: "\(flavor(for: adventurer.classChoice)) \(message)"
        )
    }

    private static func buildAdvice(for game: CatanGame) -> String {
        let player = game.players[0]

        if player.citiesLeft > 0, game.canAfford(CatanGame.cityCost, player: 0) {
            return "Your stores can support a city; look for a settlement worth raising."
        }
        if player.settlementsLeft > 0, game.canAfford(CatanGame.settlementCost, player: 0) {
            return "Your stores can support a settlement; look for a legal intersection that broadens production."
        }
        if player.roadsLeft > 0, game.canAfford(CatanGame.roadCost, player: 0) {
            return "Your stores can support a road; extend toward an open intersection before the route closes."
        }
        if player.resources.values.contains(where: { $0 >= 4 }) {
            return "Set aside four matching resources and consider a bank trade that serves the next build."
        }
        if game.publicScore(for: 0) >= CatanGame.winningPoints - 1 {
            return "At the visible finish line, keep the next turn simple and protect the plan you have."
        }
        return "No clear build is ready; end the turn when your plan is settled and return ready to roll."
    }

    private static func flavor(for choice: CatanAdventurerClass) -> String {
        switch choice {
        case .barbarian: return "With a steady ember:"
        case .bard: return "With a table-song in mind:"
        case .cleric: return "With patient purpose:"
        case .druid: return "With an eye on the island's rhythm:"
        case .fighter: return "With a clear stance:"
        case .monk: return "With a quiet breath:"
        case .paladin: return "With a promise to the road ahead:"
        case .ranger: return "With the horizon surveyed:"
        case .rogue: return "With an opening marked:"
        case .sorcerer: return "With a spark of resolve:"
        case .warlock: return "With a careful bargain in mind:"
        case .wizard: return "With the pattern considered:"
        }
    }
}
