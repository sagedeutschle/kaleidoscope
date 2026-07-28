import Foundation
import PrismetShared
import SwiftUI

@MainActor
final class PracticeBlackjackSession: ObservableObject {
    enum RecoveryReason: Equatable {
        case corrupt
        case unsupported
    }

    enum LoadState: Equatable {
        case loading
        case ready
        case recoveryRequired(RecoveryReason)
    }

    enum Sheet: String, Identifiable {
        case fairPlay
        case replay

        var id: String { rawValue }
    }

    @Published private(set) var table: PrismetBlackjackObservation
    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var errorMessage: String?
    @Published var presentedSheet: Sheet?

    private var auditedSession: PrismetBlackjackAuditedSession

    private let store: PracticeBlackjackStore
    private let seedSource: () -> UInt64
    private var nextPreviewSeed: UInt64?
    private var pendingPersistence: Task<Void, Never>?

    init(
        previewSeed: UInt64? = nil,
        store: PracticeBlackjackStore = PracticeBlackjackStore(),
        seedSource: @escaping () -> UInt64 = casinoSystemSeed
    ) {
        let initialSeed = previewSeed ?? seedSource()
        let initialSession = Self.startSession(seed: initialSeed)
        self.store = store
        self.seedSource = seedSource
        self.auditedSession = initialSession
        self.table = initialSession.observation
        self.nextPreviewSeed = previewSeed.map { $0 &+ 0x9e3779b97f4a7c15 }
    }

    var canHit: Bool {
        loadState == .ready && table.legalCommands.contains(.hit)
    }

    var canStand: Bool {
        loadState == .ready && table.legalCommands.contains(.stand)
    }

    var canEndHand: Bool {
        loadState == .ready && table.canEndHand
    }

    var canStartNewHand: Bool {
        guard loadState == .ready else { return false }
        return table.phase == .completed || table.phase == .abandoned
    }

    var auditDisclosure: PrismetBlackjackAuditDisclosure? {
        guard canStartNewHand else { return nil }
        return try? auditedSession.auditDisclosure()
    }

    var auditPresentation: CasinoAuditPresentation? {
        guard let disclosure = auditDisclosure else { return nil }
        return CasinoAuditPresentation(
            seed: String(disclosure.seed),
            rulesVersion: String(disclosure.rulesVersion),
            randomizerVersion: String(disclosure.randomizerVersion),
            commands: disclosure.commands.map { $0.rawValue.capitalized },
            revealedDrawOrder: disclosure.revealedDrawOrder.map {
                $0.accessibilityLabel(isFaceUp: true)
            },
            stateHashes: disclosure.stateHashes.map(\.value),
            replayOutcome: disclosure.replay.finalOutcome.rawValue.capitalized,
            resolution: Self.auditResolutionSummary(disclosure.resolution)
        )
    }

    var commandAvailability: CasinoMacCommandAvailability {
        CasinoMacCommandAvailability(
            canHit: canHit,
            canStand: canStand,
            canStartNewHand: canStartNewHand,
            hasReplay: auditDisclosure != nil
        )
    }

    func restoreOrDeal() async {
        guard loadState == .loading else { return }

        do {
            guard let data = try await store.loadData() else {
                loadState = .ready
                await persist()
                return
            }

            do {
                let state = try PrismetVersionedGameStateCodec.decodeSupported(
                    data,
                    support: Self.versionSupport
                )
                let restored = try PrismetBlackjackAuditedSession.restore(from: state)
                auditedSession = restored
                table = restored.observation
                loadState = .ready
                errorMessage = nil
            } catch let error as PrismetVersionedGameStateError {
                enterRecovery(reason: Self.recoveryReason(for: error))
            } catch {
                enterRecovery(reason: .corrupt)
            }
        } catch {
            enterRecovery(reason: .corrupt)
        }
    }

    func hit() {
        apply(.hit)
    }

    func stand() {
        apply(.stand)
    }

    func endHand() {
        guard canEndHand else { return }
        do {
            auditedSession = try auditedSession.endingHand()
            publishCurrentObservation()
        } catch {
            errorMessage = "The hand could not be ended. Your current table is unchanged."
        }
    }

    func newHand() {
        guard canStartNewHand else { return }
        let next = Self.startSession(seed: takeNextSeed())
        auditedSession = next
        table = next.observation
        presentedSheet = nil
        errorMessage = nil
        schedulePersistence()
    }

    func showReplay() {
        guard auditDisclosure != nil else { return }
        presentedSheet = .replay
    }

