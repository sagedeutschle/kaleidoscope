import ModelIO
import SceneKit
import SceneKit.ModelIO
import SwiftUI
import UIKit

struct ChessSceneKitBoardView: UIViewRepresentable {
    let position: Position
    let selectedSquare: Square?
    let targets: Set<Int>
    let lastFrom: Int?
    let lastTo: Int?
    let theme: ChessBoardTheme
    let onSquareTap: (Square) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSquareTap: onSquareTap)
    }

    func makeUIView(context: Context) -> SCNView {
        let coordinator = context.coordinator
        let view = TappableChessSCNView(frame: .zero)
        let scene = SCNScene()
        view.scene = scene

        buildBase(in: scene, coordinator: coordinator)
        buildTiles(in: scene, coordinator: coordinator)
        scene.rootNode.addChildNode(coordinator.piecesRoot)
        scene.rootNode.addChildNode(coordinator.markersRoot)
        buildCamera(in: scene, view: view)
        buildLights(in: scene)

        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isJitteringEnabled = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = theme.boardEdge.uiColor
        view.tapHandler = { [weak coordinator, weak view] point in
            guard let coordinator, let view else { return }
            coordinator.handleTap(at: point, in: view)
        }

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSquareTap = onSquareTap
        coordinator.slabNode?.geometry?.firstMaterial?.diffuse.contents = theme.boardEdge.uiColor
        refreshTiles(coordinator: coordinator)

        if coordinator.renderedPosition != position {
            rebuildPieces(coordinator: coordinator)
            coordinator.renderedPosition = position
        }

        rebuildMarkers(coordinator: coordinator)
    }

    private func buildBase(in scene: SCNScene, coordinator: Coordinator) {
        let slab = SCNBox(width: 8.7, height: 0.5, length: 8.7, chamferRadius: 0.08)
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = theme.boardEdge.uiColor
        material.specular.contents = UIColor(white: 0.2, alpha: 1)
        material.shininess = 0.1
        slab.materials = [material]

        let node = SCNNode(geometry: slab)
        node.position = SCNVector3(0, -Self.tileTop - 0.25, 0)
        scene.rootNode.addChildNode(node)
        coordinator.slabNode = node
    }

    private func buildTiles(in scene: SCNScene, coordinator: Coordinator) {
        var tiles: [SCNNode] = []
        tiles.reserveCapacity(64)

        for index in 0..<64 {
            let square = Square(index: index)
            let box = SCNBox(width: Self.tileSize, height: Self.tileThickness, length: Self.tileSize, chamferRadius: 0.012)
            let material = SCNMaterial()
            material.lightingModel = .blinn
            material.specular.contents = UIColor(white: 0.18, alpha: 1)
            material.shininess = 0.06
            material.diffuse.contents = baseTileColor(for: square)
            box.materials = [material]

            let node = SCNNode(geometry: box)
            node.position = ChessSceneGeometry.tileCenter(file: square.file, rank: square.rank, y: 0)
            node.name = ChessSceneGeometry.squareName(index)
            scene.rootNode.addChildNode(node)
            tiles.append(node)
        }

        coordinator.tileNodes = tiles
    }

    private func buildCamera(in scene: SCNScene, view: SCNView) {
        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.1
        camera.zFar = 200

        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(0, 9.0, 9.5)
        node.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(node)
        view.pointOfView = node
    }

    private func buildLights(in scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor.white
        ambient.intensity = 380
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.color = UIColor.white
        key.intensity = 850
        key.castsShadow = true
        key.shadowSampleCount = 16
        key.shadowRadius = 4
        key.shadowColor = UIColor(white: 0, alpha: 0.35)
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

    private func refreshTiles(coordinator: Coordinator) {
        guard coordinator.tileNodes.count == 64 else { return }
        for index in 0..<64 {
            let square = Square(index: index)
            let base = baseTileColor(for: square)
            let material = coordinator.tileNodes[index].geometry?.firstMaterial

            if checkedSquareIndex == index {
                material?.diffuse.contents = Self.blend(base, over: theme.check.solidUIColor, fraction: 0.60)
                material?.emission.contents = Self.scaled(theme.check.solidUIColor, by: 0.22)
            } else if selectedSquare?.index == index {
                material?.diffuse.contents = Self.blend(base, over: theme.selection.solidUIColor, fraction: 0.55)
                material?.emission.contents = Self.scaled(theme.selection.solidUIColor, by: 0.18)
            } else if lastFrom == index || lastTo == index {
                material?.diffuse.contents = Self.blend(base, over: theme.lastMove.solidUIColor, fraction: 0.32)
                material?.emission.contents = Self.scaled(theme.lastMove.solidUIColor, by: 0.08)
            } else {
                material?.diffuse.contents = base
                material?.emission.contents = UIColor.black
            }
        }
    }

    private func rebuildPieces(coordinator: Coordinator) {
        for child in coordinator.piecesRoot.childNodes {
            child.removeFromParentNode()
        }

        let whiteMaterial = pieceMaterial(.white)
        let blackMaterial = pieceMaterial(.black)

        for index in 0..<64 {
            let square = Square(index: index)
            guard let piece = position.piece(at: square) else { continue }
            let material = piece.color == .white ? whiteMaterial : blackMaterial
            let node = pieceNode(for: piece, material: material, coordinator: coordinator)
            node.position = ChessSceneGeometry.tileCenter(file: square.file, rank: square.rank, y: Self.tileTop)
            node.name = ChessSceneGeometry.squareName(index)
            if piece.type == .knight {
                node.eulerAngles.y = piece.color == .white ? 0 : Float.pi
            }
            coordinator.piecesRoot.addChildNode(node)
        }
    }

    private func rebuildMarkers(coordinator: Coordinator) {
        for child in coordinator.markersRoot.childNodes {
            child.removeFromParentNode()
        }

        for index in targets {
            guard (0..<64).contains(index) else { continue }
            let square = Square(index: index)
            let cylinder = SCNCylinder(radius: 0.16, height: 0.04)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = theme.legalDot.solidUIColor
            material.transparency = 0.78
            material.isDoubleSided = true
            material.writesToDepthBuffer = false
            cylinder.materials = [material]

            let node = SCNNode(geometry: cylinder)
            node.castsShadow = false
            node.position = ChessSceneGeometry.tileCenter(file: square.file, rank: square.rank, y: Self.tileTop + 0.035)
            node.name = ChessSceneGeometry.squareName(index)
            coordinator.markersRoot.addChildNode(node)
        }
    }

    private func pieceNode(for piece: Piece, material: SCNMaterial, coordinator: Coordinator) -> SCNNode {
        if let baseGeometry = baseGeometry(for: piece.type, coordinator: coordinator),
           let geometry = baseGeometry.copy() as? SCNGeometry {
            geometry.materials = Array(repeating: material, count: max(1, geometry.elementCount))
            let node = SCNNode(geometry: geometry)
            let (low, high) = geometry.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((low.x + high.x) / 2, low.y, (low.z + high.z) / 2)
            node.scale = SCNVector3(Self.modelScale, Self.modelScale, Self.modelScale)
            return node
        }

        let text = SCNText(string: piece.type.letter, extrusionDepth: 0.08)
        text.font = UIFont.systemFont(ofSize: 2.4, weight: .heavy)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        text.flatness = 0.04
        text.materials = [material]

        let node = SCNNode(geometry: text)
        let (low, high) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((low.x + high.x) / 2, low.y, (low.z + high.z) / 2)
        node.scale = SCNVector3(0.33, 0.33, 0.33)
        node.eulerAngles.x = -Float.pi / 2
        return node
    }

    private func baseGeometry(for type: PieceType, coordinator: Coordinator) -> SCNGeometry? {
        if let cached = coordinator.baseGeometry[type.rawValue] {
            return cached
        }

        let url = Bundle.main.url(forResource: type.rawValue, withExtension: "obj")
            ?? Bundle.main.url(forResource: type.rawValue, withExtension: "obj", subdirectory: "models3d")
        guard let url else {
            return nil
        }

        let asset = MDLAsset(url: url)
        guard asset.count > 0, let mesh = asset.object(at: 0) as? MDLMesh else {
            return nil
        }

        let geometry = SCNGeometry(mdlMesh: mesh)
        coordinator.baseGeometry[type.rawValue] = geometry
        return geometry
    }

    private func pieceMaterial(_ color: PieceColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = (color == .white ? theme.whitePiece : theme.blackPiece).solidUIColor
        // White pieces washed out as a glossy near-white under the key light; keep
        // white matte + opaque so it reads as a solid form (mirrors the macOS app).
        material.specular.contents = UIColor(white: color == .white ? 0.18 : 0.45, alpha: 1)
        material.shininess = color == .white ? 0.05 : 0.22
        material.locksAmbientWithDiffuse = true
        return material
    }

    private func baseTileColor(for square: Square) -> UIColor {
        (square.file + square.rank) % 2 == 0 ? theme.darkSquare.solidUIColor : theme.lightSquare.solidUIColor
    }

    private var checkedSquareIndex: Int? {
        switch MoveGenerator.status(of: position) {
        case .check(let color):
            return position.kingSquare(of: color)?.index
        default:
            return nil
        }
    }

    final class Coordinator: NSObject {
        var onSquareTap: (Square) -> Void
        var tileNodes: [SCNNode] = []
        var piecesRoot = SCNNode()
        var markersRoot = SCNNode()
        var slabNode: SCNNode?
        var baseGeometry: [String: SCNGeometry] = [:]
        var renderedPosition: Position?

        init(onSquareTap: @escaping (Square) -> Void) {
            self.onSquareTap = onSquareTap
            super.init()
        }

        func handleTap(at point: CGPoint, in view: SCNView) {
            let hits = view.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true
            ])

            for hit in hits {
                if let square = square(for: hit.node) {
                    onSquareTap(square)
                    return
                }
            }
        }

        private func square(for node: SCNNode) -> Square? {
            var current: SCNNode? = node
            while let candidate = current {
                if let name = candidate.name, let index = ChessSceneGeometry.squareIndex(named: name) {
                    return Square(index: index)
                }
                current = candidate.parent
            }
            return nil
        }
    }

    private static let tileSize: CGFloat = 0.96
    private static let tileThickness: CGFloat = 0.20
    private static let tileTop: Float = Float(tileThickness / 2)
    private static let modelScale: Float = 0.017

    private static func blend(_ base: UIColor, over: UIColor, fraction: CGFloat) -> UIColor {
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        var tr: CGFloat = 0
        var tg: CGFloat = 0
        var tb: CGFloat = 0
        var ta: CGFloat = 0
        base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        over.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        let k = max(0, min(1, fraction))
        return UIColor(red: br * (1 - k) + tr * k,
                       green: bg * (1 - k) + tg * k,
                       blue: bb * (1 - k) + tb * k,
                       alpha: 1)
    }

    private static func scaled(_ color: UIColor, by factor: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: 1)
    }
}

private final class TappableChessSCNView: SCNView {
    var tapHandler: ((CGPoint) -> Void)?

    private var touchStart: CGPoint?
    private var didDrag = false
    private static let dragThresholdSquared: CGFloat = 64

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            touchStart = touch.location(in: self)
            didDrag = false
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touchStart, let touch = touches.first {
            let point = touch.location(in: self)
            let dx = point.x - touchStart.x
            let dy = point.y - touchStart.y
            if (dx * dx) + (dy * dy) > Self.dragThresholdSquared {
                didDrag = true
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point = touches.first?.location(in: self)
        super.touchesEnded(touches, with: event)

        defer {
            touchStart = nil
            didDrag = false
        }

        guard !didDrag, let point else { return }
        tapHandler?(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
        didDrag = false
        super.touchesCancelled(touches, with: event)
    }
}
