import XCTest
@testable import Prismet

final class GamePlayModeTests: XCTestCase {
    func testEveryCanonicalGameDeclaresLaunchModes() {
        let covered = Set(GameModeCatalog.all.map(\.gameID))
        XCTAssertEqual(covered, Set(CanonicalGameID.allCases))
    }

    func testChessExposesBotLocalAndOnlineModes() {
        XCTAssertEqual(GameModeCatalog.playableModes(for: .chess), [.soloBot, .localTwoPlayer, .onlineFriend])
        XCTAssertEqual(GameModeCatalog.option(for: .chess, mode: .onlineFriend)?.status, .playable)
    }

    func testReversiAndConnectFourExposeBotLocalAndOnlineModes() {
        XCTAssertEqual(GameModeCatalog.playableModes(for: .reversi), [.soloBot, .localTwoPlayer, .onlineFriend])
        XCTAssertEqual(GameModeCatalog.playableModes(for: .connectFour), [.soloBot, .localTwoPlayer, .onlineFriend])
    }

    func testGomokuExposesBotLocalAndOnlineModes() {
        XCTAssertEqual(GameModeCatalog.playableModes(for: .gomoku), [.soloBot, .localTwoPlayer, .onlineFriend])
    }

    func testCrazyEightExposesBotLocalAndOnlineModes() {
        XCTAssertEqual(GameModeCatalog.playableModes(for: .crazyEight), [.soloBot, .localTwoPlayer, .onlineFriend])
    }

    func testSeaBattleExposesSoloAndOnlineModes() {
        XCTAssertEqual(GameModeCatalog.option(for: .seaBattle, mode: .localTwoPlayer), nil)
        XCTAssertEqual(GameModeCatalog.playableModes(for: .seaBattle), [.soloBot, .onlineFriend])
    }

    func testExistingHotSeatBoardGamesExposeLocalTwoPlayerAndOnline() {
        for gameID in [CanonicalGameID.reversi, .connectFour, .checkers, .gomoku, .crazyEight] {
            XCTAssertTrue(GameModeCatalog.playableModes(for: gameID).contains(.localTwoPlayer))
            XCTAssertTrue(GameModeCatalog.playableModes(for: gameID).contains(.onlineFriend), "\(gameID.rawValue) should offer online play")
        }
    }

    func testSoloDesignedGamesDoNotExposePlayerCountChoices() {
        let gamesWithPlayerChoices: Set<CanonicalGameID> = [.chess, .checkers, .reversi, .connectFour, .gomoku, .crazyEight, .seaBattle]
        let soloDesignedGames = CanonicalGameID.allCases.filter { !gamesWithPlayerChoices.contains($0) }

        for gameID in soloDesignedGames {
            XCTAssertEqual(GameModeCatalog.options(for: gameID), [.playable(.soloBot)], "\(gameID.rawValue) should launch directly as a solo game")
        }
    }

    func testOnlyMultiplayerDesignedGamesRequireLaunchModeSelection() {
        XCTAssertFalse(GameModeCatalog.requiresLaunchModeSelection(for: .solitaire))
        XCTAssertFalse(GameModeCatalog.requiresLaunchModeSelection(for: .wordle))
        XCTAssertFalse(GameModeCatalog.requiresLaunchModeSelection(for: .game2048))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .chess))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .checkers))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .reversi))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .connectFour))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .gomoku))
        XCTAssertFalse(GameModeCatalog.requiresLaunchModeSelection(for: .spider))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .crazyEight))
        XCTAssertTrue(GameModeCatalog.requiresLaunchModeSelection(for: .seaBattle))
    }
}

final class OnlineMatchTests: XCTestCase {
    func testRoomCodesUseUnambiguousAlphabetAndFixedLength() {
        for _ in 0..<200 {
            let code = OnlineMatchStore.generateRoomCode()
            XCTAssertEqual(code.count, OnlineMatchStore.roomCodeLength)
            XCTAssertTrue(code.allSatisfy { OnlineMatchStore.roomCodeAlphabet.contains($0) })
            // Look-alike characters must never appear.
            XCTAssertFalse(code.contains("0")); XCTAssertFalse(code.contains("O"))
            XCTAssertFalse(code.contains("1")); XCTAssertFalse(code.contains("I"))
            XCTAssertFalse(code.contains("L"))
        }
    }

