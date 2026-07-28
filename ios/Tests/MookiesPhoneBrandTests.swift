import XCTest
@testable import Prismet

final class MookiesPhoneBrandTests: XCTestCase {
    func testCanonicalIdentityKeepsAppAndStudioNamesDistinct() {
        XCTAssertEqual(MookiesPhoneBrand.appFacingName, "Mookie's Arcade")
        XCTAssertEqual(MookiesPhoneBrand.studioName, "Prismet")
        XCTAssertEqual(MookiesPhoneBrand.studioCredit, "from Prismet")
    }

    func testCompactHeaderUsesSelectedMookieHostAsset() {
        XCTAssertEqual(MookiesPhoneBrand.hostAssetName, "MookieHost")
        XCTAssertEqual(MookiesPhoneBrand.compactHostSize, 56)
    }

    func testHeaderAccessibilityLabelIncludesBothCanonicalIdentities() {
        XCTAssertEqual(MookiesPhoneBrand.compactHeaderAccessibilityLabel, "Mookie's Arcade, from Prismet")
    }
}
