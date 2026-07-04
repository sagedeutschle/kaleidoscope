import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ModelIO
import AppKit
import OSLog

// MARK: - Board3DView (public contract)

/// An angled, near-isometric 3D chess board (the "Apple Chess"-style view).
///
/// It renders `game.position` with SceneKit, mirrors the 2D board's highlight
/// semantics (selection / last move / check / legal-move dots) and routes a
/// click through `game.tap(_:)`. Because it reads and mutates the same shared
/// `GameState`, hot-swapping between this and the 2D board never loses a game.
struct Board3DView: View {
    @ObservedObject var game: GameState
    let theme: Theme
    let dragPlacement: Board3DDragPlacement

    var body: some View {
        // `game` is observed here so any @Published change re-evaluates this
        // body, produces a fresh wrapper value, and drives `updateNSView`.
        Board3DSceneView(game: game,
                         theme: theme,
                         dragPlacement: dragPlacement,
                         position: game.position,
                         selected: game.selectedSquare,
                         destinations: game.legalDestinations,
                         last: game.lastMove,
                         checked: game.checkedKingSquare)
    }
}

// MARK: - Geometry constants

private enum BoardConst {
    /// Pitch between tile centers is 1.0; tiles are a hair smaller so the
    /// dark base slab shows through as thin grid lines.
    static let tileSize: CGFloat = 0.96
    static let tileThickness: CGFloat = 0.20
    /// Y of a tile's top surface (pieces rest from here upward).
    static let tileTop: CGFloat = tileThickness / 2   // 0.10
}

private let board3DLogger = Logger(subsystem: "com.gtrktscrb.kaleidoscope", category: "board3d")

// MARK: - SceneKit-backed NSView

/// Conforming to `View` (via `NSViewRepresentable`) infers `@MainActor`
/// isolation for this whole type, so every helper below is main-actor isolated
/// and may freely touch `game` and SceneKit objects.
private struct Board3DSceneView: NSViewRepresentable {
    let game: GameState
    let theme: Theme
    let dragPlacement: Board3DDragPlacement
    let position: Position
    let selected: Square?
    let destinations: Set<Square>
    let last: Move?
    let checked: Square?

    func makeCoordinator() -> Coordinator { Coordinator(game: game) }

    // MARK: Build (once)

    func makeNSView(context: Context) -> SCNView {
        let coord = context.coordinator
        let scnView = ClickableSCNView(frame: .zero)
        let scene = SCNScene()
        scnView.scene = scene

        buildBase(in: scene, coordinator: coord)
        buildTiles(in: scene, coordinator: coord)

        scene.rootNode.addChildNode(coord.piecesRoot)
        scene.rootNode.addChildNode(coord.markersRoot)

        buildCamera(in: scene, view: scnView)
        buildLights(in: scene)

        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isJitteringEnabled = true
        scnView.backgroundColor = theme.boardEdge.nsColor
        // Guarantees state changes are reflected on screen without relying on
        // implicit redraw heuristics; the scene is tiny so this is cheap.
        scnView.rendersContinuously = true
        coord.dragPlacement = dragPlacement

        // Dispatch clicks directly from the view to avoid gesture recognizer
        // conflicts with SceneKit's built-in camera controls.
        scnView.clickHandler = { [weak coord, weak scnView] point in
            guard let coord, let scnView else { return }
            coord.handleClick(at: point, in: scnView)
        }
        scnView.dragStartHandler = { [weak coord, weak scnView] point in
            guard let coord, let scnView else { return false }
            return coord.beginPieceDrag(at: point, in: scnView)
        }
        scnView.dragMoveHandler = { [weak coord, weak scnView] point in
            guard let coord, let scnView else { return }
            coord.updatePieceDrag(at: point, in: scnView)
        }
        scnView.dragEndHandler = { [weak coord, weak scnView] point in
            guard let coord, let scnView else { return }
            coord.endPieceDrag(at: point, in: scnView)
        }
        coord.scnView = scnView

        return scnView
    }

    // MARK: Reconcile (every state change)

