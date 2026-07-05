import Foundation

struct GomokuSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: GomokuGame
    var undoStack: [GomokuGame]
    var usesBot: Bool
    var aiELO: Int
}

final class GomokuSession: ObservableObject {
    @Published var game = GomokuGame()
    @Published private(set) var undoStack: [GomokuGame] = []
    @Published var usesBot = false
    @Published var aiELO = 1200

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        self.persistenceStore = store

        do {
            if let snapshot = try store.loadSnapshot(GomokuSessionSnapshot.self, kind: .gomoku, windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadSnapshot(GomokuSessionSnapshot.self, kind: .gomoku, windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> GomokuSessionSnapshot {
        GomokuSessionSnapshot(version: 1,
                             game: game,
                             undoStack: undoStack,
                             usesBot: usesBot,
                             aiELO: aiELO)
    }

    func restore(from snapshot: GomokuSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        undoStack = snapshot.undoStack
        usesBot = snapshot.usesBot
        aiELO = Self.clampELO(snapshot.aiELO)
        if persist { save() }
    }

    @discardableResult
    func play(row: Int, col: Int) -> Bool {
        let previous = game
        guard game.placeStone(row: row, col: col) else { return false }

        pushUndo(previous)
        save()
        return true
    }

    func reset() {
        game = GomokuGame()
        undoStack = []
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        save()
    }

    func nextBotMove() -> GomokuPoint? {
        GomokuAI(player: .white, targetELO: aiELO).move(in: game)
    }

    private func pushUndo(_ gameState: GomokuGame) {
        undoStack.append(gameState)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSnapshot(snapshot(), kind: .gomoku, windowSessionID: windowSessionID)
    }

    private static func clampELO(_ elo: Int) -> Int {
        min(2400, max(600, elo))
    }
}
