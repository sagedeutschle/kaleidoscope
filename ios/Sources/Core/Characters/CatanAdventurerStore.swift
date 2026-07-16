import Combine
import Foundation

struct CatanAdventurerState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var active: CatanAdventurer?
    var draft: CatanAdventurerDraft?

    init(schemaVersion: Int = Self.currentSchemaVersion,
         active: CatanAdventurer? = nil,
         draft: CatanAdventurerDraft? = nil) {
        self.schemaVersion = schemaVersion
        self.active = active
        self.draft = draft
    }

    static let empty = Self()

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, active, draft
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw CatanAdventurerStoreError.unsupportedSchema(version)
        }

        schemaVersion = version
        active = try container.decodeIfPresent(CatanAdventurer.self, forKey: .active)
        draft = try container.decodeIfPresent(CatanAdventurerDraft.self, forKey: .draft)
    }
}

struct CatanAdventurerLoadResult: Equatable {
    var state: CatanAdventurerState
    var quarantinedURL: URL?
}

enum CatanAdventurerStoreError: Error, Equatable {
    case unsupportedSchema(Int)
    case noDraft
    case persistenceFailed
}

struct CatanAdventurerFileStore {
    let rootURL: URL
    var fileManager: FileManager = .default
    var now: () -> Date = Date.init

    init(rootURL: URL = Self.defaultRootURL(),
         fileManager: FileManager = .default,
         now: @escaping () -> Date = Date.init) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.now = now
    }

    static func defaultRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Kaleidoscope/CatanAdventurer", isDirectory: true)
    }

    func loadRecovering() throws -> CatanAdventurerLoadResult {
        let fileURL = stateURL
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return CatanAdventurerLoadResult(state: .empty, quarantinedURL: nil)
        }

        do {
            let state = try JSONDecoder().decode(CatanAdventurerState.self, from: Data(contentsOf: fileURL))
            return CatanAdventurerLoadResult(state: state, quarantinedURL: nil)
        } catch let error as CatanAdventurerStoreError {
            throw error
        } catch {
            let timestamp = Int(now().timeIntervalSince1970)
            var quarantinedURL = rootURL.appendingPathComponent("state-corrupt-\(timestamp).json")
            var suffix = 1
            while fileManager.fileExists(atPath: quarantinedURL.path) {
                quarantinedURL = rootURL.appendingPathComponent("state-corrupt-\(timestamp)-\(suffix).json")
                suffix += 1
            }
            try fileManager.moveItem(at: fileURL, to: quarantinedURL)
            return CatanAdventurerLoadResult(state: .empty, quarantinedURL: quarantinedURL)
        }
    }

    func save(_ state: CatanAdventurerState) throws {
        var normalizedState = state
        normalizedState.schemaVersion = CatanAdventurerState.currentSchemaVersion

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(normalizedState)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try data.write(to: stateURL, options: .atomic)
    }

    func delete() throws {
        let fileURL = stateURL
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private var stateURL: URL {
        rootURL.appendingPathComponent("state.json", isDirectory: false)
    }
}

@MainActor
final class CatanAdventurerStore: ObservableObject {
    @Published private(set) var active: CatanAdventurer?
    @Published private(set) var draft: CatanAdventurerDraft?
    @Published private(set) var message: String?

    private let fileStore: CatanAdventurerFileStore
    private var blockedSchemaVersion: Int?

    init(fileStore: CatanAdventurerFileStore = CatanAdventurerFileStore()) {
        self.fileStore = fileStore
    }

    func load() {
        do {
            let result = try fileStore.loadRecovering()
            blockedSchemaVersion = nil
            active = result.state.active
            draft = result.state.draft
            message = result.quarantinedURL == nil
                ? nil
                : "Your previous character state was recovered. You can start again safely."
        } catch CatanAdventurerStoreError.unsupportedSchema(let version) {
            blockedSchemaVersion = version
            message = futureSchemaMessage
        } catch {
            message = "Your character could not be loaded. Please try again."
        }
    }

    func beginDraft(editing character: CatanAdventurer? = nil) {
        draft = (character ?? active)?.editableDraft ?? .new()
        persistCurrentState()
    }

    func updateDraft(_ mutation: (inout CatanAdventurerDraft) -> Void) {
        guard var draft else { return }
        mutation(&draft)
        self.draft = draft
        persistCurrentState()
    }

    func completeDraft() throws -> CatanAdventurer {
        if let blockedSchemaVersion {
            message = futureSchemaMessage
            throw CatanAdventurerStoreError.unsupportedSchema(blockedSchemaVersion)
        }
        guard let draft else { throw CatanAdventurerStoreError.noDraft }
        let character = try CatanAdventurer.make(from: draft)
        do {
            try fileStore.save(CatanAdventurerState(active: character, draft: nil))
            active = character
            self.draft = nil
            message = nil
            return character
        } catch {
            message = "Your character changes are kept here, but could not be saved. Please retry."
            throw CatanAdventurerStoreError.persistenceFailed
        }
    }

    func deleteActive() {
        guard blockedSchemaVersion == nil else {
            message = futureSchemaMessage
            return
        }
        do {
            try fileStore.delete()
            active = nil
            draft = nil
            message = nil
        } catch {
            message = "Your character could not be deleted. Please retry."
        }
    }

    private func persistCurrentState() {
        guard blockedSchemaVersion == nil else {
            message = futureSchemaMessage
            return
        }
        do {
            try fileStore.save(CatanAdventurerState(active: active, draft: draft))
            message = nil
        } catch {
            message = "Your character changes are kept here, but could not be saved. Please retry."
        }
    }

    private var futureSchemaMessage: String {
        "This character was created by a newer version of Prismet. It was left unchanged."
    }
}