    func testRoomCodeNormalizationForgivesTypingStyle() {
        XCTAssertEqual(OnlineMatchStore.normalizedRoomCode(" ab-3k "), "AB3K")
        XCTAssertEqual(OnlineMatchStore.normalizedRoomCode("w2x9"), "W2X9")
    }

    func testMatchRowDecodesFromPostgRESTPayload() throws {
        let json = """
        {"id":"2E7A0A2A-7287-432D-85B1-20F65E938235","room_code":"AB3K","game_id":"connectfour",
         "status":"active","host_user_id":"00000000-0000-0000-0000-000000000222",
         "guest_user_id":"00000000-0000-0000-0000-000000000333","host_name":"Sage","guest_name":"Kris",
         "host_emoji":"🎴","guest_emoji":"🌸","state_json":"{}","current_turn_user_id":"00000000-0000-0000-0000-000000000222",
         "move_count":3,"winner_user_id":null,"created_at":"2026-07-03T10:10:36.918434+00:00","updated_at":"2026-07-03T10:10:36.918434+00:00"}
        """
        let match = try JSONDecoder().decode(OnlineMatch.self, from: Data(json.utf8))
        XCTAssertEqual(match.roomCode, "AB3K")
        XCTAssertEqual(match.canonicalGame, .connectFour)
        XCTAssertEqual(match.status, .active)
        XCTAssertEqual(match.moveCount, 3)

        let host = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
        let guest = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
        XCTAssertTrue(match.isHost(host))
        XCTAssertEqual(match.opponentID(for: host), guest)
        XCTAssertEqual(match.opponentName(for: host), "Kris")
        XCTAssertEqual(match.opponentName(for: guest), "Sage")
    }

    func testInitialStateJSONRoundTripsForEveryOnlineGame() throws {
        for gameID in OnlineGameLobbyView.supportedGames {
            let stateJSON = try OnlineGameLobbyView.initialStateJSON(for: gameID)
            switch gameID {
            case .chess:
                let snap = try GameSaveCodec.decodeSnapshot(ChessSnapshot.self, from: stateJSON)
                XCTAssertEqual(snap.position, .initial)
            case .checkers:
                let snap = try GameSaveCodec.decodeSnapshot(CheckersSnapshot.self, from: stateJSON)
                XCTAssertEqual(snap.game, CheckersGame())
            case .connectFour:
                let snap = try GameSaveCodec.decodeSnapshot(ConnectFourSnapshot.self, from: stateJSON)
                XCTAssertEqual(snap.game, ConnectFourGame())
            case .reversi:
                let snap = try GameSaveCodec.decodeSnapshot(ReversiSnapshot.self, from: stateJSON)
                XCTAssertEqual(snap.game, ReversiGame())
            case .gomoku:
                let snap = try GameSaveCodec.decodeSnapshot(GomokuSnapshot.self, from: stateJSON)
                XCTAssertEqual(snap.game, GomokuGame())
            case .crazyEight:
                let snap = try GameSaveCodec.decodeSnapshot(CrazyEightSnapshot.self, from: stateJSON)
                XCTAssertEqual(snap.game.hand(for: .host).count, 7)
            case .seaBattle:
                let snap = try GameSaveCodec.decodeSnapshot(SeaBattleSnapshot.self, from: stateJSON)
                XCTAssertTrue(snap.setup.isDeploymentPhase)
                XCTAssertTrue(snap.game.board(for: .host).shipCells.isEmpty)
                XCTAssertTrue(snap.game.board(for: .guest).shipCells.isEmpty)
            default:
                XCTFail("Unexpected online game \(gameID.rawValue)")
            }
        }
    }
}
