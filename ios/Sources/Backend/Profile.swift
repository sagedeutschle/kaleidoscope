import Foundation

/// A player profile row in the `profiles` table. Column names are snake_case in
/// Postgres; CodingKeys map them to Swift camelCase. `created_at` is set by the DB
/// default and intentionally not part of this model (we never write or read it here).
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var phone: String?
    var displayName: String
    var avatarEmoji: String
    var avatarColor: String

    enum CodingKeys: String, CodingKey {
        case id, phone
        case displayName = "display_name"
        case avatarEmoji = "avatar_emoji"
        case avatarColor = "avatar_color"
    }

    static let selectedColumns = "id, phone, display_name, avatar_emoji, avatar_color"
}
