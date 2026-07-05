import Combine
import Foundation

struct SeaBattleSetupState: Codable, Equatable, Hashable {
    var hostDeployment: SeaBattleFleetDeployment?
    var guestDeployment: SeaBattleFleetDeployment?
    var hostReady: Bool
    var guestReady: Bool

    static let empty = SeaBattleSetupState(
        hostDeployment: nil,
        guestDeployment: nil,
        hostReady: false,
        guestReady: false
    )

    static let complete = SeaBattleSetupState(
        hostDeployment: nil,
        guestDeployment: nil,
        hostReady: true,
        guestReady: true
    )

    var isComplete: Bool {
        hostReady && guestReady
            && (hostDeployment?.isComplete ?? true)
            && (guestDeployment?.isComplete ?? true)
    }

    var isDeploymentPhase: Bool {
        !isComplete
    }

    func deployment(for player: SeaBattlePlayer) -> SeaBattleFleetDeployment? {
        player == .host ? hostDeployment : guestDeployment
    }

    func isReady(_ player: SeaBattlePlayer) -> Bool {
        player == .host ? hostReady : guestReady
    }

    mutating func setDeployment(_ deployment: SeaBattleFleetDeployment, for player: SeaBattlePlayer, ready: Bool) {
        if player == .host {
            hostDeployment = deployment
            hostReady = ready && deployment.isComplete
        } else {
            guestDeployment = deployment
            guestReady = ready && deployment.isComplete
        }
    }
}

struct SeaBattleSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: SeaBattleGame
    var setup: SeaBattleSetupState
    var difficulty: SeaBattleAIDifficulty
    var deploymentOrientation: SeaBattleOrientation
}

final class SeaBattleSession: ObservableObject {
    private static let snapshotVersion = 1

    @Published var game = SeaBattleGame.deploymentGame
    @Published var setup = SeaBattleSetupState.empty
    @Published var deployment = SeaBattleFleetDeployment()
    @Published var difficulty: SeaBattleAIDifficulty = .normal
    @Published var deploymentOrientation: SeaBattleOrientation = .horizontal
    @Published var isAIThinking = false

    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var isDeploymentPhase: Bool {
        setup.isDeploymentPhase
    }

