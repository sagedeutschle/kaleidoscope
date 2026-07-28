import XCTest
@testable import Prismet

final class OnlineGameCatalogTests: XCTestCase {
    func testCatalogDrivesTheLobbyAllowlist() {
        // The lobby's supported set must come straight from the catalog.
        XCTAssertEqual(OnlineGameLobbyView.supportedGames, OnlineGameCatalog.availableGameIDs)
    }

    func testEveryAvailableGameProducesRoundTrippableInitialState() throws {
        for gameID in OnlineGameCatalog.availableGameIDs {
            let json = try OnlineGameCatalog.initialStateJSON(for: gameID)
            XCTAssertFalse(json.isEmpty, "\(gameID.rawValue) produced empty initial online state")
        }
    }

    func testEveryAvailableGameOffersOnlineMode() {
        // A game that's online-available in the catalog must also expose the online
        // launch mode — the two sides of the seam can't drift.
        for gameID in OnlineGameCatalog.availableGameIDs {
            XCTAssertTrue(GameModeCatalog.playableModes(for: gameID).contains(.onlineFriend),
                          "\(gameID.rawValue) is online-available but has no .onlineFriend mode")
        }
    }

    func testCatanIsRegisteredButNotYetAvailable() {
        let descriptor = OnlineGameCatalog.descriptor(for: .catan)
        XCTAssertNotNil(descriptor, "Catan should be registered so the seam knows it exists")
        XCTAssertEqual(descriptor?.seats, 3...4)
        XCTAssertFalse(OnlineGameCatalog.supports(.catan), "Catan online is a documented follow-up, not live yet")
        XCTAssertFalse(OnlineGameLobbyView.supportedGames.contains(.catan))
    }

    func testInitialStateForUnavailableGameThrows() {
        XCTAssertThrowsError(try OnlineGameCatalog.initialStateJSON(for: .catan))
    }
}
