import Foundation
import PrismetShared

actor PracticeBlackjackStore {
    nonisolated let fileURL: URL

    init(fileURL: URL = PracticeBlackjackStore.defaultFileURL()) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    func loadData() throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try Data(contentsOf: fileURL)
    }

    func save(_ state: PrismetVersionedGameState) throws {
        try ensureDirectory()
        let encoded = try PrismetVersionedGameStateCodec.encode(state)
        try encoded.write(to: fileURL, options: [.atomic])
    }

    @discardableResult
    func preserveDiagnosticCopy(_ data: Data) throws -> URL {
        try ensureDirectory()
        let destination = fileURL.deletingLastPathComponent().appendingPathComponent(
            "practice-blackjack-diagnostic-\(UUID().uuidString.lowercased()).json"
        )
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private nonisolated static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let bundleName = Bundle.main.bundleIdentifier ?? "com.gtrktscrb.prismet"
        return base
            .appendingPathComponent(bundleName, isDirectory: true)
            .appendingPathComponent("PracticeBlackjack", isDirectory: true)
            .appendingPathComponent("hand.json")
    }
}