    func updateNSView(_ nsView: SCNView, context: Context) {
        let coord = context.coordinator

        nsView.backgroundColor = theme.boardEdge.nsColor
        coord.slabNode?.geometry?.firstMaterial?.diffuse.contents = theme.boardEdge.nsColor
        let dragPlacementChanged = coord.renderedDragPlacement != dragPlacement
        coord.dragPlacement = dragPlacement
        if dragPlacementChanged && dragPlacement == .snappy {
            coord.loosePiecePlacements.removeAll()
        }

        refreshTiles(coordinator: coord,
                     selected: selected,
                     last: last,
                     checked: checked)
        // Pieces are heavy meshes — only rebuild when the position or theme
        // actually changes, not on every selection/marker update.
        if coord.pieceNodesDirty || coord.renderedPosition != position || coord.renderedThemeId != theme.id || dragPlacementChanged {
            rebuildPieces(coordinator: coord, position: position)
            coord.renderedPosition = position
            coord.renderedThemeId = theme.id
            coord.renderedDragPlacement = dragPlacement
            coord.pieceNodesDirty = false
        }
        rebuildMarkers(coordinator: coord, destinations: destinations)
    }

    // MARK: - Scene construction helpers

    private func buildBase(in scene: SCNScene, coordinator coord: Coordinator) {
        let slab = SCNBox(width: 8.7, height: 0.5, length: 8.7, chamferRadius: 0.08)
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = theme.boardEdge.nsColor
        mat.specular.contents = NSColor(white: 0.2, alpha: 1)
        mat.shininess = 0.1
        slab.materials = [mat]

        let node = SCNNode(geometry: slab)
        // Slab top sits flush under the tile bottoms (tile bottom = -tileTop).
        node.position = SCNVector3(0, -BoardConst.tileTop - 0.25, 0)
        scene.rootNode.addChildNode(node)
        coord.slabNode = node
    }

    private func buildTiles(in scene: SCNScene, coordinator coord: Coordinator) {
        var tiles: [SCNNode] = []
        tiles.reserveCapacity(64)
        for index in 0..<64 {
            let sq = Square(index: index)
            let box = SCNBox(width: BoardConst.tileSize,
                             height: BoardConst.tileThickness,
                             length: BoardConst.tileSize,
                             chamferRadius: 0.012)
            let mat = SCNMaterial()
            mat.lightingModel = .blinn
            mat.specular.contents = NSColor(white: 0.18, alpha: 1)
            mat.shininess = 0.06
            // a1 (file 0, rank 0) is DARK -> dark when (file + rank) is even.
            let isDark = (sq.file + sq.rank) % 2 == 0
            mat.diffuse.contents = (isDark ? theme.darkSquare : theme.lightSquare).nsColor
            box.materials = [mat]

            let node = SCNNode(geometry: box)
            node.position = tileCenter(file: sq.file, rank: sq.rank, y: 0)
            node.name = Coordinator.squareName(index)
            scene.rootNode.addChildNode(node)
            tiles.append(node)
        }
        coord.tileNodes = tiles
    }

    private func buildCamera(in scene: SCNScene, view: SCNView) {
        let cam = SCNCamera()
        cam.fieldOfView = 42
        cam.zNear = 0.1
        cam.zFar = 200
        cam.usesOrthographicProjection = false

        let node = SCNNode()
        node.camera = cam
        // High and toward +Z (White's near side); ~43 degrees down.
        node.position = SCNVector3(0, 9.0, 9.5)
        node.look(at: SCNVector3(0, 0, 0))   // one-time aim; lets camera control orbit freely
        scene.rootNode.addChildNode(node)
        view.pointOfView = node
    }

