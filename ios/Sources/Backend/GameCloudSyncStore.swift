import Foundation
import Supabase

final class GameCloudSyncStore {
    static let shared = GameCloudSyncStore()

    private var client: SupabaseClient? { Backend.client }

    func push(_ record: GameSaveRecord) async throws {
        guard let client else { return }
        guard await AppSecurity.allowClientAction(
            .gameSavePush,
            scope: "\(record.accountID.uuidString):\(record.gameID.rawValue)"
        ) else { return }
        try await client
            .from("game_saves")
            .upsert(CloudGameSaveRow(record: record), onConflict: "user_id,game_id")
            .execute()
    }

    func pull(accountID: UUID, gameID: CanonicalGameID) async throws -> GameSaveRecord? {
        guard let client else { return nil }
        let row: CloudGameSaveRow = try await client
            .from("game_saves")
            .select()
            .eq("user_id", value: accountID.uuidString)
            .eq("game_id", value: gameID.rawValue)
            .single()
            .execute()
            .value
        return try row.record()
    }
}
