import XCTest
@testable import Prismet

final class ShotHarnessTests: XCTestCase {
    func testScreenshotHarnessLaunchSkipsAuthRestoreWhenShotIsRequested() {
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "chess3d"]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "home"]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "  "]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": "chess3d"]))
    }

    func testNormalLaunchRestoresAuthSession() {
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: [:]))
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": ""]))
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": ""]))
    }
}