    private func buildLights(in scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 1, alpha: 1)
        ambient.intensity = 380
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.color = NSColor(white: 1, alpha: 1)
        key.intensity = 850
        key.castsShadow = true
        key.shadowSampleCount = 16
        key.shadowRadius = 4
        key.shadowColor = NSColor(white: 0, alpha: 0.35)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(5, 12, 7)
        keyNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 220
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-6, 7, -5)
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Per-update helpers

    private func refreshTiles(coordinator coord: Coordinator,
                              selected: Square?,
                              last: Move?,
                              checked: Square?) {
        guard coord.tileNodes.count == 64 else { return }
        for index in 0..<64 {
            let sq = Square(index: index)
            let isDark = (sq.file + sq.rank) % 2 == 0
            let base = (isDark ? theme.darkSquare : theme.lightSquare).nsColor

            var highlight: NSColor? = nil
            var glow: CGFloat = 0
            if let c = checked, c == sq {
                highlight = theme.check.nsColor; glow = 0.30
            } else if let s = selected, s == sq {
                highlight = theme.selection.nsColor; glow = 0.22
            } else if let l = last, l.from == sq || l.to == sq {
                highlight = theme.lastMove.nsColor; glow = 0.12
            }

            let mat = coord.tileNodes[index].geometry?.firstMaterial
            if let highlight {
                mat?.diffuse.contents = blend(base, over: highlight, fraction: alphaOf(highlight))
                mat?.emission.contents = scaledRGB(highlight, by: glow)
            } else {
                mat?.diffuse.contents = base
                mat?.emission.contents = NSColor.black
            }
        }
    }

    private func rebuildPieces(coordinator coord: Coordinator, position: Position) {
        let root = coord.piecesRoot
        for child in root.childNodes { child.removeFromParentNode() }
        coord.pruneLoosePiecePlacements(for: position)

        // Two shared materials per rebuild keep it cheap (32 pieces max).
        let whiteMat = pieceMaterial(.white)
        let blackMat = pieceMaterial(.black)

        for index in 0..<64 {
            let sq = Square(index: index)
            guard let piece = position.piece(at: sq) else { continue }
            guard let base = baseGeometry(for: piece.type, coordinator: coord) else { continue }

            // SCNGeometry.copy() shares the heavy vertex data but allows an
            // independent material, so tinting white/black is essentially free.
            guard let geo = base.copy() as? SCNGeometry else { continue }
            geo.firstMaterial = piece.color == .white ? whiteMat : blackMat

            let node = SCNNode(geometry: geo)
            // Source model's origin is at its bbox corner; recenter on the base
            // so node.position lands it on the tile center, resting on the top.
            let (lo, hi) = geo.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2)
            node.scale = SCNVector3(Self.modelScale, Self.modelScale, Self.modelScale)
            node.position = tileCenter(file: sq.file, rank: sq.rank, y: BoardConst.tileTop)
            if let loosePosition = coord.loosePosition(for: sq, piece: piece) {
                node.position = loosePosition
            }
            node.name = Coordinator.squareName(index)   // a hit on a piece maps to its square
            if piece.type == .knight {                  // knights face the opponent
                node.eulerAngles = SCNVector3(0, piece.color == .white ? 0 : CGFloat.pi, 0)
            }
            root.addChildNode(node)
        }
    }

    /// Source units are ~mm (king ≈ 78); 0.017 lands pawn ≈ 0.73, king ≈ 1.33,
    /// matching the tile/scene scale.
    private static let modelScale: CGFloat = 0.017

    /// Loads + caches the real Staunton OBJ mesh for a piece type (parsed once).
    /// "Staunton-Pieces" by clarkerubber (MIT) — see models3d/CREDITS.md.
    private func baseGeometry(for type: PieceType, coordinator coord: Coordinator) -> SCNGeometry? {
        if let g = coord.baseGeometry[type.rawValue] { return g }
        guard let url = Bundle.main.url(forResource: type.rawValue, withExtension: "obj"),
              let mesh = MDLAsset(url: url).object(at: 0) as? MDLMesh else { return nil }
        let g = SCNGeometry(mdlMesh: mesh)
        coord.baseGeometry[type.rawValue] = g
        return g
    }

    private func rebuildMarkers(coordinator coord: Coordinator, destinations: Set<Square>) {
        let root = coord.markersRoot
        for child in root.childNodes { child.removeFromParentNode() }

        let dot = theme.legalDot.nsColor
        let opacity = max(0.4, alphaOf(dot))
        for sq in destinations {
            let disc = SCNCylinder(radius: 0.16, height: 0.04)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = dot
            mat.transparency = opacity
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = false
            disc.materials = [mat]

            let node = SCNNode(geometry: disc)
            node.castsShadow = false
            node.position = tileCenter(file: sq.file, rank: sq.rank, y: BoardConst.tileTop + 0.035)
            node.name = Coordinator.squareName(sq.index)   // clicking a dot selects that square
            root.addChildNode(node)
        }
    }

    // MARK: - Piece geometry (distinct silhouette per type)

    private func pieceMaterial(_ color: PieceColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = (color == .white ? theme.whitePiece : theme.blackPiece).nsColor
        // White pieces previously washed out: a glossy near-white under the key
        // light blew out to the same value as the cream squares, so they were
        // hard to see. Keep white matte + opaque so it reads as a solid 3D form;
        // black keeps a touch more sheen.
        m.specular.contents = NSColor(white: color == .white ? 0.18 : 0.45, alpha: 1)
        m.shininess = color == .white ? 0.05 : 0.22
        m.transparency = 1
        m.locksAmbientWithDiffuse = true
        return m
    }

    // (The procedural primitive pieces were replaced by the real Staunton OBJ
    // models loaded + cached in `baseGeometry(for:coordinator:)` above.)

    // MARK: - Coordinate mapping

    /// White's rank 1 is nearest the camera (+Z front), a-file on the left (-X).
    private func tileCenter(file: Int, rank: Int, y: CGFloat) -> SCNVector3 {
        SCNVector3(CGFloat(file) - 3.5, y, CGFloat(7 - rank) - 3.5)
    }

    // MARK: - Coordinator

    /// Holds the live SceneKit references and routes clicks to `game`.
    /// Explicitly `@MainActor`: an `NSObject` subclass does not inherit the
    /// main-actor isolation that `View` confers, yet it must touch `game`.
    @MainActor
    final class Coordinator: NSObject {
        let game: GameState
        weak var scnView: SCNView?

        var tileNodes: [SCNNode] = []
        let piecesRoot = SCNNode()
        let markersRoot = SCNNode()
        var slabNode: SCNNode?

        // Caches so heavy meshes parse once and pieces only rebuild on change.
        var baseGeometry: [String: SCNGeometry] = [:]
        var renderedPosition: Position?
        var renderedThemeId: String?
        var renderedDragPlacement: Board3DDragPlacement?
        var pieceNodesDirty = false
        var dragPlacement: Board3DDragPlacement = .loose
        var loosePiecePlacements: [Int: LoosePiecePlacement] = [:]
        private var draggedSquare: Square?
        private weak var draggedPieceNode: SCNNode?
        private var draggedPieceOriginalPosition: SCNVector3?

        struct LoosePiecePlacement {
            let piece: Piece
            let position: SCNVector3
        }

        init(game: GameState) {
            self.game = game
            super.init()
        }

        static func squareName(_ index: Int) -> String { "sq_\(index)" }

        func handleClick(at point: NSPoint, in view: SCNView) {
            guard let square = square(at: point, in: view) else {
                board3DLogger.info("click missed board geometry")
                return
            }
            board3DLogger.info("resolved click to square \(square.algebraic, privacy: .public)")
            game.tap(square)
        }

        func beginPieceDrag(at point: NSPoint, in view: SCNView) -> Bool {
            guard let square = square(at: point, in: view),
                  game.canSelect(square),
                  let pieceNode = pieceNode(on: square) else {
                return false
            }

            draggedSquare = square
            draggedPieceNode = pieceNode
            draggedPieceOriginalPosition = pieceNode.position
            pieceNode.opacity = 0.72
            pieceNode.renderingOrder = 50

            if game.selectedSquare != square {
                game.tap(square)
            }

            board3DLogger.info("begin drag from square \(square.algebraic, privacy: .public)")
            return true
        }

        func updatePieceDrag(at point: NSPoint, in view: SCNView) {
            guard let pieceNode = draggedPieceNode else {
                return
            }

            switch dragPlacement {
            case .loose:
                guard let boardPoint = boardPoint(at: point, in: view, y: BoardConst.tileTop) else { return }
                pieceNode.position = SCNVector3(boardPoint.x, BoardConst.tileTop + 0.06, boardPoint.z)
            case .snappy:
                guard let square = square(at: point, in: view, ignoring: pieceNode) else { return }
                pieceNode.position = tileCenter(file: square.file, rank: square.rank, y: BoardConst.tileTop + 0.06)
            }
        }

        func endPieceDrag(at point: NSPoint, in view: SCNView) {
            guard let from = draggedSquare else { return }
            let movingNode = draggedPieceNode
            let target = square(at: point, in: view, ignoring: movingNode)

            guard let target, target != from else {
                resetDraggedPiece(restorePosition: true)
                board3DLogger.info("end drag without target from square \(from.algebraic, privacy: .public)")
                return
            }

            board3DLogger.info("end drag from \(from.algebraic, privacy: .public) to \(target.algebraic, privacy: .public)")
            let positionBeforeMove = game.position
            game.tap(target)
            let didMove = game.position != positionBeforeMove

            if didMove {
                clearLoosePlacement(on: from)
                if dragPlacement == .loose,
                   let movedPiece = game.position.piece(at: target),
                   let visualPosition = movingNode?.position {
                    rememberLoosePlacement(piece: movedPiece, on: target, visualPosition: visualPosition)
                } else {
                    clearLoosePlacement(on: target)
                }
                // The mesh was moved directly during the drag, so invalidate the
                // cache and let the next SwiftUI update rebuild from the model.
                pieceNodesDirty = true
                renderedPosition = nil
                resetDraggedPiece(restorePosition: false)
                scnView?.needsDisplay = true
            } else {
                resetDraggedPiece(restorePosition: true)
            }
        }

        private func square(at point: NSPoint, in view: SCNView, ignoring ignoredNode: SCNNode? = nil) -> Square? {
            let hits = view.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,   // front-to-back
                .ignoreHiddenNodes: true
            ])
            // First hit that resolves to a board square wins; ignore stray hits.
            for hit in hits {
                if let ignoredNode, node(hit.node, isDescendantOf: ignoredNode) {
                    continue
                }
                if let square = square(for: hit.node) {
                    return square
                }
            }
            return nil
        }

        private func pieceNode(on square: Square) -> SCNNode? {
            piecesRoot.childNodes.first { $0.name == Self.squareName(square.index) }
        }

        func pruneLoosePiecePlacements(for position: Position) {
            loosePiecePlacements = loosePiecePlacements.filter { index, placement in
                position.piece(at: index) == placement.piece
            }
        }

        func loosePosition(for square: Square, piece: Piece) -> SCNVector3? {
            guard let placement = loosePiecePlacements[square.index], placement.piece == piece else {
                return nil
            }
            return placement.position
        }

        private func rememberLoosePlacement(piece: Piece, on square: Square, visualPosition: SCNVector3) {
            loosePiecePlacements[square.index] = LoosePiecePlacement(
                piece: piece,
                position: SCNVector3(visualPosition.x, BoardConst.tileTop, visualPosition.z)
            )
        }

        private func clearLoosePlacement(on square: Square) {
            loosePiecePlacements.removeValue(forKey: square.index)
        }

        private func resetDraggedPiece(restorePosition: Bool) {
            if let draggedPieceNode, let draggedPieceOriginalPosition {
                if restorePosition {
                    draggedPieceNode.position = draggedPieceOriginalPosition
                }
                draggedPieceNode.opacity = 1
                draggedPieceNode.renderingOrder = 0
            }
            draggedSquare = nil
            draggedPieceNode = nil
            draggedPieceOriginalPosition = nil
        }

        private func tileCenter(file: Int, rank: Int, y: CGFloat) -> SCNVector3 {
            SCNVector3(CGFloat(file) - 3.5, y, CGFloat(7 - rank) - 3.5)
        }

        private func boardPoint(at point: NSPoint, in view: SCNView, y: CGFloat) -> SCNVector3? {
            let near = view.unprojectPoint(SCNVector3(point.x, point.y, 0))
            let far = view.unprojectPoint(SCNVector3(point.x, point.y, 1))
            let dy = far.y - near.y
            guard abs(dy) > 0.0001 else { return nil }

            let t = (y - near.y) / dy
            guard t >= 0 else { return nil }

            return SCNVector3(
                near.x + (far.x - near.x) * t,
                y,
                near.z + (far.z - near.z) * t
            )
        }

        private func node(_ node: SCNNode, isDescendantOf ancestor: SCNNode) -> Bool {
            var current: SCNNode? = node
            while let candidate = current {
                if candidate === ancestor { return true }
                current = candidate.parent
            }
            return false
        }

        /// Walks up the node tree to the nearest "sq_<index>" ancestor.
        private func square(for node: SCNNode) -> Square? {
            var current: SCNNode? = node
            while let n = current {
                if let name = n.name, name.hasPrefix("sq_"),
                   let index = Int(name.dropFirst(3)), index >= 0, index < 64 {
                    return Square(index: index)
                }
                current = n.parent
            }
            return nil
        }
    }
}

