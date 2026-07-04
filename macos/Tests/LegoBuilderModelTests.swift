import XCTest
@testable import Kaleidoscope

final class LegoBuilderModelTests: XCTestCase {
    func testAddingBrickStoresGridPlacementAndPartIdentity() {
        var document = LegoBuildDocument()
        let brick = LegoBrick(
            size: .twoByFour,
            color: .classicRed,
            origin: LegoGridPoint(x: 2, y: 3),
            layer: 1
        )

        document.add(brick)

        XCTAssertEqual(document.bricks, [brick])
        XCTAssertEqual(document.partsSummary.first?.partNumber, "3001")
        XCTAssertEqual(document.partsSummary.first?.quantity, 1)
    }

    func testWantedListExportIncludesPartColorAndQuantity() {
        var document = LegoBuildDocument()
        document.add(LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 0, y: 0), layer: 0))
        document.add(LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 4, y: 0), layer: 0))

        let xml = BrickLinkWantedListExporter.xml(for: document)

        XCTAssertTrue(xml.contains("<ITEMID>3001</ITEMID>"))
        XCTAssertTrue(xml.contains("<COLOR>5</COLOR>"))
        XCTAssertTrue(xml.contains("<MINQTY>2</MINQTY>"))
    }

    func testCatalogIncludesPlatesAndExpandedBrickLinkColors() {
        XCTAssertEqual(LegoBrickSize.oneByFourPlate.partNumber, "3710")
        XCTAssertEqual(LegoBrickSize.twoBySixPlate.elementKind, .plate)
        XCTAssertEqual(LegoBrickColor.tan.brickLinkColorId, 2)
        XCTAssertEqual(LegoBrickColor.darkBluishGray.brickLinkColorId, 85)
    }

    func testMoveByDeltaUpdatesBrickOrigin() {
        var document = LegoBuildDocument()
        let brick = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 2, y: 3), layer: 0)
        document.add(brick)

        document.move(id: brick.id, dx: 1, dy: 2, dLayer: 0, gridSize: 12)

        XCTAssertEqual(document.bricks.first?.origin, LegoGridPoint(x: 3, y: 5))
    }

    func testMoveClampsFootprintWithinBoard() {
        var document = LegoBuildDocument()
        // 2x4 brick: max legal origin is x = 12-2 = 10, y = 12-4 = 8.
        let brick = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 10, y: 8), layer: 0)
        document.add(brick)

        document.move(id: brick.id, dx: 5, dy: 5, dLayer: 0, gridSize: 12)
        XCTAssertEqual(document.bricks.first?.origin, LegoGridPoint(x: 10, y: 8))

        document.move(id: brick.id, dx: -50, dy: -50, dLayer: 0, gridSize: 12)
        XCTAssertEqual(document.bricks.first?.origin, LegoGridPoint(x: 0, y: 0))
    }

    func testMoveChangesLayerClampedAtZero() {
        var document = LegoBuildDocument()
        let brick = LegoBrick(size: .twoByTwo, color: .brightBlue, origin: LegoGridPoint(x: 0, y: 0), layer: 1)
        document.add(brick)

        document.move(id: brick.id, dx: 0, dy: 0, dLayer: 2, gridSize: 12)
        XCTAssertEqual(document.bricks.first?.layer, 3)

        document.move(id: brick.id, dx: 0, dy: 0, dLayer: -10, gridSize: 12)
        XCTAssertEqual(document.bricks.first?.layer, 0)
    }

    func testMoveWithUnknownIdDoesNothing() {
        var document = LegoBuildDocument()
        let brick = LegoBrick(size: .twoByTwo, color: .black, origin: LegoGridPoint(x: 1, y: 1), layer: 0)
        document.add(brick)

        document.move(id: UUID(), dx: 3, dy: 3, dLayer: 1, gridSize: 12)

        XCTAssertEqual(document.bricks.first?.origin, LegoGridPoint(x: 1, y: 1))
        XCTAssertEqual(document.bricks.first?.layer, 0)
    }

    // MARK: - Rotation (Q/R flipping)

    func testNewBrickHasNoRotation() {
        let b = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 0, y: 0), layer: 0)
        XCTAssertEqual(b.rotationQuarters, 0)
        XCTAssertEqual(b.footprintWide, 2)
        XCTAssertEqual(b.footprintDeep, 4)
    }

    func testRotateSwapsFootprintDimensions() {
        var doc = LegoBuildDocument()
        let b = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 0, y: 0), layer: 0)
        doc.add(b)

        doc.rotate(id: b.id, by: 1, gridSize: 12)

        XCTAssertEqual(doc.bricks.first?.rotationQuarters, 1)
        XCTAssertEqual(doc.bricks.first?.footprintWide, 4)
        XCTAssertEqual(doc.bricks.first?.footprintDeep, 2)
    }

    func testRotateWrapsModuloFour() {
        var doc = LegoBuildDocument()
        let b = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 0, y: 0), layer: 0)
        doc.add(b)

        doc.rotate(id: b.id, by: 4, gridSize: 12)
        XCTAssertEqual(doc.bricks.first?.rotationQuarters, 0)

        doc.rotate(id: b.id, by: -1, gridSize: 12)
        XCTAssertEqual(doc.bricks.first?.rotationQuarters, 3)
    }

    func testRotateReclampsFootprintWithinBoard() {
        var doc = LegoBuildDocument()
        // 2x4 at x=10 is legal (maxX = 12-2). After a 90° turn the width is 4, so maxX = 8.
        let b = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 10, y: 0), layer: 0)
        doc.add(b)

        doc.rotate(id: b.id, by: 1, gridSize: 12)

        XCTAssertEqual(doc.bricks.first?.origin.x, 8)
    }

    func testMoveUsesRotatedFootprintForClamping() {
        var doc = LegoBuildDocument()
        let b = LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 0, y: 0), layer: 0)
        doc.add(b)
        doc.rotate(id: b.id, by: 1, gridSize: 12)   // now 4 wide x 2 deep

        doc.move(id: b.id, dx: 50, dy: 50, dLayer: 0, gridSize: 12)

        XCTAssertEqual(doc.bricks.first?.origin, LegoGridPoint(x: 8, y: 10))
    }

    func testRotateUnknownIdDoesNothing() {
        var doc = LegoBuildDocument()
        let b = LegoBrick(size: .twoByTwo, color: .black, origin: LegoGridPoint(x: 1, y: 1), layer: 0)
        doc.add(b)

        doc.rotate(id: UUID(), by: 1, gridSize: 12)

        XCTAssertEqual(doc.bricks.first?.rotationQuarters, 0)
    }

    func testWantedListImportCreatesDocumentFromBrickLinkXml() throws {
        let xml = """
        <INVENTORY>
          <ITEM>
            <ITEMTYPE>P</ITEMTYPE>
            <ITEMID>3710</ITEMID>
            <COLOR>2</COLOR>
            <MINQTY>2</MINQTY>
            <CONDITION>N</CONDITION>
          </ITEM>
          <ITEM>
            <ITEMTYPE>P</ITEMTYPE>
            <ITEMID>3001</ITEMID>
            <COLOR>5</COLOR>
            <MINQTY>1</MINQTY>
            <CONDITION>N</CONDITION>
          </ITEM>
        </INVENTORY>
        """

        let document = try BrickLinkWantedListImporter.document(from: xml)

        XCTAssertEqual(document.bricks.count, 3)
        XCTAssertEqual(document.partsSummary.count, 2)
        XCTAssertTrue(document.bricks.contains { $0.size == .oneByFourPlate && $0.color == .tan })
        XCTAssertTrue(document.bricks.contains { $0.size == .twoByFour && $0.color == .classicRed })
    }

    func testLegoBuilderSnapshotRoundTripsThroughPersistenceStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString
        let snapshot = LegoBuilderSnapshot(
            version: 1,
            document: LegoBuildDocument(bricks: [
                LegoBrick(size: .twoByFour, color: .classicRed, origin: LegoGridPoint(x: 1, y: 2), layer: 3)
            ]),
            selectedSize: .twoBySixPlate,
            selectedColor: .orange,
            selectedLayer: 4,
            selectedOrigin: LegoGridPoint(x: 5, y: 6),
            selectedBrickID: UUID(),
            canvasStyle: .flat,
            controls: .defaults
        )

        try store.saveLegoBuilder(snapshot, windowSessionID: sessionID)
        let loaded = try XCTUnwrap(store.loadLegoBuilder(windowSessionID: sessionID))

        XCTAssertEqual(loaded, snapshot)
    }

    @MainActor
    func testLegoBuilderSessionPersistsAfterAddBrick() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString

        let session = LegoBuilderSession()
        session.configurePersistence(windowSessionID: sessionID, store: store)
        session.addBrick(size: .twoByFour,
                         color: .classicRed,
                         origin: LegoGridPoint(x: 1, y: 2),
                         layer: 3)

        let loaded = try XCTUnwrap(store.loadLegoBuilder(windowSessionID: sessionID))
        XCTAssertEqual(loaded.document.bricks.count, 1)
        XCTAssertEqual(loaded.document.bricks.first?.origin, LegoGridPoint(x: 1, y: 2))
    }

    @MainActor
    func testLegoBuilderSessionReloadsCachedStateAfterTransientChanges() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString

        let session = LegoBuilderSession()
        session.configurePersistence(windowSessionID: sessionID, store: store)
        session.addBrick(size: .twoByFour,
                         color: .classicRed,
                         origin: LegoGridPoint(x: 1, y: 2),
                         layer: 3)
        session.selectedSize = .twoBySixPlate
        session.selectedColor = .orange
        session.selectedLayer = 4
        session.selectedOrigin = LegoGridPoint(x: 5, y: 6)
        session.selectedBrickID = session.document.bricks.first?.id
        session.canvasStyle = .flat
        session.controls.invertForwardBack = true

        let saved = session.snapshot()

        let otherSnapshot = LegoBuilderSnapshot(
            version: 1,
            document: LegoBuildDocument(),
            selectedSize: .oneByOne,
            selectedColor: .black,
            selectedLayer: 0,
            selectedOrigin: LegoGridPoint(x: 0, y: 0),
            selectedBrickID: nil,
            canvasStyle: .iso,
            controls: .defaults
        )

        session.restore(from: otherSnapshot, persist: false)
        session.reloadSavedState()

        XCTAssertEqual(session.snapshot(), saved)
    }

    @MainActor
    func testLegoBuilderSessionUndoRedoRestoresDocumentHistory() {
        let session = LegoBuilderSession()

        session.addBrick(size: .twoByFour,
                         color: .classicRed,
                         origin: LegoGridPoint(x: 1, y: 2),
                         layer: 3)
        let placed = session.document

        XCTAssertTrue(session.canUndo)
        XCTAssertFalse(session.canRedo)

        session.undo()

        XCTAssertTrue(session.document.bricks.isEmpty)
        XCTAssertFalse(session.canUndo)
        XCTAssertTrue(session.canRedo)

        session.redo()

        XCTAssertEqual(session.document, placed)
        XCTAssertTrue(session.canUndo)
        XCTAssertFalse(session.canRedo)
    }

    @MainActor
    func testLegoBuilderSessionNewEditClearsRedoHistory() {
        let session = LegoBuilderSession()

        session.addBrick(size: .twoByFour,
                         color: .classicRed,
                         origin: LegoGridPoint(x: 1, y: 2),
                         layer: 0)
        session.undo()
        XCTAssertTrue(session.canRedo)

        session.addBrick(size: .oneByOne,
                         color: .brightBlue,
                         origin: LegoGridPoint(x: 3, y: 4),
                         layer: 0)

        XCTAssertFalse(session.canRedo)
        XCTAssertEqual(session.document.bricks.count, 1)
        XCTAssertEqual(session.document.bricks.first?.size, .oneByOne)
    }
}
