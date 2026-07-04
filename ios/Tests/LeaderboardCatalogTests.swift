import XCTest
@testable import Kaleidoscope

final class LeaderboardCatalogTests: XCTestCase {
    func testCheckersIsRankedAsHighScoreGame() {
        XCTAssertEqual(LeaderboardCatalog.metric(for: .checkers), .highScore)
        XCTAssertTrue(LeaderboardCatalog.ranked(friendsOnly: false).contains(.checkers))
        XCTAssertTrue(LeaderboardCatalog.ranked(friendsOnly: true).contains(.checkers))
        XCTAssertEqual(LeaderboardCatalog.title(for: .checkers), "Checkers")
    }

    func testWordgameIsFriendsOnlyDailyLeaderboard() {
        XCTAssertEqual(LeaderboardCatalog.metric(for: .wordle), .fewestMoves)
        XCTAssertTrue(LeaderboardCatalog.ranked(friendsOnly: true).contains(.wordle))
        XCTAssertFalse(LeaderboardCatalog.ranked(friendsOnly: false).contains(.wordle))
        XCTAssertEqual(LeaderboardCatalog.title(for: .wordle), "Wordgame")
        XCTAssertEqual(LeaderboardCatalog.period(for: .wordle), .daily)
    }

    func testLeaderboardStoreKeepsLocalScoreWhenBackendIsUnavailable() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let accountID = UUID()

        try await store.submitBest(
            LeaderboardRow(
                userID: accountID,
                gameID: CanonicalGameID.checkers.rawValue,
                score: 400,
                displayName: "Dad",
                avatarEmoji: "🎴",
                avatarColor: "B88A2E"
            ),
            game: .checkers
        )

        let rows = try await store.top(game: .checkers, limit: 10)