// MARK: - Scene view plumbing

/// A tiny SCNView subclass that forwards uncomplicated mouse clicks to the
/// coordinator while still allowing drag gestures to orbit the camera.
@MainActor
private final class ClickableSCNView: SCNView {
    var clickHandler: ((NSPoint) -> Void)?
    var dragStartHandler: ((NSPoint) -> Bool)?
    var dragMoveHandler: ((NSPoint) -> Void)?
    var dragEndHandler: ((NSPoint) -> Void)?

    private var mouseDownPoint: NSPoint?
    private var isPieceDrag = false
    private var isDragInteraction = false
    private static let dragThresholdSquared: CGFloat = 64

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseDownPoint = point
        isPieceDrag = dragStartHandler?(point) ?? false
        isDragInteraction = false
        if !isPieceDrag {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)

        if isPieceDrag {
            dragMoveHandler?(currentPoint)
            return
        }

        guard let mouseDownPoint else {
            super.mouseDragged(with: event)
            return
        }

        let dx = currentPoint.x - mouseDownPoint.x
        let dy = currentPoint.y - mouseDownPoint.y
        if !isDragInteraction && ((dx * dx) + (dy * dy) > Self.dragThresholdSquared) {
            isDragInteraction = true
        }

        if isDragInteraction {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let upPoint = convert(event.locationInWindow, from: nil)

        defer { mouseDownPoint = nil }
        defer { isPieceDrag = false }
        defer { isDragInteraction = false }

        if isPieceDrag {
            dragEndHandler?(upPoint)
            return
        }

        super.mouseUp(with: event)
        guard let downPoint = mouseDownPoint else { return }

        let dx = upPoint.x - downPoint.x
        let dy = upPoint.y - downPoint.y
        let movedEnoughForDrag = isDragInteraction || ((dx * dx) + (dy * dy) > Self.dragThresholdSquared)
        guard !movedEnoughForDrag else { return }

        board3DLogger.info("forwarding click at \(upPoint.x, privacy: .public), \(upPoint.y, privacy: .public)")
        clickHandler?(upPoint)
    }
}

