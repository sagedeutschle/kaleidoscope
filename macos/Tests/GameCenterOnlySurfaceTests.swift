import XCTest

final class GameCenterOnlySurfaceTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDesktopAccountSurfaceDoesNotMentionPhoneSMSOrOTP() throws {
        let checkedFiles = [
            "Sources/Account/AccountViews.swift",
            "Sources/Account/AuthManager.swift",
            "Sources/App/ContentView.swift"
        ]
        let forbidden = ["phone", "SMS", "OTP", "Send code", "Verify and sign in", "Use the same phone"]

        for file in checkedFiles {
            let contents = try String(contentsOf: repoRoot.appendingPathComponent(file))
            for term in forbidden {
                XCTAssertFalse(contents.localizedCaseInsensitiveContains(term), "\(file) still contains \(term)")
            }
        }
    }
}
