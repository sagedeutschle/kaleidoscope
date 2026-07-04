// PRISM: RELEASE Agent-Design(brickbench-3d) 2026-07-03 — real SceneKit 3D LEGO builder ported from desktop apps/chess-hotswap Sources/Views/LegoBuilder3DView.swift
import SwiftUI
import SceneKit
import UIKit

// MARK: - LegoBuilder3DView (public contract)

/// A genuine SceneKit 3D build view for Brick Bench, ported from the macOS
/// `LegoBuilder3DView`. A tap on the baseplate moves the placement ghost to the
/// tapped stud (so "Add Brick" still works); a tap on a placed brick *selects*
/// it. Touch drag orbits the turntable camera; pinch zooms — both free from
/// `allowsCameraControl` + `.orbitTurntable`.
///
/// The macOS drag-gizmo + keyboard rebinding are omitted here: those are
/// mouse/keyboard-specific, and on iOS the surrounding `EditBar` already
/// exposes move / rotate / layer / delete as touch buttons.
struct LegoBuilder3DView: View {
    let document: LegoBuildDocument
    @Binding var selectedOrigin: LegoGridPoint
    let selectedSize: LegoBrickSize
    let selectedColor: LegoBrickColor
    let selectedLayer: Int
    @Binding var selectedBrickID: UUID?

    var body: some View {
        LegoSceneView(document: document,
                      selectedOrigin: $selectedOrigin,
                      selectedSize: selectedSize,
                      selectedColor: selectedColor,
                      selectedLayer: selectedLayer,
                      selectedBrickID: $selectedBrickID)
    }
}

// MARK: - Geometry constants

private enum BrickConst {
    static let seam: CGFloat = 0.06
    static let chamfer: CGFloat = 0.03
    static let studRadius: CGFloat = 0.30
    static let studHeight: CGFloat = 0.18
    /// Hollow-underside shell: wall/top thickness and the anti-stud tube radii.
    static let wall: CGFloat = 0.16
    static let topSlab: CGFloat = 0.16
    static let tubeOuter: CGFloat = 0.33
    static let tubeInner: CGFloat = 0.22
}

// MARK: - SceneKit-backed UIView

private struct LegoSceneView: UIViewRepresentable {
    let document: LegoBuildDocument
    @Binding var selectedOrigin: LegoGridPoint
    let selectedSize: LegoBrickSize
    let selectedColor: LegoBrickColor
    let selectedLayer: Int
    @Binding var selectedBrickID: UUID?

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Build (once)

    func makeUIView(context: Context) -> SCNView {
        let coord = context.coordinator
        let scnView = TappableLegoSCNView(frame: .zero)
        scnView.tapHandler = { [weak coord, weak scnView] point in
            guard let coord, let scnView else { return }
            coord.handleTap(at: point, in: scnView)
        }
        let scene = SCNScene()
        scnView.scene = scene

        buildBaseplate(in: scene)
        scene.rootNode.addChildNode(coord.bricksRoot)
        scene.rootNode.addChildNode(coord.ghostRoot)

        buildCamera(in: scene, view: scnView)
        buildLights(in: scene)

        // On iOS this gives touch orbit + pinch-zoom for free.
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isJitteringEnabled = true
        // Warm parchment to match the light Brick Bench shell. (iOS UIColor(red:…)
        // is sRGB, matching the desktop's NSColor(srgbRed:…).)
        scnView.backgroundColor = UIColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1)
        scnView.rendersContinuously = true

