import SwiftUI
import SceneKit
import AppKit
import OSLog

// MARK: - Gizmo axis colors (customizable; default toned RGB)

/// Per-axis arrow colors for the move gizmo. Defaults to the universal
/// X=red / Y=green / Z=blue convention (toned down a touch), with a single
/// "active" highlight color. Exposed so a tucked-away setting can recolor them.
struct GizmoAxisColors: Equatable {
    var x: Color = Color(red: 0.898, green: 0.282, blue: 0.302)   // #E5484D
    var y: Color = Color(red: 0.180, green: 0.627, blue: 0.263)   // #2EA043
    var z: Color = Color(red: 0.231, green: 0.510, blue: 0.965)   // #3B82F6
    var active: Color = Color(red: 1.0, green: 0.823, blue: 0.247) // #FFD23F

    static let classic = GizmoAxisColors()

    /// Wong colorblind-safe palette (vermillion / bluish-green / blue).
    static let colorblindSafe = GizmoAxisColors(
        x: Color(red: 0.835, green: 0.369, blue: 0.0),
        y: Color(red: 0.0, green: 0.620, blue: 0.451),
        z: Color(red: 0.337, green: 0.706, blue: 0.914),
        active: Color(red: 0.941, green: 0.894, blue: 0.259)
    )
}

private enum GizmoAxis: String { case x, y, z }

// MARK: - LegoBuilder3DView (public contract)

/// A 3D build view for Brick Bench. A click on the baseplate moves the
/// placement ghost (so "Add Brick" still works); a click on a placed brick
/// *selects* it and raises a Blender/Axiom-style 3-arrow translate gizmo.
/// Dragging an arrow — or pressing the arrow keys — moves that one brick,
/// snapping stud-by-stud. The gizmo only translates; it never resizes a brick.
struct LegoBuilder3DView: View {
    let document: LegoBuildDocument
    @Binding var selectedOrigin: LegoGridPoint
    let selectedSize: LegoBrickSize
    let selectedColor: LegoBrickColor
    let selectedLayer: Int

    @Binding var selectedBrickID: UUID?
    /// Translate the brick with `id` by whole-stud / whole-layer deltas.
    var onMove: (UUID, Int, Int, Int) -> Void
    /// Rotate the brick with `id` by `quarters` 90° turns (Q/R by default).
    var onRotate: (UUID, Int) -> Void
    /// Run a non-selection command such as place / undo / redo.
    var onCommand: (BrickControlAction) -> Void = { _ in }
    /// Current key bindings + behavior toggles.
    var controls: BrickControls = .defaults
    /// When non-nil, the next key press rebinds this action instead of acting.
    @Binding var capturingAction: BrickControlAction?
    /// Called with the captured key code when in rebind mode.
    var onRebind: (BrickControlAction, Int) -> Void
    var axisColors: GizmoAxisColors = .classic

    var body: some View {
        LegoSceneView(document: document,
                      selectedOrigin: $selectedOrigin,
                      selectedSize: selectedSize,
                      selectedColor: selectedColor,
                      selectedLayer: selectedLayer,
                      selectedBrickID: $selectedBrickID,
                      onMove: onMove,
                      onRotate: onRotate,
                      onCommand: onCommand,
                      controls: controls,
                      capturingAction: $capturingAction,
                      onRebind: onRebind,
                      axisColors: axisColors)
    }
}

private let legoLogger = Logger(subsystem: "com.gtrktscrb.kaleidoscope", category: "lego3d")

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

private enum GizmoConst {
    static let shaftRadius: CGFloat = 0.07
    static let shaftLength: CGFloat = 1.7
    static let tipRadius: CGFloat = 0.20
    static let tipLength: CGFloat = 0.50
    /// World distance represented by one drag step on each axis.
    static let studStep: CGFloat = 1.0                       // X / Z = one stud
    static var layerStep: CGFloat { LegoSceneGeometry.brickHeight }   // Y = one layer
}

// MARK: - SceneKit-backed NSView

