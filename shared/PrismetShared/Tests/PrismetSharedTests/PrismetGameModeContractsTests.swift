import XCTest
import PrismetShared

final class PrismetGameModeContractsTests: XCTestCase {
    func testLegacyModeRawValuesRemainStable() {
        XCTAssertEqual(PrismetGameMode.soloBot.rawValue, "soloBot")
        XCTAssertEqual(PrismetGameMode.localTwoPlayer.rawValue, "localTwoPlayer")
        XCTAssertEqual(PrismetGameMode.onlineFriend.rawValue, "onlineFriend")
    }

    func testIOSModeListsMatchCommittedCapabilities() {
        XCTAssertEqual(
            featureIDs(supporting: .soloBot, on: .iOS),
            Set([
                .game2048, .snake, .minesweeper, .sudoku, .rubiksCube,
                .lightsOut, .slidingPuzzle, .nonogram, .wordgame, .chess,
                .reversi, .checkers, .connectFour, .gomoku, .seaBattle,
                .catan, .solitaire, .spider, .crazyEight, .brickBench,
                .oracle
            ])
        )
        XCTAssertEqual(
            featureIDs(supporting: .localTwoPlayer, on: .iOS),
            Set([.chess, .reversi, .checkers, .connectFour, .gomoku, .crazyEight])
        )
        XCTAssertEqual(
            featureIDs(supporting: .onlineFriend, on: .iOS),
            Set([.chess, .reversi, .checkers, .connectFour, .gomoku, .seaBattle, .crazyEight])
        )
    }

    func testMacModeListsMatchCommittedCapabilities() {
        XCTAssertEqual(
            featureIDs(supporting: .soloBot, on: .macOS),
            Set([
                .game2048, .snake, .minesweeper, .sudoku, .rubiksCube,
                .chess, .lightsOut, .slidingPuzzle, .nonogram, .wordgame,
                .gomoku, .seaBattle, .solitaire, .spider, .crazyEight,
                .brickBench
            ])
        )
        XCTAssertEqual(
            featureIDs(supporting: .localTwoPlayer, on: .macOS),
            Set([.reversi, .checkers, .connectFour, .gomoku, .crazyEight])
        )
        XCTAssertEqual(featureIDs(supporting: .onlineFriend, on: .macOS), Set())
        XCTAssertEqual(PrismetGameModeCatalog.playableModes(for: .catan, platform: .macOS), [])
    }

    func testPlayableModesUseStableSoloLocalOnlineOrder() {
        XCTAssertEqual(
            PrismetGameModeCatalog.playableModes(for: .chess, platform: .iOS),
            [.soloBot, .localTwoPlayer, .onlineFriend]
        )
        XCTAssertEqual(
            PrismetGameModeCatalog.playableModes(for: .gomoku, platform: .macOS),
            [.soloBot, .localTwoPlayer]
        )
    }

