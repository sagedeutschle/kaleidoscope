import Foundation
import WatchConnectivity
import WatchFieldDeckCore

final class PhoneFieldDeckBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneFieldDeckBridge()
    static let refreshRequestKey = FieldDeckCodec.refreshRequestKey

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    static func applicationContext(for snapshot: FieldDeckSnapshot) throws -> [String: Any] {
        try FieldDeckCodec.context(for: snapshot)
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        pushLatestSnapshot(on: session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message[Self.refreshRequestKey] as? Bool == true else {
            replyHandler([:])
            return
        }

        do {
            let context = try Self.applicationContext(for: latestSnapshot())
            try session.updateApplicationContext(context)
            replyHandler(context)
        } catch {
            replyHandler(["prismet.fieldDeck.error": error.localizedDescription])
        }
    }

    private func pushLatestSnapshot(on session: WCSession) {
        do {
            try session.updateApplicationContext(
                Self.applicationContext(for: latestSnapshot())
            )
        } catch {
            // Application context is best-effort and retries on the next activation or request.
        }
    }

    private func latestSnapshot() -> FieldDeckSnapshot {
        FieldDeckSnapshot.july13.replacingGeneratedAt(Date())
    }
}
