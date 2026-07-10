import XCTest
@testable import Prismet

final class AppSecurityTests: XCTestCase {
    func testSupabaseConfigurationAcceptsAnonKeyForMatchingHttpsProject() {
        let key = jwt(role: "anon", ref: "cmufcjysgbiqhohozkrf")

        let result = AppSecurity.validateSupabaseConfiguration(
            urlString: "https://cmufcjysgbiqhohozkrf.supabase.co",
            anonKey: key
        )

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.blockers, [])
    }

    func testSupabaseConfigurationRejectsPrivilegedOrMismatchedKeys() {
        let serviceRoleKey = jwt(role: "service_role", ref: "cmufcjysgbiqhohozkrf")
        let mismatchedAnonKey = jwt(role: "anon", ref: "otherprojectref")

        let serviceRole = AppSecurity.validateSupabaseConfiguration(
            urlString: "https://cmufcjysgbiqhohozkrf.supabase.co",
            anonKey: serviceRoleKey
        )
        let mismatched = AppSecurity.validateSupabaseConfiguration(
            urlString: "https://cmufcjysgbiqhohozkrf.supabase.co",
            anonKey: mismatchedAnonKey
        )

        XCTAssertFalse(serviceRole.isValid)
        XCTAssertTrue(serviceRole.blockers.contains("Supabase key must be an anon client key"))
        XCTAssertFalse(mismatched.isValid)
        XCTAssertTrue(mismatched.blockers.contains("Supabase key project ref does not match the configured URL"))
    }

    func testSupabaseConfigurationRequiresHttpsSupabaseURL() {
        let key = jwt(role: "anon", ref: "cmufcjysgbiqhohozkrf")

        let result = AppSecurity.validateSupabaseConfiguration(
            urlString: "http://cmufcjysgbiqhohozkrf.supabase.co",
            anonKey: key
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.blockers, ["Supabase URL must use HTTPS"])
    }

    func testProfileUploadSanitizesPublicFields() {
        let profile = Profile(
            id: UUID(),
            phone: " 555-0100 ",
            displayName: "\n  Sage\u{0000}TheGreatWithANameThatIsWayTooLong  ",
            avatarEmoji: "   ",
            avatarColor: "not-a-color"
        )

        let sanitized = profile.sanitizedForClientUpload()

        XCTAssertNil(sanitized.phone)
        XCTAssertEqual(sanitized.displayName, "SageTheGreatWithANameThatI")
        XCTAssertEqual(sanitized.avatarEmoji, "🎴")
        XCTAssertEqual(sanitized.avatarColor, "B88A2E")
    }

    func testLeaderboardSubmissionSanitizesPublicFieldsBeforePersistence() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-security-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let accountID = UUID()

        try await store.submitBest(
            LeaderboardRow(
                userID: accountID,
                gameID: CanonicalGameID.checkers.rawValue,
                score: 400,
                displayName: "\u{0000}  WinnerWinnerWinnerWinnerWinner  ",
                avatarEmoji: "",
                avatarColor: "zzzzzz"
            ),
            game: .checkers
        )

        let rows = try JSONDecoder().decode([LeaderboardRow].self, from: Data(contentsOf: fileURL))

        XCTAssertEqual(rows.map(\.displayName), ["WinnerWinnerWinnerWinnerWi"])
        XCTAssertEqual(rows.map(\.avatarEmoji), ["🎴"])
        XCTAssertEqual(rows.map(\.avatarColor), ["B88A2E"])
    }

    func testRateLimiterSlowsRepeatedActionsWithinWindow() async {
        let limiter = SecurityRateLimiter()
        let limit = AppSecurity.RateLimit(maxEvents: 2, window: 10)
        let now = Date(timeIntervalSince1970: 100)

        let first = await limiter.allow(key: "user:new-game", limit: limit, now: now)
        let second = await limiter.allow(key: "user:new-game", limit: limit, now: now.addingTimeInterval(1))
        let third = await limiter.allow(key: "user:new-game", limit: limit, now: now.addingTimeInterval(2))
        let afterWindow = await limiter.allow(key: "user:new-game", limit: limit, now: now.addingTimeInterval(11))

        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertFalse(third)
        XCTAssertTrue(afterWindow)
    }

    func testLeaderboardUploadSpamIsThrottledAndKeptPending() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-throttle-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let limiter = SecurityRateLimiter()
        let accountID = UUID()

        actor UploadRecorder {
            private(set) var rows: [LeaderboardRow] = []
            func record(_ row: LeaderboardRow) { rows.append(row) }
            func count() -> Int { rows.count }
        }
        let recorder = UploadRecorder()
        let store = LeaderboardStore(
            clientProvider: { nil },
            localStore: localStore,
            remoteSubmitter: { row, _ in await recorder.record(row) },
            rateLimiter: limiter
        )

        for score in 1...7 {
            try await store.submitBest(
                LeaderboardRow(
                    userID: accountID,
                    gameID: CanonicalGameID.checkers.rawValue,
                    score: score,
                    displayName: "Dad",
                    avatarEmoji: "🎴",
                    avatarColor: "B88A2E"
                ),
                game: .checkers
            )
        }

        let pending = try await localStore.pendingUploads(game: .checkers)
        let uploadCount = await recorder.count()
        XCTAssertEqual(uploadCount, 6)
        XCTAssertEqual(pending.map(\.score), [7])
    }

    func testPrivilegedAPISecretsAreNotPresentInShippedAppFiles() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scannedRoots = [
            root.appendingPathComponent("Sources"),
            root.appendingPathComponent("Resources"),
            root.appendingPathComponent("Info.plist"),
            root.appendingPathComponent("project.yml")
        ]
        let forbidden = [
            "service_role",
            "sk-",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "BEGIN PRIVATE KEY"
        ]

        for file in try appFiles(in: scannedRoots) {
            let contents = try String(contentsOf: file)
            for marker in forbidden {
                XCTAssertFalse(contents.contains(marker), "\(file.path) contains privileged secret marker \(marker)")
            }
        }
    }

    func testSupabaseSecurityMigrationContainsLaunchHardening() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sqlURL = root.appendingPathComponent("docs/supabase-security-rate-limits.sql")
        let sql = try String(contentsOf: sqlURL)
        let lowercased = sql.lowercased()

        XCTAssertTrue(lowercased.contains("create table if not exists public.api_rate_limits"))
        XCTAssertTrue(lowercased.contains("profiles_rate_limit"))
        XCTAssertTrue(lowercased.contains("game_saves_rate_limit"))
        XCTAssertTrue(lowercased.contains("multiplayer_matches_rate_limit"))
        XCTAssertTrue(lowercased.contains("leaderboard_scores_rate_limit"))
        XCTAssertTrue(lowercased.contains("multiplayer_matches_payload_size"))
        XCTAssertTrue(lowercased.contains("multiplayer_matches_room_code_shape"))
        XCTAssertTrue(lowercased.contains("leaderboard_scores_score_bounds"))
        XCTAssertTrue(lowercased.contains("multiplayer_matches_participant_turn"))
        XCTAssertTrue(lowercased.contains("new.updated_at = now()"))

        let destructivePatterns = [
            #"(?i)\bdelete\s+from\b"#,
            #"(?i)\btruncate\s+table\b"#,
            #"(?i)\bdrop\s+table\b(?!\s+if\s+exists\s+public\.api_rate_limits\b)"#
        ]
        for pattern in destructivePatterns {
            XCTAssertNil(sql.range(of: pattern, options: .regularExpression), "Migration contains destructive pattern: \(pattern)")
        }
    }

    func testSupabaseSecurityProbeScriptIsRedacted() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = root.appendingPathComponent("scripts/probe-supabase-security.py")
        let script = try String(contentsOf: scriptURL)

        XCTAssertTrue(script.contains("READ_ONLY_SUPABASE_PROBE"))
        XCTAssertTrue(script.contains("redact"))
        XCTAssertFalse(script.contains("print(key)"))
        XCTAssertFalse(script.contains("Authorization': 'Bearer '+key"))
    }

    private func jwt(role: String, ref: String) -> String {
        let header = base64URL(#"{"alg":"HS256","typ":"JWT"}"#)
        let payload = base64URL(#"{"role":"\#(role)","ref":"\#(ref)"}"#)
        return "\(header).\(payload).signature"
    }

    private func base64URL(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func appFiles(in roots: [URL]) throws -> [URL] {
        let fileManager = FileManager.default
        var files: [URL] = []
        for root in roots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let file = enumerator?.nextObject() as? URL {
                    let values = try file.resourceValues(forKeys: [.isRegularFileKey])
                    guard values.isRegularFile == true else { continue }
                    guard ["swift", "plist", "json", "yml", "yaml"].contains(file.pathExtension) else { continue }
                    files.append(file)
                }
            } else {
                files.append(root)
            }
        }
        return files
    }
}
