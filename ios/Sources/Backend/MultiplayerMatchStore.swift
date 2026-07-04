import Foundation
import Supabase

/// Head-to-head online matches, backed by the `multiplayer_matches` table.
///
/// Flow: the host creates a match and gets a short room code; the friend types
/// the code on their device and claims the guest seat (a single atomic UPDATE —
/// the `status = waiting` filter means exactly one joiner can win the seat).
/// Every move is an UPDATE of the full game snapshot + whose turn it is; both
/// devices watch the row over Supabase Realtime with a polling safety net, so a
/// match survives flaky home Wi-Fi.

enum OnlineMatchStatus: String, Codable, Hashable {
    case waiting
    case active
    case finished
    case cancelled
}

struct OnlineMatch: Codable, Equatable, Hashable {
    var id: UUID
    var roomCode: String
    var gameID: String
    var status: OnlineMatchStatus
    var hostUserID: UUID
    var guestUserID: UUID?
    var hostName: String
    var guestName: String?
    var hostEmoji: String
    var guestEmoji: String?
    var stateJSON: String
    var currentTurnUserID: UUID?
    var moveCount: Int
    var winnerUserID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case roomCode = "room_code"
        case gameID = "game_id"
        case status
        case hostUserID = "host_user_id"
        case guestUserID = "guest_user_id"
        case hostName = "host_name"
        case guestName = "guest_name"
        case hostEmoji = "host_emoji"
        case guestEmoji = "guest_emoji"
        case stateJSON = "state_json"
        case currentTurnUserID = "current_turn_user_id"
        case moveCount = "move_count"
        case winnerUserID = "winner_user_id"
    }

    var canonicalGame: CanonicalGameID? { CanonicalGameID(rawValue: gameID) }

    func isHost(_ userID: UUID) -> Bool { hostUserID == userID }

    func opponentID(for userID: UUID) -> UUID? {
        isHost(userID) ? guestUserID : hostUserID
    }

    func opponentName(for userID: UUID) -> String? {
        isHost(userID) ? guestName : hostName
    }

    func opponentEmoji(for userID: UUID) -> String? {
        isHost(userID) ? guestEmoji : hostEmoji
    }
}

enum OnlineMatchError: LocalizedError, Equatable {
    case notConfigured
    case notSignedIn
    case codeNotFound
    case codeConflict
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Online play isn't configured in this build."
        case .notSignedIn:
            return "Couldn't reach the game server. Check your internet connection and try again."
        case .codeNotFound:
            return "No open match with that code. Double-check the code (and that you're both in the same game)."
        case .codeConflict:
            return "Couldn't get a room code — please try again."
        case .rateLimited:
            return "Please slow down and try again in a moment."
        }
    }
}

struct OnlineMatchStore {
    static let shared = OnlineMatchStore()

    private var client: SupabaseClient? { Backend.client }

    /// Room codes avoid look-alike characters (0/O, 1/I/L) so they survive being
    /// read out loud across a room.
    static let roomCodeAlphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    static let roomCodeLength = 4

    static func generateRoomCode() -> String {
        String((0..<roomCodeLength).compactMap { _ in roomCodeAlphabet.randomElement() })
    }

    static func normalizedRoomCode(_ raw: String) -> String {
        raw.uppercased().filter { roomCodeAlphabet.contains($0) }
    }

    /// The Supabase session uid — the identity RLS sees. Signs in anonymously if
    /// no session exists yet (e.g. the app launched offline and recovered).
    func sessionUserID() async -> UUID? {
        guard let client else { return nil }
        if let uid = try? await client.auth.session.user.id { return uid }
        return try? await client.auth.signInAnonymously().user.id
    }

