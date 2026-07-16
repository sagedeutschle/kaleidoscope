import XCTest
@testable import Prismet

@MainActor
final class CatanAdventurerStoreTests: XCTestCase {
    private final class RemoveFailingFileManager: FileManager {
        override func removeItem(at URL: URL) throws {
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testMissingFileReturnsEmptyState() throws {
        let result = try CatanAdventurerFileStore(rootURL: root()).loadRecovering()

        XCTAssertEqual(result.state, .empty)
        XCTAssertNil(result.quarantinedURL)
    }

    func testActiveAndDraftRoundTrip() throws {
        let store = CatanAdventurerFileStore(rootURL: root())
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        draft.step = .review
        let state = CatanAdventurerState(active: try CatanAdventurer.make(from: draft), draft: draft)

        try store.save(state)

        XCTAssertEqual(try store.loadRecovering().state, state)
    }

    func testCorruptFileIsQuarantined() throws {
        let root = root()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("state.json"))

        let result = try CatanAdventurerFileStore(
            rootURL: root,
            now: { Date(timeIntervalSince1970: 42) }
        ).loadRecovering()

        XCTAssertEqual(result.state, .empty)
        XCTAssertEqual(result.quarantinedURL?.lastPathComponent, "state-corrupt-42.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(result.quarantinedURL).path))
    }

    func testCorruptFileUsesANonDestructiveSuffixWhenQuarantineNameExists() throws {
        let root = root()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("state.json"))
        let existing = root.appendingPathComponent("state-corrupt-42.json")
        try Data("keep-me".utf8).write(to: existing)

        let result = try CatanAdventurerFileStore(
            rootURL: root,
            now: { Date(timeIntervalSince1970: 42) }
        ).loadRecovering()

        XCTAssertEqual(result.quarantinedURL?.lastPathComponent, "state-corrupt-42-1.json")
        XCTAssertEqual(try Data(contentsOf: existing), Data("keep-me".utf8))
    }

    func testFutureSchemaIsNotOverwritten() throws {
        let root = root()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("state.json")
        let data = Data("{\"schemaVersion\":99,\"active\":null,\"draft\":null}".utf8)
        try data.write(to: file)

        XCTAssertThrowsError(try CatanAdventurerFileStore(rootURL: root).loadRecovering()) {
            XCTAssertEqual($0 as? CatanAdventurerStoreError, .unsupportedSchema(99))
        }
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testCoordinatorCannotOverwriteFutureSchemaAfterLoad() throws {
        let root = root()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("state.json")
        let data = Data("{\"schemaVersion\":99,\"active\":null,\"draft\":null}".utf8)
        try data.write(to: file)
        let store = CatanAdventurerStore(fileStore: CatanAdventurerFileStore(rootURL: root))

        store.load()
        store.beginDraft()
        store.updateDraft { $0.name = "Rowan" }

        XCTAssertThrowsError(try store.completeDraft()) {
            XCTAssertEqual($0 as? CatanAdventurerStoreError, .unsupportedSchema(99))
        }
        XCTAssertEqual(store.draft?.name, "Rowan")
        XCTAssertNil(store.active)
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testDeleteTouchesOnlyCharacterState() throws {
        let root = root()
        let sibling = root.deletingLastPathComponent().appendingPathComponent("GameSaves/keep.json")
        try FileManager.default.createDirectory(at: sibling.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: sibling)
        let store = CatanAdventurerFileStore(rootURL: root)

        try store.save(.empty)
        try store.delete()

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("state.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
    }

    func testDefaultRootUsesKaleidoscopeCatanAdventurerDirectory() {
        XCTAssertEqual(CatanAdventurerFileStore.defaultRootURL().lastPathComponent, "CatanAdventurer")
        XCTAssertEqual(CatanAdventurerFileStore.defaultRootURL().deletingLastPathComponent().lastPathComponent, "Kaleidoscope")
    }

    func testCoordinatorPersistsDraftMutation() throws {
        let fileStore = CatanAdventurerFileStore(rootURL: root())
        let store = CatanAdventurerStore(fileStore: fileStore)

        store.beginDraft()
        store.updateDraft { $0.name = "Rowan" }

        XCTAssertEqual(try fileStore.loadRecovering().state.draft?.name, "Rowan")
        XCTAssertEqual(store.draft?.name, "Rowan")
    }

    func testCoordinatorCompletesDraftAndClearsPersistedDraft() throws {
        let fileStore = CatanAdventurerFileStore(rootURL: root())
        let store = CatanAdventurerStore(fileStore: fileStore)
        store.beginDraft()
        store.updateDraft { $0.name = "Rowan" }

        let character = try store.completeDraft()
        let persisted = try fileStore.loadRecovering().state

        XCTAssertEqual(store.active, character)
        XCTAssertNil(store.draft)
        XCTAssertEqual(persisted.active, character)
        XCTAssertNil(persisted.draft)
    }

    func testCoordinatorDeletesActiveCharacter() throws {
        let fileStore = CatanAdventurerFileStore(rootURL: root())
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        try fileStore.save(CatanAdventurerState(active: try CatanAdventurer.make(from: draft)))
        let store = CatanAdventurerStore(fileStore: fileStore)
        store.load()

        store.deleteActive()

        XCTAssertNil(store.active)
        XCTAssertEqual(try fileStore.loadRecovering().state, .empty)
    }

    func testCoordinatorPreservesActiveCharacterWhenDeleteFails() throws {
        let root = root()
        let writableStore = CatanAdventurerFileStore(rootURL: root)
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        let character = try CatanAdventurer.make(from: draft)
        try writableStore.save(CatanAdventurerState(active: character))
        let failingStore = CatanAdventurerFileStore(
            rootURL: root,
            fileManager: RemoveFailingFileManager()
        )
        let store = CatanAdventurerStore(fileStore: failingStore)
        store.load()

        store.deleteActive()

        XCTAssertEqual(store.active, character)
        XCTAssertTrue(store.message?.localizedCaseInsensitiveContains("retry") == true)
        XCTAssertEqual(try writableStore.loadRecovering().state.active, character)
    }

    func testCoordinatorKeepsDraftAndShowsRetryMessageWhenWriteFails() throws {
        let blockedRoot = root()
        try Data("not a directory".utf8).write(to: blockedRoot)
        let store = CatanAdventurerStore(fileStore: CatanAdventurerFileStore(rootURL: blockedRoot))

        store.beginDraft()
        store.updateDraft { $0.name = "Rowan" }

        XCTAssertEqual(store.draft?.name, "Rowan")
        XCTAssertNotNil(store.message)
        XCTAssertTrue(store.message?.localizedCaseInsensitiveContains("retry") == true)
    }

    func testCoordinatorCompletionPreservesDraftWhenWriteFails() throws {
        let blockedRoot = root()
        try Data("not a directory".utf8).write(to: blockedRoot)
        let store = CatanAdventurerStore(fileStore: CatanAdventurerFileStore(rootURL: blockedRoot))
        store.beginDraft()
        store.updateDraft { $0.name = "Rowan" }

        XCTAssertThrowsError(try store.completeDraft()) {
            XCTAssertEqual($0 as? CatanAdventurerStoreError, .persistenceFailed)
        }
        XCTAssertEqual(store.draft?.name, "Rowan")
        XCTAssertNil(store.active)
        XCTAssertTrue(store.message?.localizedCaseInsensitiveContains("retry") == true)
    }
}