    var canFireCurrentTurn: Bool {
        !setup.isDeploymentPhase && !game.isGameOver && game.currentPlayer == .host && !isAIThinking
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadSnapshot(SeaBattleSessionSnapshot.self, kind: .seaBattle, windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadSnapshot(SeaBattleSessionSnapshot.self,
                                                                kind: .seaBattle,
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

    func snapshot() -> SeaBattleSessionSnapshot {
        SeaBattleSessionSnapshot(
            version: Self.snapshotVersion,
            game: game,
            setup: setup,
            difficulty: difficulty,
            deploymentOrientation: deploymentOrientation
        )
    }

    func restore(from snapshot: SeaBattleSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        setup = snapshot.setup
        difficulty = snapshot.difficulty
        deploymentOrientation = snapshot.deploymentOrientation
        deployment = setup.deployment(for: .host) ?? SeaBattleFleetDeployment()
        isAIThinking = false
        if persist { save() }
    }

    func setDifficulty(_ difficulty: SeaBattleAIDifficulty) {
        self.difficulty = difficulty
        save()
    }

    func setDeploymentOrientation(_ orientation: SeaBattleOrientation) {
        deploymentOrientation = orientation
        save()
    }

    func resetBattle() {
        game = .deploymentGame
        setup = .empty
        deployment = SeaBattleFleetDeployment()
        difficulty = .normal
        deploymentOrientation = .horizontal
        isAIThinking = false
        save()
    }

    @discardableResult
    func autoDeploy() -> Bool {
        guard setup.isDeploymentPhase, !setup.isReady(.host) else { return false }
        deployment = SeaBattleFleetDeployment.random(seed: UInt64.random(in: 1...UInt64.max))
        setup.setDeployment(deployment, for: .host, ready: false)
        save()
        return true
    }

    @discardableResult
    func clearDeployment() -> Bool {
        guard setup.isDeploymentPhase, !setup.isReady(.host) else { return false }
        deployment = SeaBattleFleetDeployment()
        setup.setDeployment(deployment, for: .host, ready: false)
        save()
        return true
    }

    @discardableResult
    func tapDeploymentCell(_ point: SeaBattlePoint) -> Bool {
        guard setup.isDeploymentPhase, !setup.isReady(.host) else { return false }
        if deployment.removeShip(containing: point) {
            setup.setDeployment(deployment, for: .host, ready: false)
            save()
            return true
        }
        guard let length = deployment.nextLength else { return false }
        guard deployment.place(length: length, at: point, orientation: deploymentOrientation) else { return false }
        setup.setDeployment(deployment, for: .host, ready: false)
        save()
        return true
    }

    func canMoveHostShip(id: SeaBattlePlacement.ID, to origin: SeaBattlePoint, orientation: SeaBattleOrientation) -> Bool {
        guard setup.isDeploymentPhase, !setup.isReady(.host) else { return false }
        return deployment.canMoveShip(id: id, to: origin, orientation: orientation)
    }

    @discardableResult
    func moveHostShip(id: SeaBattlePlacement.ID, to origin: SeaBattlePoint, orientation: SeaBattleOrientation) -> Bool {
        guard setup.isDeploymentPhase, !setup.isReady(.host) else { return false }
        guard deployment.moveShip(id: id, to: origin, orientation: orientation) else { return false }
        setup.setDeployment(deployment, for: .host, ready: false)
        save()
        return true
    }

    @discardableResult
    func commitDeployment() -> Bool {
        guard setup.isDeploymentPhase, !setup.isReady(.host), deployment.isComplete else { return false }

        setup.setDeployment(deployment, for: .host, ready: true)
        let botDeployment = SeaBattleFleetDeployment.random(seed: UInt64.random(in: 1...UInt64.max))
        setup.setDeployment(botDeployment, for: .guest, ready: true)
        _ = startBattleIfReady()
        isAIThinking = false
        save()
        return true
    }

    @discardableResult
    func startBattleIfReady() -> Bool {
        guard setup.hostReady, setup.guestReady,
              let hostDeployment = setup.hostDeployment,
              let guestDeployment = setup.guestDeployment,
              let deployedGame = SeaBattleGame.gameFromDeployments(host: hostDeployment, guest: guestDeployment)
        else { return false }

        if game.board(for: .host).shipCells.isEmpty || game.board(for: .guest).shipCells.isEmpty {
            game = deployedGame
        }
        return true
    }

    func canFire(at point: SeaBattlePoint) -> Bool {
        guard canFireCurrentTurn else { return false }
        return (0..<SeaBattleGame.size).contains(point.row) && (0..<SeaBattleGame.size).contains(point.col)
            && !game.board(for: .guest).shots.contains(point)
    }

    @discardableResult
    func fire(_ point: SeaBattlePoint) -> Bool {
        guard canFire(at: point) else { return false }
        let result = game.fire(at: point)
        switch result {
        case .invalid, .alreadyTried:
            return false
        default:
            save()
            return !game.isGameOver && game.currentPlayer == .guest
        }
    }

    @discardableResult
    func fireByAI() -> Bool {
        guard !setup.isDeploymentPhase, !game.isGameOver else { return false }
        guard game.currentPlayer == .guest else { return false }

        isAIThinking = true
        let ai = SeaBattleAI(difficulty: difficulty, seed: UInt64(game.moveCount + 97))
        guard let point = ai.shot(for: .guest, in: game),
              game.fire(at: point) != .alreadyTried
        else {
            isAIThinking = false
            return false
        }

        isAIThinking = false
        save()
        return true
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSnapshot(snapshot(), kind: .seaBattle, windowSessionID: windowSessionID)
    }
}
