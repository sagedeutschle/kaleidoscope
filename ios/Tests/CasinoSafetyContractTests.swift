import XCTest

final class CasinoSafetyContractTests: XCTestCase {
    private let disclosure = "Practice only. No money, purchases, wagering, prizes, rewards, or transferable value."

    func testPermanentNoMoneyDisclosureIsExactAtTheEntryGateAndStudyLab() {
        XCTAssertTrue(gateSource.contains(disclosure))
        XCTAssertTrue(studyLabSource.contains(disclosure))
    }

    func testCasinoDoesNotContainEconomicOrRetentionMechanics() {
        let normalized = casinoSources.values.joined(separator: "\n")
            .replacingOccurrences(of: disclosure, with: "")
            .replacingOccurrences(of: "Practice only. No money, purchases, wagering, prizes, or rewards.", with: "")
            .lowercased()
        let prohibited = [
            "balance", "bankroll", "chip", "stake", "payout", "jackpot", "buy-in", "cash out",
            "timer", "countdown", "autoplay", "auto-play", "auto round", "auto-round", "auto-next",
            "streak", "near miss", "near-miss", "economy", "reward", "advertisement", "bannerad",
            "account", "leaderboard", "persistent aggregate", "aggregate stats",
        ]

        for term in prohibited {
            XCTAssertFalse(normalized.contains(term), "Casino safety surface contains prohibited mechanic: \(term)")
        }
    }

    func testCasinoDoesNotReferenceSocialOrMonetizationFrameworkIdentifiers() {
        let normalized = casinoSources.values.joined(separator: "\n").lowercased()

        for identifier in ["gamecenter", "storekit", "removeads"] {
            XCTAssertFalse(normalized.contains(identifier), "Casino safety surface contains prohibited identifier: \(identifier)")
        }
    }

    func testStudyLabIsExplicitActionOnlyAndHasNoAutomaticRoundTrigger() {
        XCTAssertTrue(sessionSource.contains("func newRound()"))
        XCTAssertTrue(studyLabSource.contains("snapshot.secondaryNewRoundTitle"))
        XCTAssertFalse(studyLabSource.contains("Timer."))
        XCTAssertFalse(studyLabSource.contains("onReceive"))
        XCTAssertFalse(studyLabSource.contains("onChange(of: snapshot"))
        XCTAssertFalse(sessionSource.contains("Timer."))
        XCTAssertFalse(sessionSource.contains("onReceive"))
    }

    func testStudyLabOwnsOneDisclosureAndOrderedAuditWhileHubOwnsRulesFairness() {
        XCTAssertTrue(studyLabSource.contains(disclosure))
        XCTAssertEqual(studyLabSource.components(separatedBy: disclosure).count - 1, 1)
        XCTAssertTrue(studyLabSource.contains("Text(\"Ordered audit\")"))
        XCTAssertFalse(studyLabSource.contains("session.descriptor.rules"))
        XCTAssertFalse(studyLabSource.contains("session.descriptor.fairness"))
        XCTAssertTrue(casinoSources["CasinoHubView.swift", default: ""].contains("casinoSession.descriptor.rules"))
        XCTAssertTrue(casinoSources["CasinoHubView.swift", default: ""].contains("casinoSession.descriptor.fairness"))
    }

    func testStudyLabAuditAccessibilityAndControlHintAgreeAboutReusedOriginalDealSeeds() {
        XCTAssertTrue(studyLabSource.contains("seed.seedUsage"))
        XCTAssertTrue(studyLabSource.contains("seed.seedUsage.displayText"))
        XCTAssertFalse(studyLabSource.contains("auditSeedUsageText("))
        XCTAssertFalse(studyLabSource.contains("auditSeedUsageAccessibilityText("))
    }

    func testPracticeCasinoPreviewSeedIsStatefulAndProductionStillUsesSecureRandomness() {
        XCTAssertTrue(sessionSource.contains("convenience init(previewSeed: UInt64?)"))
        XCTAssertFalse(sessionSource.contains("convenience init(previewSeed: UInt64? = nil)"))
        XCTAssertTrue(sessionSource.contains("var nextPreviewSeed = previewSeed"))
        XCTAssertTrue(sessionSource.contains("defer { nextPreviewSeed &+= 1 }"))
        XCTAssertTrue(sessionSource.contains("UInt64.random(in: .min ... .max)"))
    }

    func testSafetyScanEnumeratesEveryCasinoSwiftSourceIncludingEachTableFamily() throws {
        let expectedFiles: Set<String> = [
            "CasinoEntryGateView.swift", "CasinoFairPlayView.swift", "CasinoHubView.swift",
            "CasinoPlayingCardView.swift", "CasinoTheme.swift", "PracticeBlackjackSession.swift",
            "PracticeBlackjackStore.swift", "PracticeBlackjackView.swift", "PracticeCasinoSession.swift",
            "PracticeChanceGameView.swift", "PracticePokerView.swift", "PracticeStudyLabView.swift",
        ]

        XCTAssertEqual(Set(casinoSources.keys), expectedFiles)
        XCTAssertFalse(try XCTUnwrap(casinoSources["PracticeBlackjackView.swift"]).isEmpty)
        XCTAssertFalse(try XCTUnwrap(casinoSources["PracticeChanceGameView.swift"]).isEmpty)
        XCTAssertFalse(try XCTUnwrap(casinoSources["PracticePokerView.swift"]).isEmpty)
    }

    private var gateSource: String { casinoSources["CasinoEntryGateView.swift", default: ""] }
    private var hubSource: String { casinoSources["CasinoHubView.swift", default: ""] }
    private var sessionSource: String { casinoSources["PracticeCasinoSession.swift", default: ""] }
    private var studyLabSource: String { casinoSources["PracticeStudyLabView.swift", default: ""] }

    private var casinoSources: [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Casino", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )) ?? []
        return Dictionary(uniqueKeysWithValues: files
            .filter { $0.pathExtension == "swift" }
            .map { ($0.lastPathComponent, (try? String(contentsOf: $0)) ?? "") })
    }
}
