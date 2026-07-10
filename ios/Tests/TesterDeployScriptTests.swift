import XCTest

final class TesterDeployScriptTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testTesterDeployReportsLaunchFailuresAsPartialFailures() throws {
        let script = try deployTesterScript()

        XCTAssertTrue(script.contains("PARTIAL launch failed"))
        XCTAssertTrue(script.contains("Tester deploy summary"))
        XCTAssertTrue(script.contains("overall_rc=1"))
        XCTAssertFalse(script.contains("device process launch --device \"$device\" \"$BUNDLE_ID\" || true"))
    }

    func testTesterDeployIncludesKnownFamilyDevices() throws {
        let script = try deployTesterScript()

        XCTAssertTrue(script.contains("Poopoohead|B2081DF4-7D29-5F35-8CC4-18227227036B|00008120-001278982192201E"))
        XCTAssertTrue(script.contains("Benjamin's iPhone|00008150-000874440EF0401C|593AADAC-1388-5369-98C4-AB7C4003F374"))
        XCTAssertTrue(script.contains("MommaPhone|FF4B1908-94F7-5DF9-8793-8E6782A8614B|00008150-000A0DA02200401C"))
    }

    private func deployTesterScript() throws -> String {
        let scriptURL = repoRoot.appendingPathComponent("scripts/deploy-testers.sh")
        return try String(contentsOf: scriptURL, encoding: .utf8)
    }
}
