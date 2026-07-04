import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — active arcade persistence snapshots.
struct Game2048ShufflePowerUps: Codable, Equatable, Hashable {
    static let maxUsesPerGame = 5

    let usesPerGame: Int
    private(set) var remainingUses: Int

    init(usesPerGame: Int = 1) {
        self.usesPerGame = min(max(usesPerGame, 0), Self.maxUsesPerGame)
        self.remainingUses = self.usesPerGame
    }

    mutating func use() -> Bool {
        guard remainingUses > 0 else { return false }
        remainingUses -= 1
        return true
    }

    mutating func resetForNewGame() {
        remainingUses = usesPerGame
    }
}
