import SwiftUI
import SceneKit
import UIKit

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). SceneKit board view.
//
// The live, interactive 3D board. Wraps an SCNView with the house camera/tap conventions
// (see ChessSceneKitBoardView): built-in orbit-turntable camera for zoom/pan/orbit, plus a
// touch-splitting SCNView subclass so a clean tap places a piece while a drag orbits the camera.
// Taps hit-test to a named node and are only honored when they match a CURRENTLY legal target,
// so tapping scenery never does anything unexpected. State is pushed in by diffing in updateUIView.

enum CatanTapIntent: Equatable {
    case vertex(Int)
    case edge(Int)
    case hex(Int)
}

struct CatanBoard3DView: UIViewRepresentable {
    let game: CatanGame
    let theme: CatanTheme
    let pieceStyle: CatanPieceStyle
    let playerColors: [CatanRGB]
    let autoRotate: Bool
    let reduceMotion: Bool
    let legalVertices: [Int]
    let legalEdges: [Int]
    let legalHexes: [Int]
    let accent: CatanRGB
    let onTap: (CatanTapIntent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> SCNView {
        let coordinator = context.coordinator
        let view = TappableCatanSCNView(frame: .zero)
        let scene = SCNScene()
        view.scene = scene

        let builder = CatanScene3D(theme: theme, pieceStyle: pieceStyle, playerColors: playerColors)
        coordinator.builder = builder
        scene.rootNode.addChildNode(builder.root)
        builder.fullSync(game: game)
        builder.installLights(in: scene)

        let cam = builder.makeCameraNode()
        scene.rootNode.addChildNode(cam)
        view.pointOfView = cam
        scene.background.contents = theme.background.uiColor

        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.defaultCameraController.minimumVerticalAngle = 5
        view.defaultCameraController.maximumVerticalAngle = 88
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isJitteringEnabled = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = theme.background.uiColor

        coordinator.renderedGame = game
        coordinator.renderedThemeID = theme.id
        coordinator.renderedPiece = pieceStyle
        coordinator.applyMarkers(legalVertices, legalEdges, legalHexes, accent, force: true)
        coordinator.applyAutoRotate(autoRotate && !reduceMotion)

        view.tapHandler = { [weak coordinator, weak view] point in
            guard let coordinator, let view else { return }
            coordinator.handleTap(at: point, in: view)
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.onTap = onTap
        c.legalVertices = legalVertices
        c.legalEdges = legalEdges
        c.legalHexes = legalHexes
        guard let builder = c.builder, let scene = uiView.scene else { return }

        if c.renderedThemeID != theme.id || c.renderedPiece != pieceStyle {
            builder.theme = theme
            builder.pieceStyle = pieceStyle
            builder.playerColors = playerColors
            builder.fullSync(game: game)
            builder.installLights(in: scene)              // idempotent
            scene.background.contents = theme.background.uiColor
            uiView.backgroundColor = theme.background.uiColor
            c.renderedThemeID = theme.id
            c.renderedPiece = pieceStyle
            c.renderedGame = game
        } else if c.renderedGame != game {
            builder.playerColors = playerColors
            builder.sync(game: game)
            c.renderedGame = game
        }

        c.applyMarkers(legalVertices, legalEdges, legalHexes, accent, force: false)
        c.applyAutoRotate(autoRotate && !reduceMotion)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        var onTap: (CatanTapIntent) -> Void
        var builder: CatanScene3D?
        var renderedGame: CatanGame?
        var renderedThemeID = ""
        var renderedPiece: CatanPieceStyle = .cottage
        var legalVertices: [Int] = []
        var legalEdges: [Int] = []
        var legalHexes: [Int] = []
        private var markerKey = ""
        private var rotating = false

        init(onTap: @escaping (CatanTapIntent) -> Void) { self.onTap = onTap }

        func handleTap(at point: CGPoint, in view: SCNView) {
            let hits = view.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true
            ])
            for hit in hits {
                var node: SCNNode? = hit.node
                while let n = node {
                    if let v = CatanSceneGeometry.vertexIndex(n.name), legalVertices.contains(v) {
                        onTap(.vertex(v)); return
                    }
                    if let e = CatanSceneGeometry.edgeIndex(n.name), legalEdges.contains(e) {
                        onTap(.edge(e)); return
                    }
                    if let h = CatanSceneGeometry.hexIndex(n.name), legalHexes.contains(h) {
                        onTap(.hex(h)); return
                    }
                    node = n.parent
                }
            }
        }

        func applyMarkers(_ v: [Int], _ e: [Int], _ h: [Int], _ accent: CatanRGB, force: Bool) {
            let key = "\(v.sorted())|\(e.sorted())|\(h.sorted())"
            guard force || key != markerKey else { return }
            markerKey = key
            builder?.setMarkers(vertices: v, edges: e, hexes: h, accent: accent)
        }

        func applyAutoRotate(_ on: Bool) {
            guard on != rotating, let root = builder?.root else { return }
            rotating = on
            if on {
                let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 48))
                root.runAction(spin, forKey: "spin")
            } else {
                root.removeAction(forKey: "spin")
                root.eulerAngles = SCNVector3(root.eulerAngles.x, 0, root.eulerAngles.z)
            }
        }
    }
}

/// Splits touch input two ways, mirroring ChessSceneKitBoardView: a drag past the threshold
/// orbits the turntable camera; a clean tap (no meaningful movement) fires the tap handler.
private final class TappableCatanSCNView: SCNView {
    var tapHandler: ((CGPoint) -> Void)?

    private var touchStart: CGPoint?
    private var didDrag = false
    private static let dragThresholdSquared: CGFloat = 64   // 8pt of movement

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            touchStart = touch.location(in: self)
            didDrag = false
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touchStart, let touch = touches.first {
            let p = touch.location(in: self)
            let dx = p.x - touchStart.x, dy = p.y - touchStart.y
            if (dx * dx) + (dy * dy) > Self.dragThresholdSquared { didDrag = true }
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point = touches.first?.location(in: self)
        super.touchesEnded(touches, with: event)
        defer { touchStart = nil; didDrag = false }
        guard !didDrag, let point else { return }
        tapHandler?(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
        didDrag = false
        super.touchesCancelled(touches, with: event)
    }
}
