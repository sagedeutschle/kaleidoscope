import Foundation
import PrismetShared

actor PracticeBlackjackStore {
    nonisolated let fileURL: URL
    private let readData: @Sendable (URL) throws -> Data
    private let preserveFile: @Sendable (URL, URL) throws -> Void

    init(
        fileURL: URL = PracticeBlackjackStore.defaultFileURL(),
        readData: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        preserveFile: @escaping @Sendable (URL, URL) throws -> Void = { source, destination in
            try FileManager.default.copyItem(at: source, to: destination)
        }
    ) {
        self.fileURL = fileURL
        self.readData = readData
        self.preserveFile = preserveFile
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    func loadData() throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try readData(fileURL)
    }

    func save(_ state: PrismetVersionedGameState) throws {
        try ensureDirectory()
        let encoded = try PrismetVersionedGameStateCodec.encode(state)
        try encoded.write(to: fileURL, options: [.atomic])
    }

    func preserveExistingFile() throws -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        try ensureDirectory()
        let destination = fileURL.deletingLastPathComponent().appendingPathComponent(
            "practice-blackjack-diagnostic-\(UUID().uuidString.lowercased()).json"
        )
        try preserveFile(fileURL, destination)
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
