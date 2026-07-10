import XCTest

final class ProjectDeviceFamilyTests: XCTestCase {
    func testAppTargetBuildsAsUniversalIPhoneAndIPad() throws {
        let projectYAML = try String(contentsOf: projectRoot().appendingPathComponent("project.yml"))
        let targetFamilyLines = projectYAML
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("TARGETED_DEVICE_FAMILY:") }

        XCTAssertFalse(targetFamilyLines.isEmpty)
        XCTAssertTrue(
            targetFamilyLines.allSatisfy { $0.contains(#""1,2""#) },
            "Prismet must target iPhone and iPad so physical iPads do not run the app in iPhone compatibility mode."
        )
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