        XCTAssertEqual(rows.map(\.userID), [accountID])
        XCTAssertEqual(rows.map(\.score), [400])
        XCTAssertEqual(rows.map(\.displayName), ["Dad"])
    }

    func testRankedScoresArePersistedUnderStorageID() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let accountID = UUID()
        let storageID = LeaderboardCatalog.storageID(for: .checkers)

        try await store.submitBest(
            LeaderboardRow(
                userID: accountID,
                gameID: CanonicalGameID.checkers.rawValue,
                score: 300,
                displayName: "Dad",
                avatarEmoji: "🎴",
                avatarColor: "B88A2E"
            ),
            game: .checkers
        )

        let rows = try await store.top(game: .checkers, limit: 10)
        let persistedRows = try JSONDecoder().decode([LeaderboardRow].self, from: Data(contentsOf: fileURL))

        XCTAssertEqual(rows.map(\.userID), [accountID])
        XCTAssertEqual(persistedRows.map(\.gameID), [storageID])
    }

    func testWordgameFriendsOnlyLeaderboardUsesDailyStorageAndFriendFilter() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let friendID = UUID()
        let strangerID = UUID()
        let storageID = LeaderboardCatalog.storageID(for: .wordle)

        try await store.submitBest(
            LeaderboardRow(
                userID: friendID,
                gameID: CanonicalGameID.wordle.rawValue,
                score: 4,
                displayName: "Friend",
                avatarEmoji: "🟩",
                avatarColor: "65A05A"
            ),
            game: .wordle
        )
        try await store.submitBest(
            LeaderboardRow(
                userID: strangerID,
                gameID: CanonicalGameID.wordle.rawValue,
                score: 2,
                displayName: "Stranger",
                avatarEmoji: "⬜️",
                avatarColor: "AAAAAA"
            ),
            game: .wordle
        )

        let friendRows = try await store.top(game: .wordle, friendIDs: [friendID], limit: 10)
        let globalRows = try await store.top(game: .wordle, limit: 10)
        let persistedRows = try JSONDecoder().decode([LeaderboardRow].self, from: Data(contentsOf: fileURL))

        XCTAssertEqual(friendRows.map(\.userID), [friendID])
        XCTAssertEqual(friendRows.map(\.score), [4])
        XCTAssertTrue(globalRows.isEmpty)
        XCTAssertEqual(Set(persistedRows.map(\.gameID)), [storageID])
    }

    func testWordgameFriendsOnlyLeaderboardCanMatchSupabaseRowsByGameCenterID() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let gameCenterFriendID = UUID()
        let supabaseFriendID = UUID()
        let strangerID = UUID()

        try await store.submitBest(
            LeaderboardRow(
                userID: supabaseFriendID,
                gameID: CanonicalGameID.wordle.rawValue,
                score: 4,
                displayName: "Benjamin",
                avatarEmoji: "🟩",
                avatarColor: "65A05A",
                gcAccountID: gameCenterFriendID
            ),
            game: .wordle
        )
        try await store.submitBest(
            LeaderboardRow(
                userID: strangerID,
                gameID: CanonicalGameID.wordle.rawValue,
                score: 2,
                displayName: "Stranger",
                avatarEmoji: "⬜️",
                avatarColor: "AAAAAA"
            ),
            game: .wordle
        )

        let rows: [LeaderboardRow] = try await store.top(
            game: .wordle,
            friendIDs: [gameCenterFriendID],
            limit: 10
        )

        XCTAssertEqual(rows.map(\.userID), [supabaseFriendID])
        XCTAssertEqual(rows.map(\.displayName), ["Benjamin"])
    }

    func testWordgameFriendsOnlyLeaderboardDoesNotMatchRowsWithoutSharedGameCenterIdentity() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let gameCenterFriendID = GameCenterIdentity.stableUUID(fromTeamPlayerID: "friend-team-player-id")
        let supabaseFriendID = UUID()

        try await store.submitBest(
            LeaderboardRow(
                userID: supabaseFriendID,
                gameID: CanonicalGameID.wordle.rawValue,
                score: 4,
                displayName: "Pudgy Boiiiiii",
                avatarEmoji: "🟩",
                avatarColor: "65A05A"
            ),
            game: .wordle
        )

        let rows: [LeaderboardRow] = try await store.top(
            game: .wordle,
            friendIDs: [gameCenterFriendID],
            limit: 10
        )

        XCTAssertTrue(rows.isEmpty)
    }

    func testCrossDeviceRowsCollapseToOnePlayerKeepingBest() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let gcID = GameCenterIdentity.stableUUID(fromTeamPlayerID: "sage-team-player-id")
        let iPhoneUID = UUID()
        let iPadUID = UUID()

        // Same human, two devices: distinct auth uids, one Game Center id.
        try await store.submitBest(
            LeaderboardRow(
                userID: iPhoneUID,
                gameID: CanonicalGameID.snake.rawValue,
                score: 42,
                displayName: "Sage",
                avatarEmoji: "🐍",
                avatarColor: "65A05A",
                gcAccountID: gcID
            ),
            game: .snake
        )
        try await store.submitBest(
            LeaderboardRow(
                userID: iPadUID,
                gameID: CanonicalGameID.snake.rawValue,
                score: 99,
                displayName: "Sage",
                avatarEmoji: "🐍",
                avatarColor: "65A05A",
                gcAccountID: gcID
            ),
            game: .snake
        )

        let rows = try await store.top(game: .snake, limit: 10)

        XCTAssertEqual(rows.count, 1, "one human should show once, not once per device")
        XCTAssertEqual(rows.first?.score, 99)
        XCTAssertEqual(rows.first?.canonicalPlayerID, gcID)
    }

    func testLeaderboardScoreRemainsPendingWhenUploadIsUnavailable() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let store = LeaderboardStore(clientProvider: { nil }, localStore: localStore)
        let accountID = UUID()

        try await store.submitBest(
            LeaderboardRow(
                userID: accountID,
                gameID: CanonicalGameID.checkers.rawValue,
                score: 200,
                displayName: "Dad",
                avatarEmoji: "🎴",
                avatarColor: "B88A2E"
            ),
            game: .checkers
        )

        let pending = try await localStore.pendingUploads(game: .checkers)

        XCTAssertEqual(pending.map(\.userID), [accountID])
        XCTAssertEqual(pending.map(\.score), [200])
    }

    func testLeaderboardTopAutomaticallyUploadsPendingScores() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("leaderboard-\(UUID().uuidString).json")
        let localStore = LocalLeaderboardStore(fileURL: fileURL)
        let accountID = UUID()
        let offlineStore = LeaderboardStore(clientProvider: { nil }, localStore: localStore)

        try await offlineStore.submitBest(
            LeaderboardRow(
                userID: accountID,
                gameID: CanonicalGameID.checkers.rawValue,
                score: 200,
                displayName: "Dad",
                avatarEmoji: "🎴",
                avatarColor: "B88A2E"
            ),
            game: .checkers
        )

        actor UploadRecorder {
            private(set) var rows: [LeaderboardRow] = []
            func record(_ row: LeaderboardRow) { rows.append(row) }
            func snapshot() -> [LeaderboardRow] { rows }
        }
        let recorder = UploadRecorder()
        let syncingStore = LeaderboardStore(
            clientProvider: { nil },
            localStore: localStore,
            remoteSubmitter: { row, _ in await recorder.record(row) }
        )

        _ = try await syncingStore.top(game: .checkers, limit: 10)

        let uploaded = await recorder.snapshot()
        let pending = try await localStore.pendingUploads(game: .checkers)
        XCTAssertEqual(uploaded.map(\.userID), [accountID])
        XCTAssertEqual(uploaded.map(\.gameID), [LeaderboardCatalog.storageID(for: .checkers)])
        XCTAssertTrue(pending.isEmpty)
    }
}
