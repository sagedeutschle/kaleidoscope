import Foundation

public enum PrismetBlackjackAuditError: Error, Equatable {
    case auditUnavailable(phase: PrismetBlackjackPhase)
    case invalidTerminalState
    case stateMismatch
    case replayMismatch(PrismetReplayMismatch)
}

public struct PrismetBlackjackAuditDisclosure: Codable, Hashable, Sendable {
    public let seed: UInt64
    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let commands: [PrismetBlackjackCommand]
    public let revealedDrawOrder: [PrismetPlayingCard]
    public let stateHashes: [PrismetStateHash]
    public let replay: PrismetGameReplay
    public let resolution: PrismetBlackjackResolution

    public init(
        seed: UInt64,
        rulesVersion: Int,
        randomizerVersion: Int,
        commands: [PrismetBlackjackCommand],
        revealedDrawOrder: [PrismetPlayingCard],
        stateHashes: [PrismetStateHash],
        replay: PrismetGameReplay,
        resolution: PrismetBlackjackResolution
    ) {
        self.seed = seed
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.commands = commands
        self.revealedDrawOrder = revealedDrawOrder
        self.stateHashes = stateHashes
        self.replay = replay
        self.resolution = resolution
    }
}

public struct PrismetBlackjackAuditedSession: Codable, Hashable, Sendable {
    public let state: PrismetBlackjackState
    let tableCommands: [PrismetBlackjackCommand]
    let endedByPlayer: Bool
    let eventRecords: [PrismetGameEventRecord]

    public var observation: PrismetBlackjackObservation {
        PrismetBlackjackEngine.observation(for: state)
    }

    public static func start(seed: UInt64) throws -> PrismetBlackjackAuditedSession {
        try makeStartedSession(from: PrismetBlackjackEngine.start(seed: seed))
    }

    public func applying(
        _ command: PrismetBlackjackCommand
    ) throws -> PrismetBlackjackAuditedSession {
        let transition = try PrismetBlackjackEngine.applying(command, to: state)
        let records = try Self.makeEventRecords(
            events: transition.events,
            state: transition.state,
            startingAt: eventRecords.count
        )
        return PrismetBlackjackAuditedSession(
            state: transition.state,
            tableCommands: tableCommands + [command],
            endedByPlayer: false,
            eventRecords: eventRecords + records
        )
    }

    public func endingHand() throws -> PrismetBlackjackAuditedSession {
        let transition = try PrismetBlackjackEngine.endHand(state)
        let records = try Self.makeEventRecords(
            events: transition.events,
            state: transition.state,
            startingAt: eventRecords.count
        )
        return PrismetBlackjackAuditedSession(
            state: transition.state,
            tableCommands: tableCommands,
            endedByPlayer: true,
            eventRecords: eventRecords + records
        )
    }

    public func versionedState(modifiedAt: Date) throws -> PrismetVersionedGameState {
        let payload = try Self.encodeDeterministically(self)
        return try PrismetVersionedGameState(
            gameID: PrismetBlackjackRulesV1.canonicalGameID,
            rulesVersion: PrismetBlackjackRulesV1.rulesVersion,
            payloadVersion: PrismetBlackjackRulesV1.payloadVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            hashAlgorithm: .fnv1a64V1,
            payload: payload,
            modifiedAt: modifiedAt
        )
    }

    public static func restore(
        from versionedState: PrismetVersionedGameState
    ) throws -> PrismetBlackjackAuditedSession {
        guard versionedState.gameID == PrismetBlackjackRulesV1.canonicalGameID else {
            throw PrismetVersionedGameStateError.unsupportedGameID(versionedState.gameID)
        }
        guard versionedState.rulesVersion == PrismetBlackjackRulesV1.rulesVersion else {
            throw PrismetVersionedGameStateError.unsupportedRulesVersion(
                versionedState.rulesVersion
            )
        }
        guard versionedState.payloadVersion == PrismetBlackjackRulesV1.payloadVersion else {
            throw PrismetVersionedGameStateError.unsupportedPayloadVersion(
                versionedState.payloadVersion
            )
        }
        guard versionedState.randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetVersionedGameStateError.unsupportedRandomizerVersion(
                versionedState.randomizerVersion
            )
        }
        guard versionedState.hashAlgorithm == .fnv1a64V1 else {
            throw PrismetVersionedGameStateError.unsupportedHashAlgorithm(
                versionedState.hashAlgorithm
            )
        }

        let expectedHash = PrismetStateHash.fnv1a64(versionedState.payload)
        guard versionedState.stateHash == expectedHash else {
            throw PrismetVersionedGameStateError.payloadHashMismatch(
                expected: expectedHash,
                actual: versionedState.stateHash
            )
        }

