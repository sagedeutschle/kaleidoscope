import Foundation
import SwiftUI

struct SpiderSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: SpiderGame
    var seed: UInt64
}

final class SpiderSession: ObservableObject {
    @Published private(set) var game: SpiderGame
    @Published private(set) var seed: UInt64

    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.seed = seed
        self.game = SpiderGame.newGame(seed: seed)
    }

    var isWon: Bool { game.isWon }
    var moves: Int { game.moves }
    var completedSets: Int { game.completedSets }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadSnapshot(SpiderSessionSnapshot.self,
                                                    kind: .spider,
                                                    windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            } else {
                save()
            }
        } catch {
            save()
        }
    }

    func reloadSavedState() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        do {
            if let snapshot = try persistenceStore.loadSnapshot(SpiderSessionSnapshot.self,
                                                              kind: .spider,
                                                              windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> SpiderSessionSnapshot {
        SpiderSessionSnapshot(version: 1, game: game, seed: seed)
    }

    func restore(from snapshot: SpiderSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        seed = snapshot.seed
        if persist { save() }
    }

    @discardableResult
    func dealRow() -> Bool {
        guard game.dealRow() else { return false }
        save()
        return true
    }

    @discardableResult
    func moveRun(from sourceColumn: Int, cardIndex: Int, to destinationColumn: Int) -> Bool {
        guard game.moveRun(from: sourceColumn, cardIndex: cardIndex, to: destinationColumn) else { return false }
        save()
        return true
    }

    func newGame(seed seedValue: UInt64? = nil) {
        if let seedValue {
            seed = seedValue
        } else {
            seed = UInt64.random(in: 1...UInt64.max)
        }
        game = SpiderGame.newGame(seed: seed)
        save()
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSnapshot(snapshot(), kind: .spider, windowSessionID: windowSessionID)
    }
}
