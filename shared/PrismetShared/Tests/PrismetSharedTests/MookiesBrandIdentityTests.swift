import XCTest
@testable import PrismetShared

final class MookiesBrandIdentityTests: XCTestCase {
    func testCasinoIdentityKeepsAppRoomAndStudioDistinct() {
        XCTAssertEqual(MookiesBrandIdentity.appName, "Mookie's Arcade")
        XCTAssertEqual(MookiesBrandIdentity.casinoName, "Reynard's Casino")
        XCTAssertEqual(MookiesBrandIdentity.studioName, "Prismet")
    }

    func testCasinoHostCopyNamesTheCharacterAndPracticeBoundary() {
        let plan = MookiesCasinoMascotPresencePlan.casino

        XCTAssertTrue(plan.primary.accessibilityLabel.contains("Reynard"))
        XCTAssertTrue(plan.primary.accessibilityLabel.contains("practice"))
        XCTAssertTrue(plan.secondary.accessibilityLabel.contains("Mookie"))
        XCTAssertTrue(plan.secondary.accessibilityLabel.contains("guide"))
    }
}
