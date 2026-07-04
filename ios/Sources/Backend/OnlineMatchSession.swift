import Foundation
import Supabase

/// Drives one online head-to-head match from a device's point of view: host or
/// join, then keep `match` continuously in sync while both players trade moves.
///
/// Sync strategy: Supabase Realtime (postgres_changes on this match's row) for
/// instant delivery, plus a slow polling loop as a safety net — turn-based games
/// only need eventual delivery, so the poll guarantees progress even if the
/// websocket never connects (hotel Wi-Fi, school networks, etc.).
@MainActor
final class OnlineMatchSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case working(String)          // spinner label ("Creating match…")
        case waitingForOpponent
        case active
        case finished
        case failed(String)
    }

    @Published private(set) var match: OnlineMatch?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var myUserID: UUID?
    /// Transient error (e.g. a move that failed to send). UI shows and clears it.
    @Published var lastError: String?

    private let store: OnlineMatchStore
    private var watchTask: Task<Void, Never>?

    /// Placeholder for views whose `online` parameter is nil — never started, never
    /// publishes. Lets game views keep a single non-optional `@ObservedObject`.
    static let inert = OnlineMatchSession()

    init(store: OnlineMatchStore = .shared) {
        self.store = store
    }

    // MARK: - Derived state

    var roomCode: String? { match?.roomCode }
    var isHost: Bool {
        guard let match, let myUserID else { return false }
        return match.isHost(myUserID)
    }
    var isMyTurn: Bool {
        guard let match, let myUserID, match.status == .active else { return false }
        return match.currentTurnUserID == myUserID
    }
    var opponentName: String? {
        guard let match, let myUserID else { return nil }
        return match.opponentName(for: myUserID)
    }
    var opponentEmoji: String? {
        guard let match, let myUserID else { return nil }
        return match.opponentEmoji(for: myUserID)
    }
    /// nil = draw (or not finished yet); true/false once a winner exists.
    var iWon: Bool? {
        guard let match, match.status == .finished, let winner = match.winnerUserID else { return nil }
        return winner == myUserID
    }

    // MARK: - Lifecycle

    func host(game: CanonicalGameID, playerName: String, playerEmoji: String, initialStateJSON: String) async {
        guard phase == .idle || isFailed else { return }
        phase = .working("Creating match…")
        do {
            let created = try await store.create(
                game: game,
                hostName: playerName,
                hostEmoji: playerEmoji,
                initialStateJSON: initialStateJSON
            )
            myUserID = created.hostUserID
            match = created
            phase = .waitingForOpponent
            startWatching(created.id)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func join(game: CanonicalGameID, code: String, playerName: String, playerEmoji: String) async {
        guard phase == .idle || isFailed else { return }
        phase = .working("Joining…")
        do {
            let joined = try await store.join(
                game: game,
                code: code,
                guestName: playerName,
                guestEmoji: playerEmoji
            )
            myUserID = joined.guestUserID
            match = joined
            phase = .active
            startWatching(joined.id)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Send my move: the full post-move snapshot plus whose turn it is now.
    /// `nextTurnIsMine` handles multi-jump checkers / reversi passes where the
    /// same player moves again. Applies optimistically, then reconciles with the
    /// server's row (refetching on failure so both devices stay truthful).
    func sendMove(stateJSON: String, nextTurnIsMine: Bool, finished: Bool = false, winnerIsMe: Bool? = nil) async {
        guard let current = match, let myUserID,
              let opponentID = current.opponentID(for: myUserID) else { return }
        let sentCount = current.moveCount + 1
        var optimistic = current
        optimistic.stateJSON = stateJSON
        optimistic.moveCount = sentCount
        optimistic.currentTurnUserID = nextTurnIsMine ? myUserID : opponentID
        if finished {
            optimistic.status = .finished
            optimistic.winnerUserID = winnerIsMe.map { $0 ? myUserID : opponentID }
        }
        match = optimistic
        if finished { phase = .finished }
        do {
            let updated = try await store.submitMove(
                matchID: current.id,
                stateJSON: stateJSON,
                moveCount: sentCount,
                nextTurnUserID: nextTurnIsMine ? myUserID : opponentID,
                finished: finished,
                winnerUserID: finished ? winnerIsMe.map { $0 ? myUserID : opponentID } : nil
            )
            apply(updated)
        } catch {
            lastError = "That move didn't reach your friend — check your connection and try again."
            if let server = try? await store.fetch(id: current.id) {
                apply(server, force: true)
            }
        }
    }

    func resign() async {
        guard let current = match, let myUserID,
              let opponentID = current.opponentID(for: myUserID) else { return }
        phase = .finished
        match?.status = .finished
        match?.winnerUserID = opponentID
        _ = try? await store.setStatus(matchID: current.id, status: .finished, winnerUserID: opponentID)
    }

    /// Host abandons the lobby before anyone joined.
    func cancelHosting() async {
        guard let current = match, current.status == .waiting else { return }
        stop()
        match = nil
        phase = .idle
        _ = try? await store.setStatus(matchID: current.id, status: .cancelled)
    }

    func retryFromFailure() {
        if isFailed { phase = .idle }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    // MARK: - Row watching

    private func startWatching(_ id: UUID) {
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self?.realtimeLoop(id) }
                group.addTask { await self?.pollLoop(id) }
                await group.waitForAll()
            }
        }
    }

    private nonisolated func realtimeLoop(_ id: UUID) async {
        guard let client = Backend.client else { return }
        let channel = client.channel("match-\(id.uuidString.lowercased())")
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "multiplayer_matches",
            filter: .eq("id", value: id.uuidString)
        )
        await channel.subscribe()
        for await change in updates {
            if Task.isCancelled { break }
            if let updated = try? change.decodeRecord(as: OnlineMatch.self, decoder: JSONDecoder()) {
                await self.apply(updated)
            }
        }
        await channel.unsubscribe()
    }

    /// Safety net under realtime: slow, steady refetch. 2.5s keeps turn-based
    /// play feeling live even when the websocket is blocked entirely.
    private nonisolated func pollLoop(_ id: UUID) async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if Task.isCancelled { break }
            let waiting = await self.isWaitingOrActive
            guard waiting else { continue }
            if let fetched = try? await store.fetch(id: id) {
                await self.apply(fetched)
            }
        }
    }

    private var isWaitingOrActive: Bool {
        phase == .waitingForOpponent || phase == .active
    }

    /// Fold a server row into local state, ignoring stale echoes.
    private func apply(_ incoming: OnlineMatch, force: Bool = false) {
        guard let current = match, incoming.id == current.id else { return }
        if !force {
            // Never move backwards: an old poll result must not undo a newer move.
            if incoming.moveCount < current.moveCount { return }
            if incoming.moveCount == current.moveCount,
               incoming.status == current.status,
               incoming.guestUserID == current.guestUserID { return }
        }
        match = incoming
        switch incoming.status {
        case .waiting:
            phase = .waitingForOpponent
        case .active:
            phase = .active
        case .finished:
            phase = .finished
        case .cancelled:
            phase = .failed("The match was cancelled.")
        }
    }

    private static func message(for error: Error) -> String {
        if let matchError = error as? OnlineMatchError {
            return matchError.errorDescription ?? "Something went wrong."
        }
        return "Couldn't reach the game server. Check your internet connection and try again."
    }
}
