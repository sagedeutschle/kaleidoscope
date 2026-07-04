import Foundation
import SwiftUI

struct LegoBuilderSnapshot: Codable, Hashable {
    var version: Int
    var document: LegoBuildDocument
    var selectedSize: LegoBrickSize
    var selectedColor: LegoBrickColor
    var selectedLayer: Int
    var selectedOrigin: LegoGridPoint
    var selectedBrickID: UUID?
    var canvasStyle: BoardStyle
    var controls: BrickControls

    static var placeholder: LegoBuilderSnapshot {
        LegoBuilderSnapshot(version: 1,
                            document: LegoBuildDocument(),
                            selectedSize: .twoByFour,
                            selectedColor: .classicRed,
                            selectedLayer: 0,
                            selectedOrigin: LegoGridPoint(x: 4, y: 4),
                            selectedBrickID: nil,
                            canvasStyle: .iso,
                            controls: .defaults)
    }
}

@MainActor
final class LegoBuilderSession: ObservableObject {
    @Published private(set) var document: LegoBuildDocument { didSet { save() } }
    @Published var selectedSize: LegoBrickSize { didSet { save() } }
    @Published var selectedColor: LegoBrickColor { didSet { save() } }
    @Published var selectedLayer: Int { didSet { save() } }
    @Published var selectedOrigin: LegoGridPoint { didSet { save() } }
    @Published var selectedBrickID: UUID? { didSet { save() } }
    @Published var canvasStyle: BoardStyle { didSet { save() } }
    @Published var controls: BrickControls { didSet { save() } }
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""
    private var isApplyingSnapshot = false
    private var undoStack: [LegoBuildDocument] = []
    private var redoStack: [LegoBuildDocument] = []

    init(document: LegoBuildDocument = LegoBuildDocument(),
         selectedSize: LegoBrickSize = .twoByFour,
         selectedColor: LegoBrickColor = .classicRed,
         selectedLayer: Int = 0,
         selectedOrigin: LegoGridPoint = LegoGridPoint(x: 4, y: 4),
         selectedBrickID: UUID? = nil,
         canvasStyle: BoardStyle = .iso,
         controls: BrickControls = .defaults) {
        self.document = document
        self.selectedSize = selectedSize
        self.selectedColor = selectedColor
        self.selectedLayer = selectedLayer
        self.selectedOrigin = selectedOrigin
        self.selectedBrickID = selectedBrickID
        self.canvasStyle = canvasStyle
        self.controls = controls
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadLegoBuilder(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            } else {
                save()
            }
        } catch {
            save()
        }
    }

    func reloadSavedState() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        do {
            if let snapshot = try persistenceStore.loadLegoBuilder(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func addBrick(size: LegoBrickSize, color: LegoBrickColor, origin: LegoGridPoint, layer: Int) {
        applyDocumentEdit { document in
            document.add(LegoBrick(size: size, color: color, origin: origin, layer: layer))
        }
        selectedBrickID = nil
    }

    func clearDocument() {
        applyDocumentEdit { document in
            document.clear()
        }
        selectedBrickID = nil
    }

    func moveBrick(id: UUID, dx: Int, dy: Int, dLayer: Int, gridSize: Int) {
        applyDocumentEdit { document in
            document.move(id: id, dx: dx, dy: dy, dLayer: dLayer, gridSize: gridSize)
        }
    }

    func rotateBrick(id: UUID, by quarters: Int, gridSize: Int) {
        applyDocumentEdit { document in
            document.rotate(id: id, by: quarters, gridSize: gridSize)
        }
    }

    func replaceDocument(_ newDocument: LegoBuildDocument) {
        applyDocumentEdit { document in
            document = newDocument
        }
        selectedBrickID = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        clearStaleSelection()
        syncHistoryState()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        clearStaleSelection()
        syncHistoryState()
    }

    func snapshot() -> LegoBuilderSnapshot {
        LegoBuilderSnapshot(version: 1,
                            document: document,
                            selectedSize: selectedSize,
                            selectedColor: selectedColor,
                            selectedLayer: selectedLayer,
                            selectedOrigin: selectedOrigin,
                            selectedBrickID: selectedBrickID,
                            canvasStyle: canvasStyle,
                            controls: controls)
    }

    func restore(from snapshot: LegoBuilderSnapshot, persist: Bool = true) {
        isApplyingSnapshot = true
        document = snapshot.document
        selectedSize = snapshot.selectedSize
        selectedColor = snapshot.selectedColor
        selectedLayer = snapshot.selectedLayer
        selectedOrigin = snapshot.selectedOrigin
        selectedBrickID = snapshot.selectedBrickID
        canvasStyle = snapshot.canvasStyle
        controls = snapshot.controls
        undoStack.removeAll()
        redoStack.removeAll()
        syncHistoryState()
        isApplyingSnapshot = false
        if persist { save() }
    }

    private func applyDocumentEdit(_ edit: (inout LegoBuildDocument) -> Void) {
        var next = document
        edit(&next)
        guard next != document else { return }

        undoStack.append(document)
        redoStack.removeAll()
        document = next
        clearStaleSelection()
        syncHistoryState()
    }

    private func clearStaleSelection() {
        guard let selectedBrickID else { return }
        if !document.bricks.contains(where: { $0.id == selectedBrickID }) {
            self.selectedBrickID = nil
        }
    }

    private func syncHistoryState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty, !isApplyingSnapshot else { return }
        try? persistenceStore.saveLegoBuilder(snapshot(), windowSessionID: windowSessionID)
    }
}
