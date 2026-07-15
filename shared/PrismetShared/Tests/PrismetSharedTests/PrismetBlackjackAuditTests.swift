import Foundation
import XCTest
@testable import PrismetShared

final class PrismetBlackjackAuditTests: XCTestCase {
    func testSameSeedAndCommandsProduceEquivalentReplay() throws {
        let first = try PrismetBlackjackAuditedSession.start(seed: 7).applying(.stand)
        let second = try PrismetBlackjackAuditedSession.start(seed: 7).applying(.stand)

        let firstAudit = try first.auditDisclosure()
        let secondAudit = try second.auditDisclosure()

        XCTAssertEqual(firstAudit, secondAudit)
        XCTAssertNil(
            PrismetGameReplayVerifier.firstMismatch(
                recorded: firstAudit.replay,
                reproduced: secondAudit.replay
            )
        )
    }

    func testActiveHandDeniesAuditDisclosure() throws {
        let active = try activeFixtureSession()

        XCTAssertThrowsError(try active.auditDisclosure()) {
            XCTAssertEqual(
                $0 as? PrismetBlackjackAuditError,
                .auditUnavailable(phase: .playerTurn)
            )
        }
    }

    func testTerminalDisclosureContainsReplayAndRevealedFairnessData() throws {
        let terminal = try activeFixtureSession().applying(.stand)

        let disclosure = try terminal.auditDisclosure()

        XCTAssertEqual(disclosure.seed, terminal.state.seed)
        XCTAssertEqual(disclosure.rulesVersion, 1)
        XCTAssertEqual(disclosure.randomizerVersion, 1)
        XCTAssertEqual(disclosure.commands, [.stand])
        XCTAssertGreaterThanOrEqual(disclosure.revealedDrawOrder.count, 4)
        XCTAssertFalse(disclosure.stateHashes.isEmpty)
        XCTAssertEqual(disclosure.replay.finalOutcome, .completed)
        XCTAssertEqual(disclosure.replay.seed, disclosure.seed)
        XCTAssertEqual(disclosure.resolution, terminal.observation.resolution)
    }

    func testFirstTamperedStateHashIsReportedAsReplayMismatch() throws {
        let terminal = try activeFixtureSession().applying(.stand)
        let first = try XCTUnwrap(terminal.eventRecords.first)
        let changed = try PrismetGameEventRecord(
            sequence: first.sequence,
            payload: first.payload,
            stateHash: .fnv1a64(Data("tampered".utf8))
        )
        let tampered = PrismetBlackjackAuditedSession(
            state: terminal.state,
            tableCommands: terminal.tableCommands,
            endedByPlayer: terminal.endedByPlayer,
            eventRecords: [changed] + terminal.eventRecords.dropFirst()
        )

        XCTAssertThrowsError(try tampered.auditDisclosure()) {
            XCTAssertEqual(
                $0 as? PrismetBlackjackAuditError,
                .replayMismatch(.event(index: 0))
            )
        }
    }

    func testUnsupportedRulesVersionFailsClosed() throws {
        let session = try activeFixtureSession()
        let saved = try session.versionedState(modifiedAt: Date(timeIntervalSince1970: 10))
        let future = try PrismetVersionedGameState(
            gameID: saved.gameID,
            rulesVersion: 2,
            payloadVersion: saved.payloadVersion,
            randomizerVersion: saved.randomizerVersion,
            stateHash: saved.stateHash,
            payload: saved.payload,
            modifiedAt: saved.modifiedAt
        )

        XCTAssertThrowsError(try PrismetBlackjackAuditedSession.restore(from: future)) {
            XCTAssertEqual(
                $0 as? PrismetVersionedGameStateError,
                .unsupportedRulesVersion(2)
            )
        }
    }

    func testMidHandSaveRestorePreservesExactFutureDeck() throws {
        let middle = try activeSessionWithSurvivingHit().applying(.hit)
        XCTAssertEqual(middle.observation.phase, .playerTurn)
        let saved = try middle.versionedState(modifiedAt: Date(timeIntervalSince1970: 20))

        let restored = try PrismetBlackjackAuditedSession.restore(from: saved)
        let originalTerminal = try middle.applying(.stand)
        let restoredTerminal = try restored.applying(.stand)

        XCTAssertEqual(restored, middle)
        XCTAssertEqual(restoredTerminal, originalTerminal)
        XCTAssertEqual(
            try restoredTerminal.auditDisclosure(),
            try originalTerminal.auditDisclosure()
        )
    }

    func testEndingHandProducesNeutralAbandonedReplay() throws {
        let ended = try activeFixtureSession().endingHand()

        let disclosure = try ended.auditDisclosure()

        XCTAssertEqual(ended.observation.phase, .abandoned)
        XCTAssertEqual(disclosure.resolution.outcome, .abandoned)
        XCTAssertEqual(disclosure.resolution.reason, .endedByPlayer)
        XCTAssertEqual(disclosure.replay.finalOutcome, .abandoned)
        XCTAssertEqual(disclosure.commands, [])
        XCTAssertEqual(disclosure.replay.commands.last?.payload.kind, "end-hand")
    }

    func testPersistedAndDisclosedSchemasContainNoEconomyIdentityOrPressureFields() throws {
        let terminal = try activeFixtureSession().applying(.stand)
        let saved = try terminal.versionedState(modifiedAt: Date(timeIntervalSince1970: 30))
        let encodedSaved = try PrismetVersionedGameStateCodec.encode(saved)
        let encodedDisclosure = try JSONEncoder().encode(terminal.auditDisclosure())
        let combined = (
            String(decoding: encodedSaved, as: UTF8.self)
            + String(decoding: encodedDisclosure, as: UTF8.self)
        ).lowercased()

        for forbidden in [
            "account", "profile", "device", "purchase", "balance", "chip", "token",
            "wager", "stake", "payout", "prize", "streak", "automaticnext",
            "autoplay", "autonewhand"
        ] {
            XCTAssertFalse(combined.contains(forbidden), "Found forbidden schema field: \(forbidden)")
        }
    }

    private func activeFixtureSession() throws -> PrismetBlackjackAuditedSession {
        for seed in UInt64(1)...1_000 {
            let session = try PrismetBlackjackAuditedSession.start(seed: seed)
            if session.observation.phase == .playerTurn {
                return session
            }
        }
        throw FixtureError.noActiveSeed
    }

    private func activeSessionWithSurvivingHit() throws -> PrismetBlackjackAuditedSession {
        for seed in UInt64(1)...1_000 {
            let session = try PrismetBlackjackAuditedSession.start(seed: seed)
            guard session.observation.phase == .playerTurn,
                  let afterHit = try? session.applying(.hit),
                  afterHit.observation.phase == .playerTurn else {
                continue
            }
            return session
        }
        throw FixtureError.noSurvivingHitSeed
    }

    private enum FixtureError: Error {
        case noActiveSeed
        case noSurvivingHitSeed
    }
}
