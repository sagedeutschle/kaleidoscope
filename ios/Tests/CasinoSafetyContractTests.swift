import XCTest

final class CasinoSafetyContractTests: XCTestCase {
    private let disclosure = "Practice only. No money, purchases, wagering, prizes, or rewards."

    func testExactNoMoneyDisclosureAndComingNextCopyArePresent() {
        XCTAssertTrue(casinoSource.contains(disclosure))
        XCTAssertTrue(casinoSource.contains("Five-Card Poker — Coming next"))
        XCTAssertFalse(casinoSource.contains("NavigationLink"), "Coming-next Poker must not expose a fake route")
    }

    func testCasinoSourceContainsNoEconomyOrPressureSystem() {
        let normalized = casinoSource
            .replacingOccurrences(of: disclosure, with: "")
            .lowercased()
        let prohibited = [
            "balance", "bankroll", "chip", "token", "stake", "payout", "jackpot",
            "daily reward", "streak", "countdown", "near miss", "loss recovery",
            "win chance", "auto-next", "automatic next", "buy-in", "cash value",
        ]

        for term in prohibited {
            XCTAssertFalse(normalized.contains(term), "Casino source contains prohibited term: \(term)")
        }
    }

    func testCasinoDoesNotUseAccountsLeaderboardsPurchasesOrAds() {
        for term in ["accountID", "Leaderboard", "GameCenter", "StoreKit", "BannerAd", "RemoveAds"] {
            XCTAssertFalse(casinoSource.contains(term), "Casino source must remain isolated from \(term)")
        }
    }

    func testNoCodePathAutomaticallyStartsAnotherHand() {
        XCTAssertFalse(casinoSource.contains("onChange(of: session.table.phase"))
        XCTAssertFalse(casinoSource.contains("onReceive"))
        XCTAssertTrue(casinoSource.contains("Button(\"New Hand\")"))
        XCTAssertTrue(casinoSource.contains("session.newHand()"))
    }

    func testFairPlayCopyNamesRulesDealerPolicyAndOddsAssumption() {
        XCTAssertTrue(casinoSource.contains("Practice Blackjack rules v1"))
        XCTAssertTrue(casinoSource.contains("Dealer stands on every 17, including soft 17."))
        XCTAssertTrue(casinoSource.contains("Uses only your cards and the dealer’s face-up card; the hole card and draw pile are treated as unseen."))
        XCTAssertTrue(casinoSource.contains("Replay & Fairness becomes available after this hand ends."))
    }

    private var casinoSource: String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Casino", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? String(contentsOf: $0) }
            .joined(separator: "\n")
    }
}
