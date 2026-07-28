import XCTest
@testable import Prismet

final class ShotHarnessTests: XCTestCase {
    func testScreenshotHarnessLaunchSkipsAuthRestoreWhenShotIsRequested() {
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "chess3d"]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "home"]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "casino"]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": "  "]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": "chess3d"]))
    }

    func testNormalLaunchRestoresAuthSession() {
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: [:]))
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: ["PRISMET_SHOT": ""]))
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": ""]))
    }

    func testCasinoScreenshotRouteIsDeclaredByTheDebugHarness() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/App/ShotHarness.swift")
        )

        XCTAssertTrue(source.contains(#"case "casino":"#))
        XCTAssertTrue(source.contains("CasinoHubView(previewSeed: 20260728)"))
    }
}
