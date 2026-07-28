import Foundation

actor PracticeBlackjackStore {
    private let rootURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL = PracticeBlackjackStore.defaultRootURL(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func load() throws -> Data? {
        guard fileManager.fileExists(atPath: saveURL.path) else { return nil }
        return try Data(contentsOf: saveURL)
    }

    func save(_ data: Data) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try data.write(to: saveURL, options: [.atomic])
    }

    @discardableResult
    func preserveDiagnosticCopy() throws -> Bool {
        guard let data = try load() else { return false }
        try fileManager.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
        let copyURL = diagnosticsURL.appendingPathComponent("preserved-\(UUID().uuidString).json")
        try data.write(to: copyURL, options: [.atomic])
        return true
    }

    func diagnosticCopies() throws -> [Data] {
        guard fileManager.fileExists(atPath: diagnosticsURL.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: diagnosticsURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map { try Data(contentsOf: $0) }
    }

    static func defaultRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Prismet", isDirectory: true)
            .appendingPathComponent("PracticeCasino", isDirectory: true)
    }

    private var saveURL: URL {
        rootURL.appendingPathComponent("blackjack.json")
    }

    private var diagnosticsURL: URL {
        rootURL.appendingPathComponent("Preserved Saves", isDirectory: true)
    }
}
