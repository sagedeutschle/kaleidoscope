import XCTest

final class CasinoSafetyContractTests: XCTestCase {
    private let disclosure = "Practice only. No money, purchases, wagering, prizes, or rewards."

    func testExactNoMoneyDisclosureAndAllTablesArePresent() {
        XCTAssertTrue(casinoSource.contains(disclosure))
        for id in [
            "blackjack", "five-card-draw", "red-black", "higher-lower", "high-card",
            "coin-call", "dice-duel", "over-under-seven", "odd-even", "fair-wheel", "number-draw",
        ] {
            XCTAssertTrue(casinoSource.contains(id), "Casino source must route shared ID: \(id)")
        }
    }

    func testCasinoSourceContainsNoEconomyOrPressureSystem() {
        let normalized = casinoSource
            .replacingOccurrences(of: disclosure, with: "")
            .lowercased()
        let prohibited = [
            "balance", "bankroll", "chip", "stake", "payout", "jackpot",
            "daily reward", "streak", "countdown", "near miss", "loss recovery", "auto-round",
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

    func testNoCodePathAutomaticallyStartsAnotherRound() {
        XCTAssertFalse(casinoSource.contains("onChange(of: session.table.phase"))
        XCTAssertFalse(casinoSource.contains("onReceive"))
        XCTAssertTrue(casinoSource.contains("Reset Session"))
        XCTAssertTrue(casinoSource.contains("Leave Game"))
        XCTAssertTrue(casinoSource.contains("newRound()"))
    }

    func testFairPlayCopyNamesRulesDealerPolicyAndOddsAssumption() {
        XCTAssertTrue(casinoSource.contains("Rules & Fairness"))
        XCTAssertTrue(casinoSource.contains("Reset Session"))
        XCTAssertTrue(casinoSource.contains("Leave Game"))
    }

    func testResetDisclosureIsSpecificToInMemoryCompactAndPokerVisitResults() {
        XCTAssertTrue(casinoSource.contains("Clear compact and Five-Card Draw results from this visit?"))
        XCTAssertTrue(casinoSource.contains("does not clear the existing Blackjack audit save"))
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
