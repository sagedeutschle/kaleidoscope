import XCTest
import PrismetShared
@testable import Prismet

final class CasinoSafetyContractTests: XCTestCase {
    private let expectedCasinoSourceFiles: Set<String> = [
        "CasinoEntryGateView.swift", "CasinoHubView.swift", "PracticeBlackjackView.swift",
        "PracticeBlackjackSession.swift", "PracticeBlackjackStore.swift", "CasinoPlayingCardView.swift",
        "CasinoFairPlayView.swift", "CasinoTheme.swift", "PracticeCasinoSession.swift",
        "PracticeChanceGameView.swift", "PracticePokerView.swift", "PracticeStudyLabView.swift",
    ]

    func testCasinoSourceFileSetExactlyMatchesEveryProductionSwiftSurface() throws {
        let actualFiles = try Set(FileManager.default.contentsOfDirectory(
            at: casinoSourceRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "swift" }
        .map(\.lastPathComponent))

        XCTAssertEqual(
            actualFiles,
            expectedCasinoSourceFiles,
            "Every Swift file present in Sources/Casino must be scanned; update this contract deliberately when adding or removing a production surface."
        )
    }

    func testGateHeaderAndAllResetDialogsUseTheSameNoValueVisitStateContract() throws {
        let gate = try source("CasinoEntryGateView.swift")
        let chance = try source("PracticeChanceGameView.swift")
        let poker = try source("PracticePokerView.swift")
        let reset = "Adults 18+ only. This clears Chance, Poker, and Study Lab visit state; no money, purchases, wagering, prizes, rewards, or transferable value are involved. Existing Blackjack audit save is preserved."

        XCTAssertTrue(gate.contains("Adults 18+ only"))
        XCTAssertTrue(gate.contains("This screen does not verify age"))
        XCTAssertTrue(gate.contains("the access decision is not stored"))
        XCTAssertTrue(gate.contains("Practice only. No money, purchases, wagering, prizes, rewards, or transferable value."))
        XCTAssertTrue(chance.contains(reset))
        XCTAssertTrue(poker.contains(reset))
    }

    func testCasinoContainsNoMoneyEconomyPressureOrPersistentAggregateMechanics() throws {
        let source = try combinedSource()
        XCTAssertTrue(source.contains("Practice only. No money, purchases, wagering, prizes, or rewards."))
        XCTAssertTrue(source.contains("no money or transferable value"))
        for pattern in [
            #"\bbalance\b"#, #"\bchip(s)?\b"#, #"\bbet(s|ting)?\b"#, #"\bstake(s)?\b"#,
            #"\bpayout(s)?\b"#, #"\bjackpot(s)?\b"#, #"\brefill(s)?\b"#, #"\bstreak(s)?\b"#,
            #"\bcountdown\b"#, #"near[- ]miss"#, #"loss recovery"#, #"win chance"#,
            #"auto(matic)?[- ]?(deal|play|hand)"#, #"persistent aggregate"#,
        ] {
            XCTAssertNil(source.range(of: pattern, options: [.regularExpression, .caseInsensitive]), "Casino source introduced prohibited pattern: \(pattern)")
        }
        for prohibited in ["GameCenter", "StoreKit", "RemoveAds", "Leaderboard", "Account", "BannerAd", "Timer.publish", "scheduledTimer", "DispatchQueue.main.asyncAfter", "onReceive"] {
            XCTAssertFalse(source.contains(prohibited), "Casino source must not depend on \(prohibited)")
        }
    }

    func testEveryInteractiveCasinoSurfaceHasKeyboardFocusAndMotionAccessibilityHooks() throws {
        for file in ["PracticeBlackjackView.swift", "PracticeChanceGameView.swift", "PracticePokerView.swift", "PracticeStudyLabView.swift"] {
            let source = try source(file)
            XCTAssertTrue(source.contains("accessibilityReduceMotion"), "\(file) needs Reduce Motion")
            XCTAssertTrue(source.contains("accessibilityDifferentiateWithoutColor"), "\(file) needs non-color cues")
            XCTAssertTrue(source.contains(".onExitCommand"), "\(file) needs Escape leave")
            XCTAssertTrue(source.contains(".accessibilityLabel"), "\(file) needs VoiceOver labels")
        }
    }

    func testStudyLabUsesNoTimersAutoplayOrRewardLanguageWhileShowingAuditAndLedger() throws {
        let study = try source("PracticeStudyLabView.swift")
        XCTAssertTrue(study.contains("Exact counts & probabilities"))
        XCTAssertTrue(study.contains("row.value.displayText"))
        XCTAssertTrue(study.contains("snapshot.audit"))
        XCTAssertTrue(study.contains("New Round"))
        XCTAssertFalse(study.localizedCaseInsensitiveContains("autoplay"))
        XCTAssertFalse(study.localizedCaseInsensitiveContains("reward balance"))
    }

    func testStudyLabErrorAndPaiGowSelectionAccessibilityRemainExplicit() throws {
        let study = try source("PracticeStudyLabView.swift")

        for required in [
            "session.errorMessage", "Study Lab error:", "accessibilityDifferentiateWithoutColor",
            "checkmark.circle.fill", "selected || snapshot.selectedPaiGowCardIndices.count < 2",
            ".disabled(!canTogglePaiGowCard)", "Activate to deselect it.",
        ] {
            XCTAssertTrue(study.contains(required), "Study Lab must retain \(required)")
        }
    }

    func testMacCasinoRetainsResetConfirmationAndNativeAccessibilitySafetyHooks() throws {
        let source = try combinedSource()
        for required in ["confirmationDialog", "accessibilityDifferentiateWithoutColor", "accessibilityReduceMotion", "focused(", "onExitCommand"] {
            XCTAssertTrue(source.contains(required), "Mac Casino must retain \(required)")
        }
    }

    private var casinoSourceRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/Casino", isDirectory: true)
    }

    private func source(_ file: String) throws -> String {
        try String(contentsOf: casinoSourceRoot.appendingPathComponent(file), encoding: .utf8)
    }

    private func combinedSource() throws -> String {
        try expectedCasinoSourceFiles.sorted().map(source).joined(separator: "\n")
    }
}