        let restored = try JSONDecoder().decode(
            PrismetBlackjackAuditedSession.self,
            from: versionedState.payload
        )
        try restored.verifyRecordedSession()
        return restored
    }

    public func auditDisclosure() throws -> PrismetBlackjackAuditDisclosure {
        guard state.phase == .completed || state.phase == .abandoned else {
            throw PrismetBlackjackAuditError.auditUnavailable(phase: state.phase)
        }
        guard let resolution = state.resolution else {
            throw PrismetBlackjackAuditError.invalidTerminalState
        }

        try verifyRecordedSession()
        let replay = try makeReplay()
        let reproducedReplay = try reproducedSession().makeReplay()
        if let mismatch = PrismetGameReplayVerifier.firstMismatch(
            recorded: replay,
            reproduced: reproducedReplay
        ) {
            throw PrismetBlackjackAuditError.replayMismatch(mismatch)
        }

        return PrismetBlackjackAuditDisclosure(
            seed: state.seed,
            rulesVersion: PrismetBlackjackRulesV1.rulesVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            commands: tableCommands,
            revealedDrawOrder: Array(state.shuffledDeck.prefix(state.drawIndex)),
            stateHashes: eventRecords.map(\.stateHash),
            replay: replay,
            resolution: resolution
        )
    }

    private static func makeStartedSession(
        from transition: PrismetBlackjackTransition
    ) throws -> PrismetBlackjackAuditedSession {
        PrismetBlackjackAuditedSession(
            state: transition.state,
            tableCommands: [],
            endedByPlayer: false,
            eventRecords: try makeEventRecords(
                events: transition.events,
                state: transition.state,
                startingAt: 0
            )
        )
    }

    private static func makeEventRecords(
        events: [PrismetBlackjackEvent],
        state: PrismetBlackjackState,
        startingAt sequence: Int
    ) throws -> [PrismetGameEventRecord] {
        let hash = try stateHash(for: state)
        return try events.enumerated().map { offset, event in
            try PrismetGameEventRecord(
                sequence: sequence + offset,
                payload: PrismetReplayPayload(
                    kind: replayKind(for: event),
                    value: event
                ),
                stateHash: hash
            )
        }
    }

    private func makeReplay() throws -> PrismetGameReplay {
        guard state.phase == .completed || state.phase == .abandoned,
              let finalHash = eventRecords.last?.stateHash else {
            throw PrismetBlackjackAuditError.invalidTerminalState
        }

        var commandRecords = try tableCommands.enumerated().map { sequence, command in
            try PrismetGameCommandRecord(
                sequence: sequence,
                actorSeat: 0,
                payload: PrismetReplayPayload(kind: command.rawValue, value: command)
            )
        }
        if endedByPlayer {
            commandRecords.append(
                try PrismetGameCommandRecord(
                    sequence: commandRecords.count,
                    actorSeat: 0,
                    payload: PrismetReplayPayload(kind: "end-hand", data: Data())
                )
            )
        }

        return try PrismetGameReplay(
            gameID: PrismetBlackjackRulesV1.canonicalGameID,
            rulesetVersion: PrismetBlackjackRulesV1.rulesVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            seed: state.seed,
            commands: commandRecords,
            events: eventRecords,
            finalOutcome: state.phase == .abandoned ? .abandoned : .completed,
            finalStateHash: finalHash
        )
    }

    private func reproducedSession() throws -> PrismetBlackjackAuditedSession {
        var reproduced = try Self.start(seed: state.seed)
        for command in tableCommands {
            reproduced = try reproduced.applying(command)
        }
        if endedByPlayer {
            reproduced = try reproduced.endingHand()
        }
        return reproduced
    }

    private func verifyRecordedSession() throws {
        let reproduced = try reproducedSession()
        guard reproduced.state == state else {
            throw PrismetBlackjackAuditError.stateMismatch
        }

        for index in 0..<min(eventRecords.count, reproduced.eventRecords.count)
        where eventRecords[index] != reproduced.eventRecords[index] {
            throw PrismetBlackjackAuditError.replayMismatch(.event(index: index))
        }
        if eventRecords.count != reproduced.eventRecords.count {
            throw PrismetBlackjackAuditError.replayMismatch(
                .eventCount(
                    expected: eventRecords.count,
                    actual: reproduced.eventRecords.count
                )
            )
        }
    }

    private static func stateHash(
        for state: PrismetBlackjackState
    ) throws -> PrismetStateHash {
        .fnv1a64(try encodeDeterministically(state))
    }

    private static func encodeDeterministically<Value: Encodable>(
        _ value: Value
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func replayKind(for event: PrismetBlackjackEvent) -> String {
        switch event {
        case .handStarted: return "hand-started"
        case .playerHit: return "player-hit"
        case .playerStood: return "player-stood"
        case .dealerHit: return "dealer-hit"
        case .handCompleted: return "hand-completed"
        case .handAbandoned: return "hand-abandoned"
        }
    }
}
