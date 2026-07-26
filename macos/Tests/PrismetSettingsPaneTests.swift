import XCTest
import SwiftUI
@testable import Prismet

final class PrismetSettingsPaneTests: XCTestCase {
    func testAppStoreShareURLUsesLivePublicListing() {
        XCTAssertEqual(
            PrismetSettingsPane.appStoreURL.absoluteString,
            "https://apps.apple.com/us/app/kaleidescope/id6785993194"
        )
    }

    // MARK: - Command Helm paper (iOS parity)

    /// Raw values are persistence contracts; Helm must stay appended after the
    /// original three papers.
    func testCommandHelmPaperAppendsToTheRegistry() {
        XCTAssertEqual(PrismetPaper.allCases.count, 4)
        XCTAssertEqual(PrismetPaper.allCases.last, .helm)
        XCTAssertEqual(PrismetPaper.helm.rawValue, "Command Helm")
    }

    /// Storing the Helm paper flips the live palette dark and retints the accent.
    func testHelmPaperGoesDarkAndRetintsAccent() {
        let defaults = UserDefaults.standard
        let prior = defaults.string(forKey: PrismetDesign.paperKey)
        defer { restorePaper(prior) }

        defaults.set(PrismetPaper.dark.rawValue, forKey: PrismetDesign.paperKey)
        let giltAccent = PrismetDesign.gold
        let darkGround = PrismetDesign.ground

        defaults.set(PrismetPaper.helm.rawValue, forKey: PrismetDesign.paperKey)
        XCTAssertTrue(PrismetDesign.isDark)
        XCTAssertNotEqual(PrismetDesign.gold, giltAccent)
        XCTAssertNotEqual(PrismetDesign.ground, darkGround)
    }

    func testUnknownStoredPaperStillFallsBackToDark() {
        let defaults = UserDefaults.standard
        let prior = defaults.string(forKey: PrismetDesign.paperKey)
        defer { restorePaper(prior) }

        defaults.set("Not A Paper", forKey: PrismetDesign.paperKey)
        XCTAssertEqual(PrismetDesign.paper, .dark)
    }

    // MARK: - Helpers

    private func restorePaper(_ prior: String?) {
        let defaults = UserDefaults.standard
        if let prior {
            defaults.set(prior, forKey: PrismetDesign.paperKey)
        } else {
            defaults.removeObject(forKey: PrismetDesign.paperKey)
        }
    }
}
