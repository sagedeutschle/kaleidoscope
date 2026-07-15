import XCTest
import PrismetShared
@testable import Prismet

final class CasinoSafetyContractTests: XCTestCase {
    private let requiredSourceFiles = [
        "CasinoHubView.swift",
        "PracticeBlackjackView.swift",
        "PracticeBlackjackSession.swift",
        "PracticeBlackjackStore.swift",
        "CasinoPlayingCardView.swift",
        "CasinoFairPlayView.swift",
        "CasinoTheme.swift",
        "PracticeCasinoSession.swift",
        "PracticeChanceGameView.swift",
        "PracticePokerView.swift",
    ]

    func testCasinoSourceContainsEveryIsolatedProductionFile() {
        for file in requiredSourceFiles {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: casinoSourceRoot.appendingPathComponent(file).path),
                "Missing production Casino file: \(file)"
            )
        }
    }

    func testCasinoUsesExactSafetyDisclosureWithoutEconomyOrPressureMechanics() throws {
        var source = try combinedSource()
        let disclosure = "Practice only. No money, purchases, wagering, prizes, or rewards."
        XCTAssertTrue(source.contains(disclosure))
        source = source.replacingOccurrences(of: disclosure, with: "")

        let prohibitedPatterns = [
            #"\bbalance\b"#, #"\bchip(s)?\b"#, #"\bbet(s|ting)?\b"#,
            #"\bstake(s)?\b"#, #"\bpayout(s)?\b"#, #"\bjackpot(s)?\b"#,
            #"\brefill(s)?\b"#, #"\bstreak(s)?\b"#, #"\bcountdown\b"#,
            #"near[- ]miss"#, #"loss recovery"#, #"win chance"#,
            #"auto(matic)?[- ]?(deal|play|hand)"#,
        ]

        for pattern in prohibitedPatterns {
            XCTAssertNil(
                source.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                "Casino source introduced prohibited pattern: \(pattern)"
            )
        }
    }

    func testCasinoHasNoAccountLeaderboardAdOrTimerDependencies() throws {
        let source = try combinedSource()
        for prohibited in ["GameCenter", "Leaderboard", "Account", "BannerAd", "Timer.publish", "scheduledTimer"] {
            XCTAssertFalse(source.contains(prohibited), "Casino source must not depend on \(prohibited)")
        }
    }

    func testMacSurfacePinsNativeKeyboardFocusAndAccessibilityAdaptation() throws {
        let source = try String(
            contentsOf: casinoSourceRoot.appendingPathComponent("PracticeBlackjackView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("@FocusState"))
        XCTAssertTrue(source.contains("accessibilityReduceMotion"))
        XCTAssertTrue(source.contains("accessibilityDifferentiateWithoutColor"))
        XCTAssertTrue(source.contains(".keyboardShortcut(\"h\""))
        XCTAssertTrue(source.contains(".keyboardShortcut(\"s\""))
        XCTAssertTrue(source.contains(".keyboardShortcut(\"r\""))
        XCTAssertTrue(source.contains(".onKeyPress(.return"))
        XCTAssertTrue(source.contains(".onExitCommand"))
        XCTAssertTrue(source.contains(".accessibilityLabel"))
    }

    func testMacCasinoSurfaceContainsAllRoutesAndExplicitSessionActions() throws {
        let source = try combinedSource()
        XCTAssertTrue(source.contains("PrismetPracticeCasinoCatalog.all"))
        XCTAssertTrue(source.contains("PrismetPracticeCasinoCatalog[session.selectedGameID]"))
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.id)), Set(PrismetPracticeCasinoGameID.allCases))
        XCTAssertTrue(source.contains("Reset Session"))
        XCTAssertTrue(source.contains("Leave Game"))
        XCTAssertTrue(source.contains("onExitCommand"))
        XCTAssertTrue(source.contains("accessibilityReduceMotion"))
        XCTAssertTrue(source.contains("accessibilityDifferentiateWithoutColor"))
        XCTAssertTrue(source.contains("ScrollView"))
        XCTAssertFalse(source.contains("Timer"))
        XCTAssertFalse(source.contains("onReceive"))
        XCTAssertFalse(source.contains("DispatchQueue.main.asyncAfter"))
    }

    func testMacSafetyKeepsTheExactDisclosureAndNoValueMechanics() throws {
        let source = try combinedSource()
        XCTAssertTrue(source.contains("Practice only. No money, purchases, wagering, prizes, or rewards."))
        XCTAssertTrue(source.contains("no money or transferable value"))
        XCTAssertFalse(source.localizedCaseInsensitiveContains("reward".appending(" balance")))
    }

    func testMacFairPlaySurfacesResetConfirmationAndNonColorCues() throws {
        let source = try combinedSource()
        XCTAssertTrue(source.contains("confirmationDialog"))
        XCTAssertTrue(source.contains("accessibilityDifferentiateWithoutColor"))
        XCTAssertTrue(source.contains("accessibilityReduceMotion"))
        XCTAssertTrue(source.contains("focused("))
        XCTAssertTrue(source.contains("onExitCommand"))
    }

    private var casinoSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Casino", isDirectory: true)
    }

    private func combinedSource() throws -> String {
        try requiredSourceFiles.map { file in
            try String(contentsOf: casinoSourceRoot.appendingPathComponent(file), encoding: .utf8)
        }.joined(separator: "\n")
    }
}
