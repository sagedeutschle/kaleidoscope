import Foundation
import PrismetShared
import SwiftUI

@MainActor
final class PracticeBlackjackSession: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case corruptSave
        case failed(String)
    }

    enum Sheet: String, Identifiable {
        case rulesAndFairness
        case replayAndFairness
        case corruptSave

        var id: String { rawValue }
    }

    @Published private(set) var table: PrismetBlackjackObservation
    @Published private(set) var loadState: LoadState = .idle
    @Published var presentedSheet: Sheet?

    var canHit: Bool { table.legalCommands.contains(.hit) }
    var canStand: Bool { table.legalCommands.contains(.stand) }
    var canStartNewHand: Bool { table.phase == .completed || table.phase == .abandoned }

    var auditSummary: PracticeBlackjackAuditSummary? {
        guard canStartNewHand,
              let disclosure = try? auditedSession.auditDisclosure() else {
            return nil
        }
        return PracticeBlackjackAuditSummary(
            seed: disclosure.seed,
            rulesVersion: disclosure.rulesVersion,
            randomizerVersion: disclosure.randomizerVersion,
            commandCount: disclosure.commands.count,
            revealedCards: disclosure.revealedDrawOrder.map {
                $0.accessibilityLabel(isFaceUp: true)
            },
            verification: "Verified"
        )
    }

    private let store: PracticeBlackjackStore
    private var nextPreviewSeed: UInt64?
    private var auditedSession: PrismetBlackjackAuditedSession
    private var didAttemptRestore = false
    private var didPreserveCorruptSave = false

    init(
        previewSeed: UInt64? = nil,
        store: PracticeBlackjackStore = PracticeBlackjackStore()
    ) {
        self.store = store
        let initialSeed = previewSeed ?? Self.secureSeed()
        self.nextPreviewSeed = previewSeed.map { $0 &+ 1 }
        let initial = Self.startSession(seed: initialSeed)
        self.auditedSession = initial
        self.table = initial.observation
    }

    func restoreOrDeal() async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true
        loadState = .loading

        do {
            if let data = try await store.load() {
                let state = try PrismetVersionedGameStateCodec.decodeSupported(
                    data,
                    support: PrismetVersionSupport(
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
                )
                replaceSession(try PrismetBlackjackAuditedSession.restore(from: state))
            }
            loadState = .ready
            await persist()
        } catch {
            loadState = .corruptSave
            presentedSheet = .corruptSave
        }
    }

    func hit() {
        apply(.hit)
    }

    func stand() {
        apply(.stand)
    }

    func endHand() {
        guard table.canEndHand else { return }
        do {
            replaceSession(try auditedSession.endingHand())
            persistAfterAction()
        } catch {
            loadState = .failed("The hand could not be ended. Your current table is unchanged.")
        }
    }

    func newHand() {
        guard canStartNewHand else { return }
        replaceSession(Self.startSession(seed: nextSeed()))
        persistAfterAction()
    }

    func persist() async {
        guard loadState != .corruptSave else { return }
        do {
            let state = try auditedSession.versionedState(modifiedAt: Date())
            try await store.save(PrismetVersionedGameStateCodec.encode(state))
        } catch {
            loadState = .failed("This hand is still visible, but it could not be saved.")
        }
    }

    func preserveDiagnosticCopy() async {
        guard loadState == .corruptSave, !didPreserveCorruptSave else { return }
        do {
            didPreserveCorruptSave = try await store.preserveDiagnosticCopy()
        } catch {
            loadState = .failed("The diagnostic copy could not be preserved.")
        }
    }

    func startFresh() async {
        if loadState == .corruptSave, !didPreserveCorruptSave {
            await preserveDiagnosticCopy()
        }
        guard loadState == .corruptSave || didPreserveCorruptSave else { return }
        replaceSession(Self.startSession(seed: nextSeed()))
        loadState = .ready
        presentedSheet = nil
        await persist()
    }

    private func apply(_ command: PrismetBlackjackCommand) {
        guard table.legalCommands.contains(command) else { return }
        do {
            replaceSession(try auditedSession.applying(command))
            persistAfterAction()
        } catch {
            loadState = .failed("That action could not be applied. Your current table is unchanged.")
        }
    }

    private func replaceSession(_ session: PrismetBlackjackAuditedSession) {
        auditedSession = session
        table = session.observation
        if loadState != .loading {
            loadState = .ready
        }
    }

    private func persistAfterAction() {
        Task { await persist() }
    }

    private func nextSeed() -> UInt64 {
        guard let previewSeed = nextPreviewSeed else {
            return Self.secureSeed()
        }
        nextPreviewSeed = previewSeed &+ 1
        return previewSeed
    }

    private static func startSession(seed: UInt64) -> PrismetBlackjackAuditedSession {
        do {
            return try PrismetBlackjackAuditedSession.start(seed: seed)
        } catch {
            preconditionFailure("Practice Blackjack could not create a valid shuffled hand: \(error)")
        }
    }

    private static func secureSeed() -> UInt64 {
        var generator = SystemRandomNumberGenerator()
        return generator.next()
    }
}
