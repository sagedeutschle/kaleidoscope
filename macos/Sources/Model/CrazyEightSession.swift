import Foundation

enum CrazyEightMode: String, Codable, Hashable {
    case soloBot
    case passAndPlay
}

struct CrazyEightSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: CrazyEightGame
    var seed: UInt64
    var aiELO: Int
    var mode: CrazyEightMode
}

final class CrazyEightSession: ObservableObject {
    @Published var game = CrazyEightGame.newGame(seed: 1)
    @Published var seed: UInt64 = 2
    @Published var aiELO: Int = 1200
    @Published var mode: CrazyEightMode = .soloBot

    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var visiblePlayer: CrazyEightPlayer {
        mode == .passAndPlay ? game.currentPlayer : .host
    }

    var isBotTurn: Bool {
        mode == .soloBot && game.currentPlayer == .guest && !game.isGameOver
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadSnapshot(CrazyEightSessionSnapshot.self,
                                                    kind: .crazyEight,
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
            if let snapshot = try persistenceStore.loadSnapshot(CrazyEightSessionSnapshot.self,
                                                               kind: .crazyEight,
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

    func snapshot() -> CrazyEightSessionSnapshot {
        CrazyEightSessionSnapshot(version: 1,
                                 game: game,
                                 seed: seed,
                                 aiELO: aiELO,
                                 mode: mode)
    }

    func restore(from snapshot: CrazyEightSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        seed = snapshot.seed
        aiELO = clampedELO(snapshot.aiELO)
        mode = snapshot.mode
        if persist { save() }
    }

    func newGame(seed: UInt64? = nil) {
        self.seed = seed ?? UInt64.random(in: 1...UInt64.max)
        game = CrazyEightGame.newGame(seed: self.seed)
        save()
    }

    func setMode(_ mode: CrazyEightMode) {
        self.mode = mode
        save()
    }

    @discardableResult
    func playCard(_ card: Card, declaredSuit: Suit? = nil) -> Bool {
        let changed = game.playCard(card, declaredSuit: declaredSuit)
        if changed { save() }
        return changed
    }

    @discardableResult
    func drawCard() -> Bool {
        let changed = game.drawCard()
        if changed { save() }
        return changed
    }

    @discardableResult
    func apply(_ move: CrazyEightMove) -> Bool {
        var next = game
        switch move {
        case .play(let card, let declaredSuit):
            let changed = next.playCard(card, declaredSuit: declaredSuit)
            guard changed else { return false }
            game = next
            save()
            return true
        case .draw:
            let changed = next.drawCard()
            guard changed else { return false }
            game = next
            save()
            return true
        }
    }

    func moveForBot() -> CrazyEightMove? {
        guard isBotTurn else { return nil }
        return CrazyEightAI(player: .guest, targetELO: aiELO).move(in: game)
    }

    func canPlay(_ card: Card, as player: CrazyEightPlayer) -> Bool {
        game.currentPlayer == player && sessionCanAct(for: player) && game.canPlay(card)
    }

    func canDraw(as player: CrazyEightPlayer) -> Bool {
        game.currentPlayer == player && sessionCanAct(for: player)
    }

    private func sessionCanAct(for player: CrazyEightPlayer) -> Bool {
        !game.isGameOver && (mode == .passAndPlay || player == .host)
    }

    private func clampedELO(_ elo: Int) -> Int {
        min(2400, max(600, elo))
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSnapshot(snapshot(), kind: .crazyEight, windowSessionID: windowSessionID)
    }
}