// MARK: - Color math (nonisolated; pure value transforms)

/// Alpha of an sRGB-normalized color.
private func alphaOf(_ color: NSColor) -> CGFloat {
    (color.usingColorSpace(.sRGB) ?? color).alphaComponent
}

/// `base` tinted toward `over` by `fraction` (0...1), returned fully opaque.
private func blend(_ base: NSColor, over: NSColor, fraction: CGFloat) -> NSColor {
    guard let b = base.usingColorSpace(.sRGB), let t = over.usingColorSpace(.sRGB) else { return over }
    let k = max(0, min(1, fraction))
    return NSColor(srgbRed: b.redComponent * (1 - k) + t.redComponent * k,
                   green: b.greenComponent * (1 - k) + t.greenComponent * k,
                   blue: b.blueComponent * (1 - k) + t.blueComponent * k,
                   alpha: 1)
}

/// RGB scaled by `factor` (used for a subtle emissive glow), alpha forced to 1.
private func scaledRGB(_ color: NSColor, by factor: CGFloat) -> NSColor {
    guard let c = color.usingColorSpace(.sRGB) else { return color }
    return NSColor(srgbRed: c.redComponent * factor,
                   green: c.greenComponent * factor,
                   blue: c.blueComponent * factor,
                   alpha: 1)
}
