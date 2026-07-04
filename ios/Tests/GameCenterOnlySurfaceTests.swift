import XCTest
@testable import Kaleidoscope

final class GameCenterOnlySurfaceTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testGameCenterIdentityIsStableForTeamPlayerID() {
        XCTAssertEqual(
            GameCenterIdentity.stableUUID(fromTeamPlayerID: "team-player-1"),
            GameCenterIdentity.stableUUID(fromTeamPlayerID: "team-player-1")
        )
        XCTAssertNotEqual(
            GameCenterIdentity.stableUUID(fromTeamPlayerID: "team-player-1"),
            GameCenterIdentity.stableUUID(fromTeamPlayerID: "team-player-2")
        )
    }

    @MainActor
    func testAuthManagerStartsWithLocalGuestIdentity() {
        let auth = AuthManager()

        guard case .signedIn = auth.state else {
            return XCTFail("AuthManager should start from a local guest identity instead of blocking on loading")
        }
        XCTAssertFalse(auth.isCloudBacked)
    }

    func testPhoneSignInViewIsRemovedFromCompiledSources() throws {
        let phoneSignIn = repoRoot.appendingPathComponent("Sources/Features/Auth/PhoneSignInView.swift")
        XCTAssertFalse(FileManager.default.fileExists(atPath: phoneSignIn.path))
    }

    func testVisibleIOSAuthSurfaceDoesNotMentionPhoneSMSOrTwilio() throws {
        let checkedFiles = [
            "Sources/App/RootView.swift",
            "Sources/Backend/AuthManager.swift",
            "Sources/Features/Profile/MeView.swift"
        ]

        let forbidden = ["phone sign-in", "phone", "SMS", "OTP", "Twilio", "Send code", "Verify"]
        for file in checkedFiles {
            let contents = try String(contentsOf: repoRoot.appendingPathComponent(file))
            for term in forbidden {
                XCTAssertFalse(contents.localizedCaseInsensitiveContains(term), "\(file) still contains \(term)")
            }
        }
    }

    func testHomeExposesNativeGameCenterAddFriendAction() throws {
        let home = try String(contentsOf: repoRoot.appendingPathComponent("Sources/Features/Home/HomeView.swift"))
        XCTAssertTrue(home.contains("GameCenterFriends.presentAddFriend()"))
        XCTAssertTrue(home.contains("Label(\"Add Friend\", systemImage: \"person.badge.plus\")"))
    }
}