    func create(
        game: CanonicalGameID,
        hostName: String,
        hostEmoji: String,
        initialStateJSON: String
    ) async throws -> OnlineMatch {
        guard let client else { throw OnlineMatchError.notConfigured }
        guard let uid = await sessionUserID() else { throw OnlineMatchError.notSignedIn }
        guard await AppSecurity.allowClientAction(.onlineMatchCreate, scope: uid.uuidString) else {
            throw OnlineMatchError.rateLimited
        }
        var lastError: Error = OnlineMatchError.codeConflict
        for _ in 0..<4 {
            let match = OnlineMatch(
                id: UUID(),
                roomCode: Self.generateRoomCode(),
                gameID: game.rawValue,
                status: .waiting,
                hostUserID: uid,
                guestUserID: nil,
                hostName: AppSecurity.sanitizedDisplayName(hostName),
                guestName: nil,
                hostEmoji: AppSecurity.sanitizedAvatarEmoji(hostEmoji),
                guestEmoji: nil,
                stateJSON: initialStateJSON,
                currentTurnUserID: uid,   // host always moves first
                moveCount: 0,
                winnerUserID: nil
            )
            do {
                let created: OnlineMatch = try await client
                    .from("multiplayer_matches")
                    .insert(match)
                    .select()
                    .single()
                    .execute()
                    .value
                return created
            } catch {
                // Most likely a live-code unique collision — regenerate and retry.
                lastError = error
                continue
            }
        }
        throw lastError
    }

    func join(
        game: CanonicalGameID,
        code: String,
        guestName: String,
        guestEmoji: String
    ) async throws -> OnlineMatch {
        guard let client else { throw OnlineMatchError.notConfigured }
        guard let uid = await sessionUserID() else { throw OnlineMatchError.notSignedIn }
        guard await AppSecurity.allowClientAction(.onlineMatchJoin, scope: uid.uuidString) else {
            throw OnlineMatchError.rateLimited
        }
        struct SeatClaim: Encodable {
            let guest_user_id: UUID
            let guest_name: String
            let guest_emoji: String
            let status: String
        }
        // Atomic seat claim: the `status = waiting` filter re-evaluates under the
        // row lock, so if two people race the same code only one update matches.
        let rows: [OnlineMatch] = try await client
            .from("multiplayer_matches")
            .update(SeatClaim(
                guest_user_id: uid,
                guest_name: AppSecurity.sanitizedDisplayName(guestName),
                guest_emoji: AppSecurity.sanitizedAvatarEmoji(guestEmoji),
                status: OnlineMatchStatus.active.rawValue
            ))
            .eq("room_code", value: Self.normalizedRoomCode(code))
            .eq("game_id", value: game.rawValue)
            .eq("status", value: OnlineMatchStatus.waiting.rawValue)
            .select()
            .execute()
            .value
        guard let match = rows.first else { throw OnlineMatchError.codeNotFound }
        return match
    }

    func fetch(id: UUID) async throws -> OnlineMatch {
        guard let client else { throw OnlineMatchError.notConfigured }
        return try await client
            .from("multiplayer_matches")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    @discardableResult
    func submitMove(
        matchID: UUID,
        stateJSON: String,
        moveCount: Int,
        nextTurnUserID: UUID,
        finished: Bool = false,
        winnerUserID: UUID? = nil
    ) async throws -> OnlineMatch {
        guard let client else { throw OnlineMatchError.notConfigured }
        guard await AppSecurity.allowClientAction(.onlineMatchMove, scope: matchID.uuidString) else {
            throw OnlineMatchError.rateLimited
        }
        struct MovePatch: Encodable {
            let state_json: String
            let move_count: Int
            let current_turn_user_id: UUID
            let status: String
            let winner_user_id: UUID?
        }
        return try await client
            .from("multiplayer_matches")
            .update(MovePatch(
                state_json: stateJSON,
                move_count: moveCount,
                current_turn_user_id: nextTurnUserID,
                status: (finished ? OnlineMatchStatus.finished : OnlineMatchStatus.active).rawValue,
                winner_user_id: winnerUserID
            ))
            .eq("id", value: matchID.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    @discardableResult
    func setStatus(
        matchID: UUID,
        status: OnlineMatchStatus,
        winnerUserID: UUID? = nil
    ) async throws -> OnlineMatch {
        guard let client else { throw OnlineMatchError.notConfigured }
        guard await AppSecurity.allowClientAction(.onlineMatchMove, scope: matchID.uuidString) else {
            throw OnlineMatchError.rateLimited
        }
        struct StatusPatch: Encodable {
            let status: String
            let winner_user_id: UUID?
        }
        return try await client
            .from("multiplayer_matches")
            .update(StatusPatch(status: status.rawValue, winner_user_id: winnerUserID))
            .eq("id", value: matchID.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}
