import Foundation
import XCTest
@testable import PrismetShared

final class PrismetReplayContractsTests: XCTestCase {
    private struct StandCommand: Codable, Equatable {
        let reason: String
    }

    func testStateHashUsesVersionedFNV1a64AndValidatesCanonicalHex() throws {
        let hash = PrismetStateHash.fnv1a64(Data("hello".utf8))

        XCTAssertEqual(hash.algorithm, .fnv1a64V1)
        XCTAssertEqual(hash.value, "a430d84680aabd0b")
        XCTAssertThrowsError(try PrismetStateHash(value: "A430D84680AABD0B")) {
            XCTAssertEqual($0 as? PrismetReplayError, .invalidStateHash("A430D84680AABD0B"))
        }
        XCTAssertThrowsError(try PrismetStateHash(value: "not-a-hash"))
    }

    func testTypedPayloadCommandAndEventRoundTrip() throws {
        let payload = try PrismetReplayPayload(
            kind: "stand",
            value: StandCommand(reason: "player chose stand")
        )
        let command = try PrismetGameCommandRecord(sequence: 0, actorSeat: 0, payload: payload)
        let event = try PrismetGameEventRecord(
            sequence: 0,
            payload: try PrismetReplayPayload(kind: "hand-completed", data: Data([1, 2, 3])),
            stateHash: .fnv1a64(Data("final".utf8))
        )

        XCTAssertEqual(try payload.decode(as: StandCommand.self), StandCommand(reason: "player chose stand"))
        XCTAssertEqual(try JSONDecoder().decode(PrismetGameCommandRecord.self, from: JSONEncoder().encode(command)), command)
        XCTAssertEqual(try JSONDecoder().decode(PrismetGameEventRecord.self, from: JSONEncoder().encode(event)), event)
    }

    func testReplayCodecIsDeterministicAndUsesStructuralOutcomes() throws {
        let replay = try makeReplay()

        let first = try PrismetGameReplayCodec.encode(replay)
        let second = try PrismetGameReplayCodec.encode(replay)
        let decoded = try PrismetGameReplayCodec.decode(first)

        XCTAssertEqual(first, second)
        XCTAssertEqual(decoded, replay)
        XCTAssertEqual(PrismetGameReplayOutcome.allCases, [.completed, .abandoned])
        XCTAssertEqual(decoded.stateHashes, decoded.events.map(\.stateHash))
    }

    func testReplayRejectsInvalidMetadataAndNonContiguousSequences() throws {
        let hash = PrismetStateHash.fnv1a64(Data("final".utf8))
        let payload = try PrismetReplayPayload(kind: "stand", data: Data())

        XCTAssertThrowsError(
            try PrismetGameCommandRecord(sequence: -1, actorSeat: 0, payload: payload)
        ) { XCTAssertEqual($0 as? PrismetReplayError, .invalidRecordSequence(-1)) }
        XCTAssertThrowsError(
            try PrismetGameCommandRecord(sequence: 0, actorSeat: -1, payload: payload)
        ) { XCTAssertEqual($0 as? PrismetReplayError, .invalidActorSeat(-1)) }
        XCTAssertThrowsError(
            try PrismetReplayPayload(kind: "   ", data: Data())
        ) { XCTAssertEqual($0 as? PrismetReplayError, .emptyPayloadKind) }
        XCTAssertThrowsError(
            try PrismetGameReplay(
                gameID: " ", rulesetVersion: 1, randomizerVersion: 1, seed: 1,
                commands: [], events: [], finalOutcome: .completed, finalStateHash: hash
            )
        ) { XCTAssertEqual($0 as? PrismetReplayError, .emptyGameID) }
        XCTAssertThrowsError(
            try PrismetGameReplay(
                gameID: "blackjack", rulesetVersion: 0, randomizerVersion: 1, seed: 1,
                commands: [], events: [], finalOutcome: .completed, finalStateHash: hash
            )
        ) { XCTAssertEqual($0 as? PrismetReplayError, .invalidRulesetVersion(0)) }

        let skipped = try PrismetGameCommandRecord(sequence: 1, actorSeat: 0, payload: payload)
        XCTAssertThrowsError(
            try PrismetGameReplay(
                gameID: "blackjack", rulesetVersion: 1, randomizerVersion: 1, seed: 1,
                commands: [skipped], events: [], finalOutcome: .completed, finalStateHash: hash
            )
        ) {
            XCTAssertEqual(
                $0 as? PrismetReplayError,
                .nonContiguousSequence(record: "command", expected: 0, actual: 1)
            )
        }
    }

    func testVerifierIdentifiesFirstTamperedEvent() throws {
        let recorded = try makeReplay()
        let first = recorded.events[0]
        let changedHash = PrismetStateHash.fnv1a64(Data("changed".utf8))
        let changed = try PrismetGameEventRecord(
            sequence: 1,
            payload: recorded.events[1].payload,
            stateHash: changedHash
        )
        let reproduced = try PrismetGameReplay(
            gameID: recorded.gameID,
            rulesetVersion: recorded.rulesetVersion,
            randomizerVersion: recorded.randomizerVersion,
            seed: recorded.seed,
            commands: recorded.commands,
            events: [first, changed],
            finalOutcome: recorded.finalOutcome,
            finalStateHash: changedHash
        )

        XCTAssertEqual(
            PrismetGameReplayVerifier.firstMismatch(recorded: recorded, reproduced: reproduced),
            .event(index: 1)
        )
        XCTAssertNil(PrismetGameReplayVerifier.firstMismatch(recorded: recorded, reproduced: recorded))
    }

    func testEncodedReplaySchemaContainsNoIdentityEconomyOrPressureFields() throws {
        let encoded = try PrismetGameReplayCodec.encode(makeReplay())
        let json = String(decoding: encoded, as: UTF8.self).lowercased()

        for forbidden in [
            "account", "profile", "device", "purchase", "balance", "chip", "token",
            "wager", "stake", "payout", "prize", "streak", "automaticnext"
        ] {
            XCTAssertFalse(json.contains(forbidden), "Replay leaked forbidden field: \(forbidden)")
        }
    }

    private func makeReplay() throws -> PrismetGameReplay {
        let command = try PrismetGameCommandRecord(
            sequence: 0,
            actorSeat: 0,
            payload: try PrismetReplayPayload(kind: "stand", data: Data())
        )
        let firstHash = PrismetStateHash.fnv1a64(Data("started".utf8))
        let finalHash = PrismetStateHash.fnv1a64(Data("final".utf8))
        let events = [
            try PrismetGameEventRecord(
                sequence: 0,
                payload: PrismetReplayPayload(kind: "started", data: Data()),
                stateHash: firstHash
            ),
            try PrismetGameEventRecord(
                sequence: 1,
                payload: PrismetReplayPayload(kind: "completed", data: Data()),
                stateHash: finalHash
            )
        ]
        return try PrismetGameReplay(
            gameID: "blackjack",
            rulesetVersion: 1,
            randomizerVersion: 1,
            seed: 7,
            commands: [command],
            events: events,
            finalOutcome: .completed,
            finalStateHash: finalHash
        )
    }
}