private struct LegoSceneView: NSViewRepresentable {
    let document: LegoBuildDocument
    @Binding var selectedOrigin: LegoGridPoint
    let selectedSize: LegoBrickSize
    let selectedColor: LegoBrickColor
    let selectedLayer: Int
    @Binding var selectedBrickID: UUID?
    var onMove: (UUID, Int, Int, Int) -> Void
    var onRotate: (UUID, Int) -> Void
    var onCommand: (BrickControlAction) -> Void
    var controls: BrickControls
    @Binding var capturingAction: BrickControlAction?
    var onRebind: (BrickControlAction, Int) -> Void
    var axisColors: GizmoAxisColors

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Build (once)

    func makeNSView(context: Context) -> SCNView {
        let coord = context.coordinator
        let scnView = ClickableLegoSCNView(frame: .zero)
        scnView.coordinator = coord
        let scene = SCNScene()
        scnView.scene = scene

        buildBaseplate(in: scene)
        scene.rootNode.addChildNode(coord.bricksRoot)
        scene.rootNode.addChildNode(coord.ghostRoot)
        scene.rootNode.addChildNode(coord.gizmoRoot)

        buildCamera(in: scene, view: scnView)
        buildLights(in: scene)

        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isJitteringEnabled = true
        // Warm parchment to match the light Brick Bench shell (was a dark slate
        // that clashed with the rustic theme).
        scnView.backgroundColor = NSColor(srgbRed: 0.85, green: 0.80, blue: 0.70, alpha: 1)
        scnView.rendersContinuously = true

        return scnView
    }

    // MARK: Reconcile (every state change)

