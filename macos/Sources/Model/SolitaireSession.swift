import Foundation
import SwiftUI

/// Live Solitaire session: owns the game, an undo stack, self-contained disk
/// persistence (so an in-progress deal survives tab switches and relaunches),
/// and reports a won game to the shared leaderboard. Self-contained on purpose —
/// it does not depend on the shared GameSessionState / GamePersistence plumbing.
@MainActor
final class SolitaireSession: ObservableObject {
    @Published private(set) var game: SolitaireGame
    @Published private(set) var drawCount: Int
    @Published private(set) var startedAt: Date
    @Published private(set) var elapsedSecondsAtWin: Int?

    private var undoStack: [SolitaireGame] = []
    private let maxUndo = 200
    private let leaderboard: LeaderboardService
    private let saveURL: URL?

    init(drawCount: Int = 1,
         leaderboard: LeaderboardService = KaleidoscopeLeaderboardService.shared,
         saveURL: URL? = SolitaireSession.defaultSaveURL()) {
        self.leaderboard = leaderboard
        self.saveURL = saveURL
        if let saved = SolitaireSession.load(from: saveURL) {
            self.game = saved
            self.drawCount = saved.drawCount
        } else {
            let fresh = SolitaireGame.newGame(seed: SolitaireSession.freshSeed(), drawCount: drawCount)
            self.game = fresh
            self.drawCount = fresh.drawCount
        }
        self.startedAt = Date()
    }

    // MARK: - Derived

    var canUndo: Bool { !undoStack.isEmpty }
    var moves: Int { game.moves }
    var isWon: Bool { game.isWon }

    // MARK: - Actions

    func newGame() {
        game = SolitaireGame.newGame(seed: SolitaireSession.freshSeed(), drawCount: drawCount)
        undoStack.removeAll()
        startedAt = Date()
        elapsedSecondsAtWin = nil
        persist()
    }

    func setDrawCount(_ count: Int) {
        let clamped = count == 3 ? 3 : 1
        guard clamped != drawCount else { return }
        drawCount = clamped
        newGame()
    }

    func draw()                                  { mutate { $0.drawFromStock() } }
    func sendWasteToFoundation()                 { mutate { $0.moveWasteToFoundation() } }
    func moveWasteToTableau(_ pile: Int)         { mutate { $0.moveWasteToTableau(pile: pile) } }
    func sendTableauToFoundation(_ pile: Int)    { mutate { $0.moveTableauToFoundation(pile: pile) } }
    func moveTableau(from: Int, cardIndex: Int, to: Int) {
        mutate { $0.moveTableau(from: from, cardIndex: cardIndex, to: to) }
    }
    func autoCollect()                           { mutate { $0.autoCollectToFoundations() } }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        persist()
    }

    // MARK: - Win → leaderboard

    /// Build the leaderboard result for a finished game (also used by the view to
    /// show a result slip). Higher score = faster, fewer moves.
    func makeResult(elapsedSeconds: Int) -> GameResult {
        let score = max(0, 10_000 - game.moves * 5 - elapsedSeconds * 2)
        return GameResult(id: UUID(),
                          facetID: "solitaire",
                          mode: "standard",
                          outcome: .won,
                          score: Int64(score),
                          durationSeconds: elapsedSeconds,
                          moveCount: game.moves,
                          completedAt: Date(),
                          metadata: ["draw": "\(drawCount)"])
    }

    // MARK: - Persistence

    func saveNow() { persist() }

    func reloadSavedState() {
        guard let saved = SolitaireSession.load(from: saveURL) else { return }
        game = saved
        drawCount = saved.drawCount
        undoStack.removeAll()
    }

    private func mutate(_ body: (inout SolitaireGame) -> Bool) {
        var copy = game
        let wasWon = copy.isWon
        guard body(&copy) else { return }   // no-op move: don't record undo
        undoStack.append(game)
        if undoStack.count > maxUndo { undoStack.removeFirst(undoStack.count - maxUndo) }
        game = copy
        persist()
        if game.isWon && !wasWon {
            let elapsed = Int(Date().timeIntervalSince(startedAt))
            elapsedSecondsAtWin = elapsed
            let result = makeResult(elapsedSeconds: elapsed)
            Task { try? await leaderboard.submit(result) }
        }
    }

    private func persist() {
        guard let saveURL else { return }
        do {
            try FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(game).write(to: saveURL, options: [.atomic])
        } catch {
            // Best-effort autosave; a failure here just means no resume next launch.
        }
    }

    nonisolated private static func load(from url: URL?) -> SolitaireGame? {
        guard let url, let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(SolitaireGame.self, from: data)
    }

    nonisolated private static func defaultSaveURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Kaleidoscope", isDirectory: true)
            .appendingPathComponent("Solitaire", isDirectory: true)
            .appendingPathComponent("game.json")
    }

    nonisolated private static func freshSeed() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFF_FFFF
    }
}
