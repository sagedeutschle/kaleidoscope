import XCTest
import SwiftUI
@testable import Prismet

final class SettingsViewTests: XCTestCase {
    func testAppStoreShareURLUsesLivePublicListing() {
        XCTAssertEqual(
            SettingsView.appStoreURL.absoluteString,
            "https://apps.apple.com/us/app/kaleidescope/id6785993194"
        )
    }

    // MARK: - Command Helm paper

    /// Raw values are persistence contracts; Helm must stay appended after the
    /// original three papers.
    func testCommandHelmPaperAppendsToTheRegistry() {
        XCTAssertEqual(PrismetPaper.allCases.count, 4)
        XCTAssertEqual(PrismetPaper.allCases.last, .helm)
        XCTAssertEqual(PrismetPaper.helm.rawValue, "Command Helm")
    }

    func testHelmPaletteIsDarkAndDistinctFromDark() {
        let helm = PrismetDesign.palette(for: .helm)
        XCTAssertTrue(helm.isDark)
        XCTAssertNotEqual(helm.ground, PrismetDesign.palette(for: .dark).ground)
    }

    func testHelmRetintsTheGoldAccent() {
        withStoredPaper(.dark) { giltAccent in
            UserDefaults.standard.set(PrismetPaper.helm.rawValue, forKey: PrismetDesign.paperKey)
            XCTAssertNotEqual(PrismetDesign.gold, giltAccent)
        }
    }

    func testUnknownStoredPaperStillFallsBackToDark() {
        let defaults = UserDefaults.standard
        let prior = defaults.string(forKey: PrismetDesign.paperKey)
        defer { restorePaper(prior) }

        defaults.set("Not A Paper", forKey: PrismetDesign.paperKey)
        XCTAssertEqual(PrismetDesign.paper, .dark)
    }

    // MARK: - Helpers

    /// Runs `body` with `paper` stored, handing it the accent under that paper,
    /// and restores whatever was persisted before.
    private func withStoredPaper(_ paper: PrismetPaper, body: (Color) -> Void) {
        let defaults = UserDefaults.standard
        let prior = defaults.string(forKey: PrismetDesign.paperKey)
        defer { restorePaper(prior) }

        defaults.set(paper.rawValue, forKey: PrismetDesign.paperKey)
        body(PrismetDesign.gold)
    }

    private func restorePaper(_ prior: String?) {
        let defaults = UserDefaults.standard
        if let prior {
            defaults.set(prior, forKey: PrismetDesign.paperKey)
        } else {
            defaults.removeObject(forKey: PrismetDesign.paperKey)
        }
    }
}