    func updateNSView(_ nsView: SCNView, context: Context) {
        let coord = context.coordinator
        coord.document = document
        coord.axisColors = axisColors
        // Capture live bindings so input handlers always read current state.
        coord.onPickEmpty = { grid in
            selectedBrickID = nil
            selectedOrigin = LegoSceneGeometry.clampedOrigin(grid, for: selectedSize)
        }
        coord.onSelectBrick = { id in selectedBrickID = id }
        coord.onMove = onMove
        coord.onRotate = onRotate
        coord.onCommand = onCommand
        coord.controls = controls
        coord.capturingAction = capturingAction
        coord.onRebind = onRebind
        coord.selectedBrickID = selectedBrickID

        // When a rebind starts, take keyboard focus so the next press is captured.
        if capturingAction != nil, nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)
        }

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

        rebuildGizmo(coordinator: coord, in: nsView)
    }

    // MARK: - Scene construction

    private func buildBaseplate(in scene: SCNScene) {
        let span = CGFloat(LegoSceneGeometry.gridSize) + 0.4
        // Classic green baseplate with studs bright enough to read at camera
        // distance (mirrors the iOS v10 fix — gray-on-gray studs were invisible).
        let slab = SCNBox(width: span, height: 0.5, length: span, chamferRadius: 0.06)
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = NSColor(red: 0.23, green: 0.50, blue: 0.27, alpha: 1)
        mat.specular.contents = NSColor(white: 0.25, alpha: 1)
        mat.shininess = 0.10
        slab.materials = [mat]
        let slabNode = SCNNode(geometry: slab)
        slabNode.position = SCNVector3(0, LegoSceneGeometry.baseTopY - 0.25, 0)
        slabNode.name = "baseplate"
        scene.rootNode.addChildNode(slabNode)

        let studMat = SCNMaterial()
        studMat.lightingModel = .blinn
        studMat.diffuse.contents = NSColor(red: 0.38, green: 0.68, blue: 0.40, alpha: 1)
        studMat.specular.contents = NSColor(white: 0.55, alpha: 1)
        studMat.shininess = 0.30
        let half = CGFloat(LegoSceneGeometry.gridSize) / 2
        for y in 0..<LegoSceneGeometry.gridSize {
            for x in 0..<LegoSceneGeometry.gridSize {
                let stud = SCNCylinder(radius: BrickConst.studRadius, height: BrickConst.studHeight)
                stud.materials = [studMat]
                let node = SCNNode(geometry: stud)
                // Children of slabNode: y is RELATIVE to the slab's center (0.5
                // thick → top face at +0.25). The old baseTopY-based y buried
                // every stud inside the slab geometry.
                node.position = SCNVector3(CGFloat(x) + 0.5 - half,
                                           0.25 + BrickConst.studHeight / 2,
                                           CGFloat(y) + 0.5 - half)
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
        key.shadowColor = NSColor(white: 0, alpha: 0.32)
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
        mat.diffuse.contents = brick.color.nsColor
        mat.specular.contents = NSColor(white: 0.5, alpha: 1)
        mat.shininess = 0.28
        mat.transparency = opacity
        mat.isDoubleSided = true        // so the hollow interior reads from below
        if selected { mat.emission.contents = NSColor(calibratedWhite: 0.34, alpha: 1) }

        let parent = SCNNode()
        // Use the rotated footprint so a turned brick still lands on whole studs;
        // the body is modeled at the catalog size and spun about Y.
        let center = LegoSceneGeometry.footprintCenter(origin: brick.origin,
                                                       wide: brick.footprintWide,
                                                       deep: brick.footprintDeep)
        parent.position = SCNVector3(center.x,
                                     LegoSceneGeometry.centerY(layer: brick.layer, kind: kind),
                                     center.z)
        parent.eulerAngles = SCNVector3(0, -Double(brick.rotationQuarters) * (Double.pi / 2), 0)
        parent.opacity = opacity

        // Hollow body: closed top + perimeter walls (open underside) + anti-stud tubes.
        for node in makeHollowBody(width: w, depth: d, height: height, kind: kind,
                                   studsWide: brick.size.studsWide, studsDeep: brick.size.studsDeep,
                                   material: mat) {
            parent.addChildNode(node)
        }

        let studMat = SCNMaterial()
        studMat.lightingModel = .blinn
        studMat.diffuse.contents = brick.color.nsColor
        studMat.specular.contents = NSColor(white: 0.55, alpha: 1)
        studMat.shininess = 0.3
        if selected { studMat.emission.contents = NSColor(calibratedWhite: 0.34, alpha: 1) }
        let sw = brick.size.studsWide
        let sd = brick.size.studsDeep
        for j in 0..<sd {
            for i in 0..<sw {
                let stud = SCNCylinder(radius: BrickConst.studRadius, height: BrickConst.studHeight)
                stud.materials = [studMat]
                let node = SCNNode(geometry: stud)
                let lx = CGFloat(i) - CGFloat(sw - 1) / 2
                let lz = CGFloat(j) - CGFloat(sd - 1) / 2
                node.position = SCNVector3(lx, height / 2 + BrickConst.studHeight / 2, lz)
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
        slabNode.position = SCNVector3(0, height / 2 - slabT / 2, 0)
        nodes.append(slabNode)

        // Perimeter walls (full height, leaving the bottom open).
        func wall(_ ww: CGFloat, _ dd: CGFloat, x: CGFloat, z: CGFloat) -> SCNNode {
            let b = SCNBox(width: ww, height: height, length: dd, chamferRadius: 0)
            b.materials = [material]
            let n = SCNNode(geometry: b)
            n.position = SCNVector3(x, 0, z)
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
                    n.position = SCNVector3(CGFloat(i) - CGFloat(sw) / 2,
                                            -slabT / 2,
                                            CGFloat(j) - CGFloat(sd) / 2)
                    nodes.append(n)
                }
            }
        }
        return nodes
    }

    // MARK: - Gizmo

    private func rebuildGizmo(coordinator coord: Coordinator, in view: SCNView) {
        let root = coord.gizmoRoot
        for child in root.childNodes { child.removeFromParentNode() }

        guard let id = coord.selectedBrickID,
              let brick = document.bricks.first(where: { $0.id == id }) else {
            root.isHidden = true
            return
        }
        root.isHidden = false

        let kind = brick.size.elementKind
        let center = LegoSceneGeometry.footprintCenter(origin: brick.origin,
                                                       wide: brick.footprintWide,
                                                       deep: brick.footprintDeep)
        let topY = LegoSceneGeometry.centerY(layer: brick.layer, kind: kind) + LegoSceneGeometry.height(of: kind) / 2
        root.position = SCNVector3(center.x, topY + 0.2, center.z)

        root.addChildNode(makeArrow(axis: .x, color: NSColor(coord.axisColors.x)))
        root.addChildNode(makeArrow(axis: .y, color: NSColor(coord.axisColors.y)))
        root.addChildNode(makeArrow(axis: .z, color: NSColor(coord.axisColors.z)))
    }

    private func makeArrow(axis: GizmoAxis, color: NSColor) -> SCNNode {
        let group = SCNNode()
        let mat = SCNMaterial()
        mat.lightingModel = .constant         // unlit so colors read true at any angle
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.readsFromDepthBuffer = false      // draw over bricks so it's always grabbable
        mat.writesToDepthBuffer = false

        let shaft = SCNCylinder(radius: GizmoConst.shaftRadius, height: GizmoConst.shaftLength)
        shaft.materials = [mat]
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position = SCNVector3(0, GizmoConst.shaftLength / 2, 0)
        shaftNode.name = "gizmo-\(axis.rawValue)"
        shaftNode.renderingOrder = 1000

        let tip = SCNCone(topRadius: 0, bottomRadius: GizmoConst.tipRadius, height: GizmoConst.tipLength)
        tip.materials = [mat]
        let tipNode = SCNNode(geometry: tip)
        tipNode.position = SCNVector3(0, GizmoConst.shaftLength + GizmoConst.tipLength / 2, 0)
        tipNode.name = "gizmo-\(axis.rawValue)"
        tipNode.renderingOrder = 1000

        group.addChildNode(shaftNode)
        group.addChildNode(tipNode)

        // Arrows are modeled along +Y; rotate into the requested world axis.
        switch axis {
        case .y: break
        case .x: group.eulerAngles = SCNVector3(0, 0, -Double.pi / 2)   // +Y -> +X
        case .z: group.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)    // +Y -> +Z
        }
        return group
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        let bricksRoot = SCNNode()
        let ghostRoot = SCNNode()
        let gizmoRoot = SCNNode()

        var document = LegoBuildDocument()
        var axisColors: GizmoAxisColors = .classic
        var selectedBrickID: UUID?

        var renderedDocument: LegoBuildDocument?
        var renderedSelection: UUID??
        var renderedGhost: GhostKey?

        var controls: BrickControls = .defaults
        var capturingAction: BrickControlAction?

        var onPickEmpty: ((LegoGridPoint) -> Void)?
        var onSelectBrick: ((UUID?) -> Void)?
        var onMove: ((UUID, Int, Int, Int) -> Void)?
        var onRotate: ((UUID, Int) -> Void)?
        var onCommand: ((BrickControlAction) -> Void)?
        var onRebind: ((BrickControlAction, Int) -> Void)?

        // MARK: Click → select brick / move ghost
        func handleClick(at point: NSPoint, in view: SCNView) {
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

        // MARK: Keyboard nudge (arrow keys)
        /// Returns true if the key was consumed (rebound or acted on a brick).
        func handleKeyDown(keyCode: Int) -> Bool {
            // Rebind mode: the next key press is captured for the pending action.
            if let action = capturingAction {
                onRebind?(action, keyCode)
                return true
            }
            guard let action = controls.action(for: keyCode) else {
                return false
            }
            switch controls.effect(of: action) {
            case .placeBrick, .undo, .redo:
                onCommand?(action)
            case .move(let dx, let dy, let dLayer):
                guard let id = selectedBrickID else { return false }
                onMove?(id, dx, dy, dLayer)
            case .rotate(let quarters):
                guard let id = selectedBrickID else { return false }
                onRotate?(id, quarters)
            }
            return true
        }

        // MARK: Gizmo drag
        private var drag: GizmoDrag?

        /// Returns true if a gizmo handle was grabbed (camera orbit suppressed).
        func beginGizmoDrag(at point: NSPoint, in view: SCNView) -> Bool {
            guard let id = selectedBrickID else { return false }
            let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            guard let axis = hits.lazy.compactMap({ Self.gizmoAxis(for: $0.node) }).first else { return false }

            let origin = gizmoRoot.presentation.position
            let stepVec: SCNVector3
            switch axis {
            case .x: stepVec = SCNVector3(GizmoConst.studStep, 0, 0)
            case .y: stepVec = SCNVector3(0, GizmoConst.layerStep, 0)
            case .z: stepVec = SCNVector3(0, 0, GizmoConst.studStep)
            }
            let a = view.projectPoint(origin)
            let b = view.projectPoint(SCNVector3(origin.x + stepVec.x, origin.y + stepVec.y, origin.z + stepVec.z))
            let dirX = CGFloat(b.x - a.x), dirY = CGFloat(b.y - a.y)
            let pixelsPerStep = (dirX * dirX + dirY * dirY).squareRoot()
            guard pixelsPerStep > 0.5 else { return true }   // axis points at camera; ignore drag but keep orbit off

            drag = GizmoDrag(id: id, axis: axis, startPoint: point,
                             dirUnit: CGPoint(x: dirX / pixelsPerStep, y: dirY / pixelsPerStep),
                             pixelsPerStep: pixelsPerStep, emittedSteps: 0)
            return true
        }

        func updateGizmoDrag(to point: NSPoint) {
            guard let d = drag else { return }
            let dxPix = CGFloat(point.x - d.startPoint.x)
            let dyPix = CGFloat(point.y - d.startPoint.y)
            let projected = dxPix * d.dirUnit.x + dyPix * d.dirUnit.y
            let target = Int((projected / d.pixelsPerStep).rounded())
            let delta = target - d.emittedSteps
            guard delta != 0 else { return }
            drag?.emittedSteps = target
            switch d.axis {
            case .x: onMove?(d.id, delta, 0, 0)
            case .y: onMove?(d.id, 0, 0, delta)
            case .z: onMove?(d.id, 0, delta, 0)
            }
        }

        func endGizmoDrag() { drag = nil }
        var isDraggingGizmo: Bool { drag != nil }

        // MARK: Node → identity helpers
        static func brickID(for node: SCNNode) -> UUID? {
            var n: SCNNode? = node
            while let cur = n {
                if let name = cur.name, let id = UUID(uuidString: name) { return id }
                n = cur.parent
            }
            return nil
        }

        static func gizmoAxis(for node: SCNNode) -> GizmoAxis? {
            var n: SCNNode? = node
            while let cur = n {
                if let name = cur.name, name.hasPrefix("gizmo-") {
                    return GizmoAxis(rawValue: String(name.dropFirst("gizmo-".count)))
                }
                n = cur.parent
            }
            return nil
        }
    }

    struct GizmoDrag {
        let id: UUID
        let axis: GizmoAxis
        let startPoint: NSPoint
        let dirUnit: CGPoint
        let pixelsPerStep: CGFloat
        var emittedSteps: Int
    }

    struct GhostKey: Equatable {
        let origin: LegoGridPoint
        let size: LegoBrickSize
        let color: LegoBrickColor
        let layer: Int
    }
}

// MARK: - Mouse + keyboard plumbing

/// Splits input three ways: a drag that starts on a gizmo arrow moves the brick,
/// any other drag orbits the camera, and a clean click selects a brick (or moves
/// the placement ghost). Arrow keys nudge the selected brick.
@MainActor
private final class ClickableLegoSCNView: SCNView {
    weak var coordinator: LegoSceneView.Coordinator?
    private var mouseDownPoint: NSPoint?
    private var movedFar = false
    private var grabbedGizmo = false
    private static let dragThresholdSquared: CGFloat = 64

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        mouseDownPoint = p
        movedFar = false
        grabbedGizmo = coordinator?.beginGizmoDrag(at: p, in: self) ?? false
        if !grabbedGizmo { super.mouseDown(with: event) }   // let the camera controller start
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let down = mouseDownPoint {
            let dx = p.x - down.x, dy = p.y - down.y
            if (dx * dx + dy * dy) > Self.dragThresholdSquared { movedFar = true }
        }
        if grabbedGizmo {
            coordinator?.updateGizmoDrag(to: p)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        defer { mouseDownPoint = nil; grabbedGizmo = false; movedFar = false }
        if grabbedGizmo {
            coordinator?.endGizmoDrag()
            return
        }
        super.mouseUp(with: event)
        if !movedFar { coordinator?.handleClick(at: p, in: self) }
    }

    override func keyDown(with event: NSEvent) {
        if coordinator?.handleKeyDown(keyCode: Int(event.keyCode)) == true { return }
        super.keyDown(with: event)
    }
}