    func persist() async {
        guard loadState == .ready else { return }
        do {
            let state = try auditedSession.versionedState(modifiedAt: Date())
            let task = enqueuePersistence(state)
            await task.value
        } catch {
            errorMessage = "This hand is still playable, but it could not be saved."
        }
    }

    func startFresh() async {
        guard case .recoveryRequired = loadState else { return }

        do {
            _ = try await store.preserveExistingFile()
            let fresh = Self.startSession(seed: takeNextSeed())
            let state = try fresh.versionedState(modifiedAt: Date())
            try await store.save(state)
            auditedSession = fresh
            table = fresh.observation
            loadState = .ready
            errorMessage = nil
        } catch {
            errorMessage = "Start Fresh could not finish. The existing file remains unchanged."
        }
    }

    private func apply(_ command: PrismetBlackjackCommand) {
        guard table.legalCommands.contains(command), loadState == .ready else { return }
        do {
            auditedSession = try auditedSession.applying(command)
            publishCurrentObservation()
        } catch {
            errorMessage = "That action is not available for the current hand."
        }
    }

    private func publishCurrentObservation() {
        table = auditedSession.observation
        errorMessage = nil
        schedulePersistence()
    }

    private func schedulePersistence() {
        do {
            let state = try auditedSession.versionedState(modifiedAt: Date())
            enqueuePersistence(state)
        } catch {
            errorMessage = "This hand is still playable, but it could not be saved."
        }
    }

    @discardableResult
    private func enqueuePersistence(
        _ state: PrismetVersionedGameState
    ) -> Task<Void, Never> {
        let predecessor = pendingPersistence
        let store = self.store
        let task = Task { @MainActor [weak self] in
            await predecessor?.value
            do {
                try await store.save(state)
                self?.errorMessage = nil
            } catch {
                self?.errorMessage = "This hand is still playable, but it could not be saved."
            }
        }
        pendingPersistence = task
        return task
    }

    private func enterRecovery(reason: RecoveryReason) {
        loadState = .recoveryRequired(reason)
        switch reason {
        case .corrupt:
            errorMessage = "The saved hand is damaged. Start Fresh keeps a diagnostic copy first."
        case .unsupported:
            errorMessage = "This saved hand uses a newer format. Start Fresh keeps a diagnostic copy first."
        }
    }

    private func takeNextSeed() -> UInt64 {
        if let nextPreviewSeed {
            self.nextPreviewSeed = nextPreviewSeed &+ 0x9e3779b97f4a7c15
            return nextPreviewSeed
        }
        return seedSource()
    }

    private static let versionSupport = PrismetVersionSupport(
        versions: [
            PrismetSupportedGameVersion(
                gameID: PrismetBlackjackRulesV1.canonicalGameID,
                rulesVersion: PrismetBlackjackRulesV1.rulesVersion,
                payloadVersion: PrismetBlackjackRulesV1.payloadVersion,
                randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
                hashAlgorithm: .fnv1a64V1
            )
        ]
    )

    private static func recoveryReason(
        for error: PrismetVersionedGameStateError
    ) -> RecoveryReason {
        switch error {
        case .unsupportedGameID,
             .unsupportedRulesVersion,
             .unsupportedPayloadVersion,
             .unsupportedRandomizerVersion,
             .unsupportedHashAlgorithm:
            return .unsupported
        case .invalidGameID,
             .invalidRulesVersion,
             .invalidPayloadVersion,
             .invalidRandomizerVersion,
             .payloadHashMismatch:
            return .corrupt
        }
    }

    private static func startSession(seed: UInt64) -> PrismetBlackjackAuditedSession {
        do {
            return try PrismetBlackjackAuditedSession.start(seed: seed)
        } catch {
            preconditionFailure("The standard Practice Blackjack deck could not start: \(error)")
        }
    }

    private static func auditResolutionSummary(
        _ resolution: PrismetBlackjackResolution
    ) -> String {
        let outcome: String
        switch resolution.outcome {
        case .playerWins: outcome = "Player hand"
        case .dealerWins: outcome = "Dealer hand"
        case .tie: outcome = "Equal totals"
        case .abandoned: outcome = "Hand ended"
        }
        return "\(outcome) · player \(resolution.playerValue.total), dealer \(resolution.dealerValue.total)"
    }

}

private func casinoSystemSeed() -> UInt64 {
    var generator = SystemRandomNumberGenerator()
    return UInt64.random(in: UInt64.min...UInt64.max, using: &generator)
}
