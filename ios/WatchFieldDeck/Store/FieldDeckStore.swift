import Foundation
import WatchConnectivity
import WatchFieldDeckCore

final class FieldDeckStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: FieldDeckSnapshot
    @Published private(set) var linkStatus = "Offline snapshot ready"
    @Published private(set) var isReachable = false

    private static let snapshotDefaultsKey = "prismet.fieldDeck.persistedSnapshot"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.snapshotDefaultsKey),
           let saved = try? JSONDecoder().decode(FieldDeckSnapshot.self, from: data),
           saved.schemaVersion == FieldDeckSnapshot.currentSchemaVersion {
            snapshot = saved
        } else {
            snapshot = .july13
        }
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func requestRefresh() {
        guard WCSession.isSupported() else {
            linkStatus = "Phone link unavailable"
            return
        }

        let session = WCSession.default
        isReachable = session.isReachable
        guard session.isReachable else {
            linkStatus = "Phone out of reach · using saved pulse"
            return
        }

        linkStatus = "Refreshing…"
        session.sendMessage(
            [FieldDeckCodec.refreshRequestKey: true],
            replyHandler: { [weak self] context in
                self?.accept(context: context, status: "Updated from iPhone")
            },
            errorHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.linkStatus = "Refresh paused · using saved pulse"
                }
            }
        )
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
            self?.linkStatus = error == nil ? "Phone link ready" : "Offline snapshot ready"
        }
        if activationState == .activated {
            accept(context: session.receivedApplicationContext, status: "Updated from iPhone")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
            self?.linkStatus = session.isReachable
                ? "Phone link ready"
                : "Offline snapshot ready"
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        accept(context: context, status: "Updated from iPhone")
    }

    private func accept(context: [String: Any], status: String) {
        guard let candidate = try? FieldDeckCodec.snapshot(from: context) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  FieldDeckCodec.shouldAccept(candidate, replacing: self.snapshot)
            else { return }
            self.snapshot = candidate
            self.linkStatus = status
            if let data = try? JSONEncoder().encode(candidate) {
                self.defaults.set(data, forKey: Self.snapshotDefaultsKey)
            }
        }
    }
}