    func testValidatedContextPreservesCanonicalIdentityAndRoundTrips() throws {
        let context = try PrismetGameLaunchContext.validated(
            featureID: .chess,
            mode: .soloBot,
            surface: .home,
            platform: .iOS
        )

        XCTAssertEqual(context.featureID, .chess)
        XCTAssertEqual(context.mode, .soloBot)
        XCTAssertEqual(context.surface, .home)
        XCTAssertEqual(context.platform, .iOS)

        let encoded = try JSONEncoder().encode(context)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: String])
        XCTAssertEqual(object["featureID"], PrismetFeatureID.chess.rawValue)
        XCTAssertEqual(object["mode"], PrismetGameMode.soloBot.rawValue)
        XCTAssertEqual(object["surface"], PrismetGameLaunchSurface.home.rawValue)
        XCTAssertEqual(object["platform"], PrismetPlatform.iOS.rawValue)
        XCTAssertEqual(try JSONDecoder().decode(PrismetGameLaunchContext.self, from: encoded), context)
    }

    func testHomeValidationRejectsUnavailablePlatformModes() {
        assertValidationError(
            featureID: .chess,
            mode: .onlineFriend,
            surface: .home,
            platform: .macOS,
            equals: .unavailableMode(featureID: .chess, mode: .onlineFriend, platform: .macOS)
        )
        assertValidationError(
            featureID: .reversi,
            mode: .soloBot,
            surface: .home,
            platform: .macOS,
            equals: .unavailableMode(featureID: .reversi, mode: .soloBot, platform: .macOS)
        )
        assertValidationError(
            featureID: .catan,
            mode: .soloBot,
            surface: .home,
            platform: .macOS,
            equals: .unavailableMode(featureID: .catan, mode: .soloBot, platform: .macOS)
        )
    }

    func testLensOnlyFeaturesCannotConstructPlayableContexts() throws {
        let oracle = try PrismetGameLaunchContext.validated(
            featureID: .oracle,
            mode: .soloBot,
            surface: .home,
            platform: .iOS
        )
        XCTAssertEqual(oracle.featureID, .oracle)

        for featureID in [PrismetFeatureID.debtClock, .steamRewind] {
            for platform in PrismetPlatform.allCases {
                assertValidationError(
                    featureID: featureID,
                    mode: .soloBot,
                    surface: .home,
                    platform: platform,
                    equals: .unavailableMode(featureID: featureID, mode: .soloBot, platform: platform)
                )
            }
        }
    }

    func testParlorRejectsEveryFeatureUntilParlorTablesAreAvailable() {
        for featureID in PrismetFeatureID.allCases {
            for platform in PrismetPlatform.allCases {
                let modes = PrismetGameModeCatalog.playableModes(for: featureID, platform: platform)
                let candidateMode = modes.first ?? .soloBot
                let expected: PrismetGameLaunchValidationError = modes.isEmpty
                    ? .unavailableMode(featureID: featureID, mode: candidateMode, platform: platform)
                    : .unavailableSurface(featureID: featureID, surface: .parlor, platform: platform)

                assertValidationError(
                    featureID: featureID,
                    mode: candidateMode,
                    surface: .parlor,
                    platform: platform,
                    equals: expected
                )
            }
        }
    }

    func testDecodingCannotForgeUnavailableMacOnlineContext() throws {
        let encoded = try encodedContext(
            featureID: .chess,
            mode: .onlineFriend,
            surface: .home,
            platform: .macOS
        )

        assertDecodingError(
            encoded,
            equals: .unavailableMode(featureID: .chess, mode: .onlineFriend, platform: .macOS)
        )
    }

    func testDecodingCannotForgeParlorContext() throws {
        let encoded = try encodedContext(
            featureID: .chess,
            mode: .soloBot,
            surface: .parlor,
            platform: .iOS
        )

        assertDecodingError(
            encoded,
            equals: .unavailableSurface(featureID: .chess, surface: .parlor, platform: .iOS)
        )
    }
}

private extension PrismetGameModeContractsTests {
    func featureIDs(
        supporting mode: PrismetGameMode,
        on platform: PrismetPlatform
    ) -> Set<PrismetFeatureID> {
        Set(PrismetFeatureCatalog.all.compactMap { feature in
            PrismetGameModeCatalog.playableModes(for: feature.canonicalID, platform: platform).contains(mode)
                ? feature.canonicalID
                : nil
        })
    }

    func assertValidationError(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform,
        equals expected: PrismetGameLaunchValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try PrismetGameLaunchContext.validated(
                featureID: featureID,
                mode: mode,
                surface: surface,
                platform: platform
            ),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? PrismetGameLaunchValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }

    func encodedContext(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "featureID": featureID.rawValue,
            "mode": mode.rawValue,
            "surface": surface.rawValue,
            "platform": platform.rawValue
        ])
    }

    func assertDecodingError(
        _ data: Data,
        equals expected: PrismetGameLaunchValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try JSONDecoder().decode(PrismetGameLaunchContext.self, from: data),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? PrismetGameLaunchValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
