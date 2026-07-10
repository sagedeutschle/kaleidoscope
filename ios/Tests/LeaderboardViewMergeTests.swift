import XCTest
@testable import Prismet

/// Covers the display-layer merge in `LeaderboardView`: the signed-in player's own
/// best row is always unioned into the fetched rows (deduped by user, correctly
/// ranked) so the friends board is never empty for the current player.
final class LeaderboardViewMergeTests: XCTestCase {
    private func row(_ id: UUID, score: Int, name: String = "Player") -> LeaderboardRow {
        LeaderboardRow(
            userID: id,
            gameID: CanonicalGameID.wordle.rawValue,
            score: score,
            displayName: name,
            avatarEmoji: "🟩",
            avatarColor: "65A05A"
        )
    }

    func testOwnRowIsAddedWhenFetchedRowsAreEmpty() {
        let me = UUID()
        let merged = LeaderboardView.merged([], ownRow: row(me, score: 3), game: .wordle)
        XCTAssertEqual(merged.map(\.userID), [me])
        XCTAssertEqual(merged.map(\.score), [3])
    }

    func testOwnRowIsNotDuplicatedAndKeepsBetterScore() {
        let me = UUID()
        // Wordgame is fewest-moves: lower is better. Fetched has a worse (higher) score.
        let fetched = [row(me, score: 5, name: "Me")]
        let merged = LeaderboardView.merged(fetched, ownRow: row(me, score: 3, name: "Me"), game: .wordle)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.map(\.score), [3])
    }

    func testMergedRowIsRankedByMetricForFewestMoves() {
        let me = UUID()
        let friend = UUID()
        // Lower wins: my 2 should sort ahead of the friend's 4.
        let fetched = [row(friend, score: 4, name: "Friend")]
        let merged = LeaderboardView.merged(fetched, ownRow: row(me, score: 2, name: "Me"), game: .wordle)
        XCTAssertEqual(merged.map(\.userID), [me, friend])
    }

    func testMergedRowIsRankedByMetricForHighScore() {
        let me = UUID()
        let friend = UUID()
        // 2048 is high-score: higher wins, so the friend's 900 sorts ahead of my 400.
        let fetched = [row(friend, score: 900, name: "Friend")]
        let merged = LeaderboardView.merged(fetched, ownRow: row(me, score: 400, name: "Me"), game: .game2048)
        XCTAssertEqual(merged.map(\.userID), [friend, me])
    }

    func testNilOwnRowLeavesFetchedRowsUnchanged() {
        let friend = UUID()
        let fetched = [row(friend, score: 4)]
        let merged = LeaderboardView.merged(fetched, ownRow: nil, game: .wordle)
        XCTAssertEqual(merged.map(\.userID), [friend])
    }
}
