import XCTest
@testable import Prismet

@MainActor
final class MookiesPhoneCompanionTests: XCTestCase {
    func testDismissalHidesCompanionAndReportsItOnce() {
        var dismissalCount = 0
        let model = MookiesPhoneCompanionModel(isPresented: true) {
            dismissalCount += 1
        }

        model.dismiss()
        model.dismiss()

        XCTAssertFalse(model.isPresented)
        XCTAssertEqual(dismissalCount, 1)
    }

    func testSemanticStatesUseWarmNonBlockingCopy() {
        XCTAssertEqual(MookiesPhoneCompanionState.welcome.message, "I’ll keep you company from over here.")
        XCTAssertEqual(MookiesPhoneCompanionState.encouragement.message, "Take your time — the next move is yours.")
        XCTAssertEqual(MookiesPhoneCompanionState.celebration.message, "Nice one! I’m cheering from the sidelines.")
        XCTAssertFalse(MookiesPhoneCompanionState.allCases
            .map(\.message)
            .joined(separator: " ")
            .lowercased()
            .contains("odds"))
    }

    func testAccessibilitySummaryNamesMookieAndTheDismissAction() {
        XCTAssertEqual(
            MookiesPhoneCompanionState.welcome.accessibilityLabel,
            "Mookie, your arcade host. I’ll keep you company from over here."
        )
        XCTAssertEqual(MookiesPhoneCompanion.dismissAccessibilityLabel, "Dismiss Mookie companion")
    }

    func testIntegrationSeamDoesNotOwnCasinoState() {
        XCTAssertEqual(MookiesPhoneCompanion.integrationSeam, "Place in a destination VStack or safe-area inset with a MookiesPhoneCompanionModel; it owns no navigation, game, odds, result, progress, or token state.")
    }
}
