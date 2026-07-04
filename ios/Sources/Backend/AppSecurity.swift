import Foundation

enum AppSecurity {
    struct ValidationResult: Equatable {
        var blockers: [String]
        var isValid: Bool { blockers.isEmpty }
    }

    struct RateLimit: Equatable {
        var maxEvents: Int
        var window: TimeInterval
    }

    enum ClientAction: String {
        case profileWrite
        case gameSavePush
        case leaderboardSubmit
        case onlineMatchCreate
        case onlineMatchJoin
        case onlineMatchMove
        case remoteContentFetch
    }

    static let fallbackDisplayName = "Player"
    static let fallbackAvatarEmoji = "🎴"
    static let fallbackAvatarColor = "B88A2E"
    static let clientRateLimiter = SecurityRateLimiter()

    static func allowClientAction(
        _ action: ClientAction,
        scope: String,
        rateLimiter: SecurityRateLimiter = clientRateLimiter,
        now: Date = Date()
    ) async -> Bool {
        await rateLimiter.allow(
            key: "\(action.rawValue):\(scope)",
            limit: rateLimit(for: action),
            now: now
        )
    }

    static func rateLimit(for action: ClientAction) -> RateLimit {
        switch action {
        case .profileWrite:
            return RateLimit(maxEvents: 4, window: 300)
        case .gameSavePush:
            return RateLimit(maxEvents: 20, window: 60)
        case .leaderboardSubmit:
            return RateLimit(maxEvents: 6, window: 60)
        case .onlineMatchCreate:
            return RateLimit(maxEvents: 6, window: 60)
        case .onlineMatchJoin:
            return RateLimit(maxEvents: 12, window: 60)
        case .onlineMatchMove:
            return RateLimit(maxEvents: 120, window: 60)
        case .remoteContentFetch:
            return RateLimit(maxEvents: 10, window: 60)
        }
    }

    static func validateSupabaseConfiguration(urlString: String, anonKey: String) -> ValidationResult {
        var blockers: [String] = []
        guard let url = URL(string: urlString), let host = url.host(percentEncoded: false) else {
            return ValidationResult(blockers: ["Supabase URL is invalid"])
        }
        if url.scheme != "https" {
            blockers.append("Supabase URL must use HTTPS")
        }
        if !host.hasSuffix(".supabase.co") {
            blockers.append("Supabase URL must point at a Supabase project")
        }

        guard let claims = jwtClaims(anonKey) else {
            blockers.append("Supabase key must be a JWT")
            return ValidationResult(blockers: blockers)
        }
        if claims["role"] as? String != "anon" {
            blockers.append("Supabase key must be an anon client key")
        }
        let projectRef = host.split(separator: ".").first.map(String.init)
        if let ref = claims["ref"] as? String, let projectRef, ref != projectRef {
            blockers.append("Supabase key project ref does not match the configured URL")
        }
        return ValidationResult(blockers: blockers)
    }

    static func sanitizedDisplayName(_ value: String) -> String {
        let cleaned = value
            .filter { !$0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallbackDisplayName }
        return String(cleaned.prefix(26))
    }

    static func sanitizedAvatarEmoji(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.first.map(String.init) ?? fallbackAvatarEmoji
    }

    static func sanitizedAvatarColor(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit) else {
            return fallbackAvatarColor
        }
        return cleaned
    }

    private static func jwtClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2, let data = base64URLDecoded(String(parts[1])) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func base64URLDecoded(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}

enum AppSecurityError: LocalizedError {
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            return "Please slow down and try again in a moment."
        }
    }
}

actor SecurityRateLimiter {
    private struct Bucket {
        var windowStart: Date
        var count: Int
    }

    private var buckets: [String: Bucket] = [:]

    func allow(key: String, limit: AppSecurity.RateLimit, now: Date = Date()) -> Bool {
        guard limit.maxEvents > 0, limit.window > 0 else { return false }
        if var bucket = buckets[key],
           now.timeIntervalSince(bucket.windowStart) < limit.window {
            guard bucket.count < limit.maxEvents else { return false }
            bucket.count += 1
            buckets[key] = bucket
            return true
        }
        buckets[key] = Bucket(windowStart: now, count: 1)
        return true
    }
}

extension Profile {
    func sanitizedForClientUpload() -> Profile {
        Profile(
            id: id,
            phone: nil,
            displayName: AppSecurity.sanitizedDisplayName(displayName),
            avatarEmoji: AppSecurity.sanitizedAvatarEmoji(avatarEmoji),
            avatarColor: AppSecurity.sanitizedAvatarColor(avatarColor)
        )
    }
}

extension LeaderboardRow {
    func sanitizedForClientUpload() -> LeaderboardRow {
        LeaderboardRow(
            userID: userID,
            gameID: gameID,
            score: score,
            displayName: AppSecurity.sanitizedDisplayName(displayName),
            avatarEmoji: AppSecurity.sanitizedAvatarEmoji(avatarEmoji),
            avatarColor: AppSecurity.sanitizedAvatarColor(avatarColor),
            gcAccountID: gcAccountID
        )
    }
}
