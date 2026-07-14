import Foundation
import XCTest
import PrismetShared

final class PrismetIdentityContractsTests: XCTestCase {
    func testStorageScopeKindsRemainDistinctForSameIdentifier() {
        let identifier = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let localScope = PrismetStorageScope(kind: .device, identifier: identifier)
        let backendScope = PrismetStorageScope(kind: .backendAccount, identifier: identifier)

        XCTAssertNotEqual(localScope, backendScope)
    }

    func testGameCenterIdentityIncludesDeveloperTeamInValueSemantics() {
        let account = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let phoneGC = PrismetGameCenterIdentity(developerTeamID: "PHONE_TEAM", accountID: account)
        let macGC = PrismetGameCenterIdentity(developerTeamID: "MAC_TEAM", accountID: account)

        XCTAssertNotEqual(phoneGC, macGC)
    }

    func testGameCenterIdentityTrimsTeamWhitespaceAndAllowsUnknownTeam() {
        let account = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        XCTAssertEqual(
            PrismetGameCenterIdentity(
                developerTeamID: " \n PHONE_TEAM \t",
                accountID: account
            ).developerTeamID,
            "PHONE_TEAM"
        )
        XCTAssertEqual(
            PrismetGameCenterIdentity(developerTeamID: " \n\t ", accountID: account).developerTeamID,
            ""
        )
    }

    func testSignedOutIdentityHasOnlyLocalStorageScope() {
        let guestID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let identity = PrismetPlayerIdentity(
            localGuestID: guestID,
            backendAccountID: nil,
            gameCenter: nil
        )

        XCTAssertEqual(
            identity.localStorageScope,
            PrismetStorageScope(kind: .device, identifier: guestID)
        )
        XCTAssertNil(identity.cloudStorageScope)
    }

    func testSignedInIdentityUsesBackendAccountForCloudStorageScope() {
        let sharedID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let identity = PrismetPlayerIdentity(
            localGuestID: sharedID,
            backendAccountID: sharedID,
            gameCenter: nil
        )

        XCTAssertEqual(identity.localStorageScope.kind, .device)
        XCTAssertEqual(
            identity.cloudStorageScope,
            PrismetStorageScope(kind: .backendAccount, identifier: sharedID)
        )
        XCTAssertNotEqual(identity.localStorageScope, identity.cloudStorageScope)
    }

    func testIdentityContractsRoundTripThroughJSON() throws {
        let guestID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let backendID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let gameCenterAccountID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let scope = PrismetStorageScope(kind: .backendAccount, identifier: backendID)
        let gameCenter = PrismetGameCenterIdentity(
            developerTeamID: "PHONE_TEAM",
            accountID: gameCenterAccountID
        )
        let player = PrismetPlayerIdentity(
            localGuestID: guestID,
            backendAccountID: backendID,
            gameCenter: gameCenter
        )

        XCTAssertEqual(try roundTrip(PrismetStorageScopeKind.allCases), PrismetStorageScopeKind.allCases)
        XCTAssertEqual(try roundTrip(scope), scope)
        XCTAssertEqual(try roundTrip(gameCenter), gameCenter)
        XCTAssertEqual(try roundTrip(player), player)
    }
}

private extension PrismetIdentityContractsTests {
    func roundTrip<Value: Codable & Equatable>(_ value: Value) throws -> Value {
        let encoded = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: encoded)
    }
}
