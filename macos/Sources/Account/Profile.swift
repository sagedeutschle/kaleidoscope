import Foundation

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
