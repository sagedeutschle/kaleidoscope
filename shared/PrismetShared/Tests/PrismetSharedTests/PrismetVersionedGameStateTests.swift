import Foundation
import XCTest
@testable import PrismetShared

final class PrismetVersionedGameStateTests: XCTestCase {
    func testCodecIsDeterministicAndPreservesOpaquePayloadExactly() throws {
        let payload = Data([0, 255, 1, 127])
        let state = try makeState(payload: payload)

        let first = try PrismetVersionedGameStateCodec.encode(state)
        let second = try PrismetVersionedGameStateCodec.encode(state)
        let decoded = try PrismetVersionedGameStateCodec.decodeSupported(
            first,
            support: supportedVersions()
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.payload, payload)
        XCTAssertEqual(decoded.stateHash, PrismetStateHash.fnv1a64(payload))
    }

    func testInitializerRejectsBlankIDInvalidVersionsAndHashMismatch() throws {
        let payload = Data([1, 2, 3])
        let hash = PrismetStateHash.fnv1a64(payload)

        XCTAssertThrowsError(
            try PrismetVersionedGameState(
                gameID: " ", rulesVersion: 1, payloadVersion: 1,
                randomizerVersion: 1, stateHash: hash, payload: payload
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .invalidGameID) }
        XCTAssertThrowsError(
            try PrismetVersionedGameState(
                gameID: "blackjack", rulesVersion: 0, payloadVersion: 1,
                randomizerVersion: 1, stateHash: hash, payload: payload
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .invalidRulesVersion(0)) }
        XCTAssertThrowsError(
            try PrismetVersionedGameState(
                gameID: "blackjack", rulesVersion: 1, payloadVersion: 0,
                randomizerVersion: 1, stateHash: hash, payload: payload
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .invalidPayloadVersion(0)) }
        XCTAssertThrowsError(
            try PrismetVersionedGameState(
                gameID: "blackjack", rulesVersion: 1, payloadVersion: 1,
                randomizerVersion: 0, stateHash: hash, payload: payload
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .invalidRandomizerVersion(0)) }

        let wrongHash = PrismetStateHash.fnv1a64(Data("wrong".utf8))
        XCTAssertThrowsError(
            try PrismetVersionedGameState(
                gameID: "blackjack", rulesVersion: 1, payloadVersion: 1,
                randomizerVersion: 1, stateHash: wrongHash, payload: payload
            )
        ) {
            XCTAssertEqual(
                $0 as? PrismetVersionedGameStateError,
                .payloadHashMismatch(expected: hash, actual: wrongHash)
            )
        }
    }

    func testDecodeFailsClosedForEveryUnsupportedVersionDimension() throws {
        let encoded = try PrismetVersionedGameStateCodec.encode(
            makeState(rulesVersion: 2, payloadVersion: 3, randomizerVersion: 4)
        )

        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                encoded,
                support: versionSupport(
                    gameID: "other",
                    rulesVersion: 2,
                    payloadVersion: 3,
                    randomizerVersion: 4
                )
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .unsupportedGameID("blackjack")) }
        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                encoded,
                support: versionSupport(
                    rulesVersion: 1,
                    payloadVersion: 3,
                    randomizerVersion: 4
                )
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .unsupportedRulesVersion(2)) }
        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                encoded,
                support: versionSupport(
                    rulesVersion: 2,
                    payloadVersion: 1,
                    randomizerVersion: 4
                )
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .unsupportedPayloadVersion(3)) }
        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                encoded,
                support: versionSupport(
                    rulesVersion: 2,
                    payloadVersion: 3,
                    randomizerVersion: 1
                )
            )
        ) { XCTAssertEqual($0 as? PrismetVersionedGameStateError, .unsupportedRandomizerVersion(4)) }
        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                encoded,
                support: versionSupport(
                    rulesVersion: 2,
                    payloadVersion: 3,
                    randomizerVersion: 4,
                    hashAlgorithm: PrismetStateHashAlgorithm(
                        rawValue: "different-known-algorithm"
                    )
                )
            )
        ) {
            XCTAssertEqual(
                $0 as? PrismetVersionedGameStateError,
                .unsupportedHashAlgorithm(.fnv1a64V1)
            )
        }
    }

    func testSupportDoesNotAcceptCartesianProductsAcrossGames() throws {
        let encoded = try PrismetVersionedGameStateCodec.encode(
            makeState(rulesVersion: 2, payloadVersion: 2, randomizerVersion: 2)
        )
        let support = PrismetVersionSupport(versions: [
            PrismetSupportedGameVersion(
                gameID: "blackjack",
                rulesVersion: 1,
                payloadVersion: 1,
                randomizerVersion: 1,
                hashAlgorithm: .fnv1a64V1
            ),
            PrismetSupportedGameVersion(
                gameID: "euchre",
                rulesVersion: 2,
                payloadVersion: 2,
                randomizerVersion: 2,
                hashAlgorithm: .fnv1a64V1
            )
        ])

        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(encoded, support: support)
        ) {
            XCTAssertEqual(
                $0 as? PrismetVersionedGameStateError,
                .unsupportedRulesVersion(2)
            )
        }
    }

    func testDecoderRejectsTamperedPayloadBeforeRestore() throws {
        let valid = try PrismetVersionedGameStateCodec.encode(makeState())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        object["payload"] = Data("tampered".utf8).base64EncodedString()
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                tampered,
                support: supportedVersions()
            )
        ) { error in
            guard case .payloadHashMismatch = error as? PrismetVersionedGameStateError else {
                return XCTFail("Expected payloadHashMismatch, got \(error)")
            }
        }
    }

    func testDecoderReportsUnknownHashAlgorithmWithTypedError() throws {
        let futureAlgorithm = PrismetStateHashAlgorithm(rawValue: "future-hash-v9")
        let valid = try PrismetVersionedGameStateCodec.encode(makeState())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        var stateHash = try XCTUnwrap(object["stateHash"] as? [String: Any])
        stateHash["algorithm"] = futureAlgorithm.rawValue
        object["stateHash"] = stateHash
        let futureState = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertThrowsError(
            try PrismetVersionedGameStateCodec.decodeSupported(
                futureState,
                support: supportedVersions()
            )
        ) {
            XCTAssertEqual(
                $0 as? PrismetVersionedGameStateError,
                .unsupportedHashAlgorithm(futureAlgorithm)
            )
        }
    }

    private func makeState(
        rulesVersion: Int = 1,
        payloadVersion: Int = 1,
        randomizerVersion: Int = 1,
        payload: Data = Data([0, 255, 1])
    ) throws -> PrismetVersionedGameState {
        try PrismetVersionedGameState(
            gameID: "blackjack",
            rulesVersion: rulesVersion,
            payloadVersion: payloadVersion,
            randomizerVersion: randomizerVersion,
            stateHash: .fnv1a64(payload),
            payload: payload,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
    }

    private func supportedVersions() -> PrismetVersionSupport {
        versionSupport()
    }

    private func versionSupport(
        gameID: String = "blackjack",
        rulesVersion: Int = 1,
        payloadVersion: Int = 1,
        randomizerVersion: Int = 1,
        hashAlgorithm: PrismetStateHashAlgorithm = .fnv1a64V1
    ) -> PrismetVersionSupport {
        PrismetVersionSupport(versions: [
            PrismetSupportedGameVersion(
                gameID: gameID,
                rulesVersion: rulesVersion,
                payloadVersion: payloadVersion,
                randomizerVersion: randomizerVersion,
                hashAlgorithm: hashAlgorithm
            )
        ])
    }
}
