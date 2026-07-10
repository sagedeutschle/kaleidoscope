import XCTest

final class DeploymentScriptTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testMacVersionMatchesPhoneVersion() throws {
        let macProject = try String(contentsOf: repoRoot.appendingPathComponent("project.yml"))
        // Monorepo: repoRoot is <repo>/macos; the iOS app is a sibling at <repo>/ios.
        let phoneProject = try String(contentsOf: repoRoot.deletingLastPathComponent().appendingPathComponent("ios/project.yml"))

        XCTAssertEqual(versionValue("MARKETING_VERSION", in: macProject), versionValue("MARKETING_VERSION", in: phoneProject))
        XCTAssertEqual(versionValue("CURRENT_PROJECT_VERSION", in: macProject), versionValue("CURRENT_PROJECT_VERSION", in: phoneProject))
    }

    func testMacDeployScriptMirrorsPhoneDeployFlow() throws {
        let scriptURL = repoRoot.appendingPathComponent("scripts/deploy-mac.sh")
        let script = try String(contentsOf: scriptURL)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
        XCTAssertTrue(script.contains("xcodegen generate"))
        XCTAssertTrue(script.contains("xcodebuild"))
        XCTAssertTrue(script.contains("Prismet.app"))
        XCTAssertTrue(script.contains("open -a"))
    }

    func testVersionSyncScriptUpdatesBothProjects() throws {
        let scriptURL = repoRoot.appendingPathComponent("scripts/sync-version.sh")
        let script = try String(contentsOf: scriptURL)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
        XCTAssertTrue(script.contains("MARKETING_VERSION"))
        XCTAssertTrue(script.contains("CURRENT_PROJECT_VERSION"))
        XCTAssertTrue(script.contains("ios/project.yml"))
        XCTAssertTrue(script.contains("macos/project.yml"))
    }

    private func versionValue(_ key: String, in yaml: String) -> String? {
        let pattern = #"\#(key): "([^"]+)""#
        return yaml
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard let range = line.range(of: pattern, options: .regularExpression) else { return nil }
                return String(line[range])
                    .replacingOccurrences(of: "\(key): ", with: "")
                    .replacingOccurrences(of: "\"", with: "")
            }
            .last
    }
}