        return scnView
    }

    // MARK: Reconcile (every state change)

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coord = context.coordinator
        coord.document = document
        // Capture live bindings so the tap handler always reads current state.
        coord.onPickEmpty = { grid in
            selectedBrickID = nil
            selectedOrigin = LegoSceneGeometry.clampedOrigin(grid, for: selectedSize)
        }
        coord.onSelectBrick = { id in
            // Tapping the already-selected brick deselects it (mirrors the iOS
            // 2D board's toggle behavior).
            selectedBrickID = (selectedBrickID == id) ? nil : id
        }
        coord.selectedBrickID = selectedBrickID

        if coord.renderedDocument != document || coord.renderedSelection != selectedBrickID {
            rebuildBricks(coordinator: coord, selected: selectedBrickID)
            coord.renderedDocument = document
            coord.renderedSelection = selectedBrickID
        }

        let ghostKey = GhostKey(origin: selectedOrigin, size: selectedSize, color: selectedColor, layer: selectedLayer)
        if coord.renderedGhost != ghostKey {
            rebuildGhost(coordinator: coord, key: ghostKey)
            coord.renderedGhost = ghostKey
        }
    }

    // MARK: - Scene construction

    private func buildBaseplate(in scene: SCNScene) {
        let span = CGFloat(LegoSceneGeometry.gridSize) + 0.4
        // Classic green baseplate. Studs are deliberately brighter than the slab
        // (tester-flagged: gray-on-gray studs vanished at camera distance).
        let slab = SCNBox(width: span, height: 0.5, length: span, chamferRadius: 0.06)
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = UIColor(red: 0.23, green: 0.50, blue: 0.27, alpha: 1)
        mat.specular.contents = UIColor(white: 0.25, alpha: 1)
        mat.shininess = 0.10
        slab.materials = [mat]
        let slabNode = SCNNode(geometry: slab)
        slabNode.position = SCNVector3(0, Float(LegoSceneGeometry.baseTopY - 0.25), 0)
        slabNode.name = "baseplate"
        scene.rootNode.addChildNode(slabNode)

        let studMat = SCNMaterial()
        studMat.lightingModel = .blinn
        studMat.diffuse.contents = UIColor(red: 0.38, green: 0.68, blue: 0.40, alpha: 1)
        studMat.specular.contents = UIColor(white: 0.55, alpha: 1)
        studMat.shininess = 0.30
        let half = CGFloat(LegoSceneGeometry.gridSize) / 2
        for y in 0..<LegoSceneGeometry.gridSize {
            for x in 0..<LegoSceneGeometry.gridSize {
                let stud = SCNCylinder(radius: BrickConst.studRadius, height: BrickConst.studHeight)
                stud.materials = [studMat]
                let node = SCNNode(geometry: stud)
                // Children of slabNode: y is RELATIVE to the slab's center, not the
                // scene. Slab is 0.5 thick, so its top face is +0.25 — the old
                // baseTopY-based y buried every stud inside the slab geometry.
                node.position = SCNVector3(Float(CGFloat(x) + 0.5 - half),
                                           Float(0.25 + BrickConst.studHeight / 2),
                                           Float(CGFloat(y) + 0.5 - half))
                node.name = "baseplate"
                slabNode.addChildNode(node)
            }
        }
    }

    private func buildCamera(in scene: SCNScene, view: SCNView) {
        let cam = SCNCamera()
        cam.fieldOfView = 42
        cam.zNear = 0.1
        cam.zFar = 200
        let node = SCNNode()
        node.camera = cam
        node.position = SCNVector3(0, 14, 15)
        node.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(node)
        view.pointOfView = node
    }

    private func buildLights(in scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 420
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 820
        key.castsShadow = true
        key.shadowSampleCount = 16
        key.shadowRadius = 4
        key.shadowColor = UIColor(white: 0, alpha: 0.32)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(7, 16, 9)
        keyNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 220
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-8, 9, -6)
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Per-update rebuilds

    private func rebuildBricks(coordinator coord: Coordinator, selected: UUID?) {
        let root = coord.bricksRoot
        for child in root.childNodes { child.removeFromParentNode() }
        for brick in document.bricks {
            let node = makeBrickNode(brick: brick, opacity: 1, selected: brick.id == selected)
            node.name = brick.id.uuidString
            root.addChildNode(node)
        }
    }

    private func rebuildGhost(coordinator coord: Coordinator, key: GhostKey) {
        let root = coord.ghostRoot
        for child in root.childNodes { child.removeFromParentNode() }
        let ghost = LegoBrick(size: key.size, color: key.color,
                              origin: LegoSceneGeometry.clampedOrigin(key.origin, for: key.size),
                              layer: key.layer)
        let node = makeBrickNode(brick: ghost, opacity: 0.42, selected: false)
        node.castsShadow = false
        root.addChildNode(node)
    }

    private func makeBrickNode(brick: LegoBrick, opacity: CGFloat, selected: Bool) -> SCNNode {
        let kind = brick.size.elementKind
        let height = LegoSceneGeometry.height(of: kind)
        let w = CGFloat(brick.size.studsWide) - BrickConst.seam
        let d = CGFloat(brick.size.studsDeep) - BrickConst.seam

        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = brick.color.uiColor
        mat.specular.contents = UIColor(white: 0.5, alpha: 1)
        mat.shininess = 0.28
        mat.transparency = opacity
        mat.isDoubleSided = true        // so the hollow interior reads from below
        if selected { mat.emission.contents = UIColor(white: 0.34, alpha: 1) }

        let parent = SCNNode()
        // Use the rotated footprint so a turned brick still lands on whole studs;
        // the body is modeled at the catalog size and spun about Y.
        let center = LegoSceneGeometry.footprintCenter(origin: brick.origin,
                                                       wide: brick.footprintWide,
                                                       deep: brick.footprintDeep)
        parent.position = SCNVector3(Float(center.x),
                                     Float(LegoSceneGeometry.centerY(layer: brick.layer, kind: kind)),
                                     Float(center.z))
        parent.eulerAngles = SCNVector3(0, Float(-Double(brick.rotationQuarters) * (Double.pi / 2)), 0)
        parent.opacity = opacity

        // Hollow body: closed top + perimeter walls (open underside) + anti-stud tubes.
        for node in makeHollowBody(width: w, depth: d, height: height, kind: kind,
                                   studsWide: brick.size.studsWide, studsDeep: brick.size.studsDeep,
                                   material: mat) {
            parent.addChildNode(node)
        }

        let studMat = SCNMaterial()
        studMat.lightingModel = .blinn
        studMat.diffuse.contents = brick.color.uiColor
        studMat.specular.contents = UIColor(white: 0.55, alpha: 1)
        studMat.shininess = 0.3
        if selected { studMat.emission.contents = UIColor(white: 0.34, alpha: 1) }
        let sw = brick.size.studsWide
        let sd = brick.size.studsDeep
        for j in 0..<sd {
            for i in 0..<sw {
                let stud = SCNCylinder(radius: BrickConst.studRadius, height: BrickConst.studHeight)
                stud.materials = [studMat]
                let node = SCNNode(geometry: stud)
                let lx = CGFloat(i) - CGFloat(sw - 1) / 2
                let lz = CGFloat(j) - CGFloat(sd - 1) / 2
                node.position = SCNVector3(Float(lx), Float(height / 2 + BrickConst.studHeight / 2), Float(lz))
                parent.addChildNode(node)
            }
        }
        return parent
    }

    /// Build a brick body as a hollow shell — a capped top, four perimeter walls,
    /// an open underside, and interior anti-stud tubes — so it reads like a real
    /// LEGO element instead of a solid cube. All parts share `material`.
    private func makeHollowBody(width w: CGFloat, depth d: CGFloat, height: CGFloat,
                                kind: LegoElementKind, studsWide sw: Int, studsDeep sd: Int,
                                material: SCNMaterial) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let t = BrickConst.wall
        let slabT = min(BrickConst.topSlab, height * 0.5)

        // Capped top.
        let slab = SCNBox(width: w, height: slabT, length: d, chamferRadius: BrickConst.chamfer)
        slab.materials = [material]
        let slabNode = SCNNode(geometry: slab)
        slabNode.position = SCNVector3(0, Float(height / 2 - slabT / 2), 0)
        nodes.append(slabNode)

        // Perimeter walls (full height, leaving the bottom open).
        func wall(_ ww: CGFloat, _ dd: CGFloat, x: CGFloat, z: CGFloat) -> SCNNode {
            let b = SCNBox(width: ww, height: height, length: dd, chamferRadius: 0)
            b.materials = [material]
            let n = SCNNode(geometry: b)
            n.position = SCNVector3(Float(x), 0, Float(z))
            return n
        }
        nodes.append(wall(t, d, x: -(w / 2 - t / 2), z: 0))          // left
        nodes.append(wall(t, d, x: (w / 2 - t / 2), z: 0))           // right
        nodes.append(wall(w - 2 * t, t, x: 0, z: -(d / 2 - t / 2)))  // back
        nodes.append(wall(w - 2 * t, t, x: 0, z: (d / 2 - t / 2)))   // front

        // Anti-stud tubes at interior stud intersections (bricks 2+ wide & deep).
        if kind == .brick, sw >= 2, sd >= 2 {
            let tubeHeight = height - slabT
            for j in 1..<sd {
                for i in 1..<sw {
                    let tube = SCNTube(innerRadius: BrickConst.tubeInner,
                                       outerRadius: BrickConst.tubeOuter,
                                       height: tubeHeight)
                    tube.materials = [material]
                    let n = SCNNode(geometry: tube)
                    n.position = SCNVector3(Float(CGFloat(i) - CGFloat(sw) / 2),
                                            Float(-slabT / 2),
                                            Float(CGFloat(j) - CGFloat(sd) / 2))
                    nodes.append(n)
                }
            }
        }
        return nodes
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        let bricksRoot = SCNNode()
        let ghostRoot = SCNNode()

        var document = LegoBuildDocument()
        var selectedBrickID: UUID?

        var renderedDocument: LegoBuildDocument?
        var renderedSelection: UUID??
        var renderedGhost: GhostKey?

        var onPickEmpty: ((LegoGridPoint) -> Void)?
        var onSelectBrick: ((UUID) -> Void)?

        // MARK: Tap → select brick / move ghost
        func handleTap(at point: CGPoint, in view: SCNView) {
            let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            if let brickID = hits.lazy.compactMap({ Self.brickID(for: $0.node) }).first {
                onSelectBrick?(brickID)
                return
            }
            if let hit = hits.first {
                let w = hit.worldCoordinates
                let grid = LegoSceneGeometry.gridPoint(worldX: CGFloat(w.x), worldZ: CGFloat(w.z))
                onPickEmpty?(grid)
            }
        }

        // MARK: Node → identity helpers
        static func brickID(for node: SCNNode) -> UUID? {
            var n: SCNNode? = node
            while let cur = n {
                if let name = cur.name, let id = UUID(uuidString: name) { return id }
                n = cur.parent
            }
            return nil
        }
    }

    struct GhostKey: Equatable {
        let origin: LegoGridPoint
        let size: LegoBrickSize
        let color: LegoBrickColor
        let layer: Int
    }
}

// MARK: - Touch plumbing

/// Splits touch input two ways, mirroring the sibling `ChessSceneKitBoardView`:
/// a drag past the threshold orbits the turntable camera (handled by the default
/// camera controller); a clean tap runs `tapHandler`, which selects a brick or
/// moves the placement ghost.
private final class TappableLegoSCNView: SCNView {
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
}
