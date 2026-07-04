import Foundation
import Combine

/// THE shared source of truth. Both the 2D and 3D boards observe this object
/// and call `tap(_:)`; because they read the same state, hot-swapping the view
/// never loses the game.
@MainActor
final class GameState: ObservableObject {
    @Published private(set) var position: Position = .initial
    @Published private(set) var status: GameStatus = .ongoing
    @Published private(set) var lastMove: Move? = nil
    @Published private(set) var selectedSquare: Square? = nil
    @Published private(set) var isThinking: Bool = false

    @Published var vsComputer: Bool = true
    @Published var humanColor: PieceColor = .white

    /// AI strength, 1...10, driven by the difficulty slider.
    @Published var aiLevel: Int = 5 {
        didSet { ai.level = aiLevel }
    }

    let ai: ChessAI
    private var undoStack: [(Position, Move?, GameStatus)] = []
    /// Every position that has occurred this game (incl. the current one), used
    /// to detect threefold repetition. Kept in lockstep with `undoStack`.
    private var positionHistory: [Position] = [.initial]
    /// Bumped on New Game / Undo so a stale "thinking" task aborts instead of
    /// dropping a move into a position the user has since changed.
    private var gameGeneration = 0
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    init(ai: ChessAI = MinimaxAI()) {
        self.ai = ai
        self.ai.level = aiLevel
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadChess(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadChess(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> ChessGameSnapshot {
        ChessGameSnapshot(version: 1,
                          position: position,
                          status: status,
                          lastMove: lastMove,
                          selectedSquare: selectedSquare,
                          vsComputer: vsComputer,
                          humanColor: humanColor,
                          aiLevel: aiLevel,
                          undoStack: undoStack.map { ChessUndoEntry(position: $0.0, lastMove: $0.1, status: $0.2) },
                          positionHistory: positionHistory)
    }

    func restore(from snapshot: ChessGameSnapshot, persist: Bool = true) {
        position = snapshot.position
        status = snapshot.status
        lastMove = snapshot.lastMove
        selectedSquare = snapshot.selectedSquare
        vsComputer = snapshot.vsComputer
        humanColor = snapshot.humanColor
        aiLevel = snapshot.aiLevel
        undoStack = snapshot.undoStack.map { ($0.position, $0.lastMove, $0.status) }
        positionHistory = snapshot.positionHistory.isEmpty ? [.initial] : snapshot.positionHistory
        isThinking = false
        gameGeneration += 1
        ai.level = aiLevel
        if persist { save() }
        scheduleAIMoveIfNeeded()
    }

    // MARK: - Strength labelling

    static func levelName(_ level: Int) -> String {
        switch level {
        case ...2:  return "Beginner"
        case 3...4: return "Casual"
        case 5...6: return "Intermediate"
        case 7...8: return "Advanced"
        default:    return "Master"
        }
    }

    /// How long the AI should *appear* to think, in seconds — randomised and
    /// scaled by level so it feels like it's actually pondering even when the
    /// search returns instantly.
    private func artificialThinkTime() -> Double {
        let l = Double(aiLevel)
        let lo = 0.35 + l * 0.16
        let hi = lo + 0.70 + l * 0.13
        return Double.random(in: lo...hi)
    }

    // MARK: - Derived state for the views

    /// Destination squares the currently selected piece may legally move to.
    var legalDestinations: Set<Square> {
        guard let from = selectedSquare else { return [] }
        return Set(MoveGenerator.legalMoves(from: from, in: position).map(\.to))
    }

    /// The king square to flag when its side is in check (for highlighting).
    var checkedKingSquare: Square? {
        if case .check(let color) = status { return position.kingSquare(of: color) }
        if case .checkmate(let winner) = status { return position.kingSquare(of: winner.opposite) }
        return nil
    }

    var isHumanTurn: Bool {
        !vsComputer || position.sideToMove == humanColor
    }

    func canSelect(_ square: Square) -> Bool {
        guard let p = position.piece(at: square) else { return false }
        return p.color == position.sideToMove && isHumanTurn
    }

    // MARK: - Unified interaction (shared by both renderers)

    func tap(_ square: Square) {
        guard !status.isTerminal, !isThinking, isHumanTurn else { return }

        if let from = selectedSquare {
            if from == square {                          // tap selected piece again -> deselect
                selectedSquare = nil
                return
            }
            let candidates = MoveGenerator.legalMoves(from: from, in: position).filter { $0.to == square }
            if let move = chooseMove(candidates) {
                selectedSquare = nil
                apply(move)
                scheduleAIMoveIfNeeded()
                return
            }
            selectedSquare = canSelect(square) ? square : nil
        } else if canSelect(square) {
            selectedSquare = square
        }
    }

    /// v1: auto-queen on promotion (under-promotion picker is a later note).
    private func chooseMove(_ candidates: [Move]) -> Move? {
        if candidates.isEmpty { return nil }
        if let promo = candidates.first(where: { $0.promotion == .queen }) { return promo }
        return candidates.first
    }

    // MARK: - Applying moves

    private func apply(_ move: Move) {
        undoStack.append((position, lastMove, status))
        position = MoveGenerator.makeMove(move, in: position)
        positionHistory.append(position)
        lastMove = move
        status = resolvedStatus()
        save()
    }

    /// Position-level status, upgraded to a draw if the game has now repeated
    /// three times (a game-level rule the stateless engine can't see).
    private func resolvedStatus() -> GameStatus {
        let base = MoveGenerator.status(of: position)
        if !base.isTerminal, MoveGenerator.isThreefoldRepetition(history: positionHistory) {
            return .draw
        }
        return base
    }

    private func scheduleAIMoveIfNeeded() {
        guard vsComputer, !status.isTerminal, position.sideToMove != humanColor else { return }
        let gen = gameGeneration
        let snapshot = position
        let floor = artificialThinkTime()
        isThinking = true
        Task {
            let start = Date()
            let move = await ai.bestMove(for: snapshot)
            // Pad to the artificial think time so the AI seems deliberate.
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < floor {
                try? await Task.sleep(nanoseconds: UInt64((floor - elapsed) * 1_000_000_000))
            }
            // Abort if a New Game / Undo happened while we were thinking.
            guard gen == self.gameGeneration else { return }
            if let move { self.apply(move) }
            self.isThinking = false
        }
    }

    // MARK: - Controls

    func newGame() {
        gameGeneration += 1
        position = .initial
        positionHistory = [.initial]
        lastMove = nil
        selectedSquare = nil
        status = .ongoing
        undoStack.removeAll()
        isThinking = false
        // If the human chose Black, let the engine open.
        scheduleAIMoveIfNeeded()
        save()
    }

    /// Step back to the human's most recent turn (undoing the AI reply too).
    func undo() {
        guard !isThinking else { return }
        gameGeneration += 1
        repeat {
            guard let (pos, last, st) = undoStack.popLast() else { break }
            position = pos
            lastMove = last
            status = st
            if positionHistory.count > 1 { positionHistory.removeLast() }
        } while vsComputer && position.sideToMove != humanColor && !undoStack.isEmpty
        selectedSquare = nil
        save()
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveChess(snapshot(), windowSessionID: windowSessionID)
    }
}
