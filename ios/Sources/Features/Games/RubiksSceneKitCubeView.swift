// PRISM: RELEASE Agent-Design(rubiks) 2026-07-03 — mash-bug fix + cube-app controls
import SceneKit
import SwiftUI
import UIKit

/// SceneKit cube with the interaction model used by the leading cube apps:
/// swipe a sticker to turn its layer, drag the background to orbit the camera.
///
/// Rendering contract (fixes the button-mash corruption): the old
/// implementation animated every cubie's `simdTransform` toward the new model
/// state with overlapping `SCNTransaction`s — matrix-LERPing a 90° rotation
/// skews the cubies, and mashing compounded the artifacts. Now the coordinator
/// keeps its own `renderedCube`, detects the applied move by diffing against
/// the incoming model, and plays turns SEQUENTIALLY: the affected layer is
/// re-parented onto a pivot node, rotated with a real rotation action, then
/// snapped exactly onto the model-derived transforms. Unrecognized jumps
/// (scramble/reset/restore) snap instantly with no interpolation.
struct RubiksSceneKitCubeView: UIViewRepresentable {
    let cube: RubiksCube
    /// A swipe on a sticker resolved to a face turn. The SwiftUI owner applies
    /// it to the model (haptics/undo/persistence run through the same path as
    /// the buttons); the coordinator then animates it via the normal diff.
    var onDragTurn: ((RubiksMove) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let coordinator = context.coordinator
        let view = SCNView(frame: .zero)
        let scene = SCNScene()
        view.scene = scene

        let cubeRoot = SCNNode()
        scene.rootNode.addChildNode(cubeRoot)
        coordinator.cubeRoot = cubeRoot

        for cubie in cube.cubies {
            let node = Self.makeCubieNode(home: cubie.home)
            node.simdTransform = RubiksSceneGeometry.transform(for: cubie)
            cubeRoot.addChildNode(node)
            coordinator.nodes[RubiksSceneGeometry.key(cubie.home)] = node
        }
        coordinator.renderedCube = cube
        coordinator.logicalCube = cube

        buildCamera(in: scene, view: view)
        buildLights(in: scene)

        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isJitteringEnabled = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)

        coordinator.scnView = view
        coordinator.onDragTurn = onDragTurn
        coordinator.installLayerDragRecognizer(on: view)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onDragTurn = onDragTurn
        coordinator.consume(target: cube)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var scnView: SCNView?
        var cubeRoot: SCNNode?
        var nodes: [String: SCNNode] = [:]
        var onDragTurn: ((RubiksMove) -> Void)?

        /// State currently shown on screen (tail of any running animation).
        var renderedCube = RubiksCube()
        /// State after every queued turn — diff target for incoming updates.
        var logicalCube = RubiksCube()

        private var queue: [RubiksMove] = []
        private var isTurning = false
        private var activePivot: SCNNode?
        /// Mash guard: beyond this, turns land instantly instead of queueing
        /// an ever-longer animation backlog.
        private let maxQueuedTurns = 6
        private static let turnDuration: TimeInterval = 0.14

        // MARK: Model sync

        func consume(target: RubiksCube) {
            if target == logicalCube { return }
            // Recognize the update as 1-2 face turns → animate them in order.
            if let moves = Self.movesReaching(target, from: logicalCube), queue.count + moves.count <= maxQueuedTurns {
                logicalCube = target
                queue.append(contentsOf: moves)
                pump()
            } else {
                // Scramble / reset / restore / mash overflow: snap, no lerp.
                snapEverything(to: target)
            }
        }

        /// Finds a sequence of at most two face turns taking `from` to `to`.
        private static func movesReaching(_ to: RubiksCube, from: RubiksCube) -> [RubiksMove]? {
            for m in RubiksMove.allCases where from.applying([m]) == to {
                return [m]
            }
            for m1 in RubiksMove.allCases {
                let mid = from.applying([m1])
                for m2 in RubiksMove.allCases where mid.applying([m2]) == to {
                    return [m1, m2]
                }
            }
            return nil
        }

        private func pump() {
            guard !isTurning, !queue.isEmpty, let cubeRoot, let scnView else { return }
            isTurning = true
            let move = queue.removeFirst()
            let before = renderedCube
            let after = before.applying([move])

            let axis = move.face.axis
            let layer = move.face.layer
            var affectedKeys: [String] = []
            for cubie in before.cubies {
                let coord = axis == 0 ? cubie.position.x : (axis == 1 ? cubie.position.y : cubie.position.z)
                if coord == layer { affectedKeys.append(RubiksSceneGeometry.key(cubie.home)) }
            }

            let pivot = SCNNode()
            cubeRoot.addChildNode(pivot)
            activePivot = pivot
            for key in affectedKeys {
                guard let node = nodes[key] else { continue }
                let world = node.worldTransform
                node.removeFromParentNode()
                pivot.addChildNode(node)
                node.transform = pivot.convertTransform(world, from: nil)
            }

            // Model turns are right-handed quarter turns about the +axis;
            // quarters 3 plays as the equivalent −90° for the short path.
            let quarters = move.quarters
            let angle: CGFloat = quarters == 2 ? .pi : (quarters == 3 ? -.pi / 2 : .pi / 2)
            let axisVec = SCNVector3(axis == 0 ? 1 : 0, axis == 1 ? 1 : 0, axis == 2 ? 1 : 0)
            let duration = Self.turnDuration * (quarters == 2 ? 1.6 : 1.0)
            let action = SCNAction.rotate(by: angle, around: axisVec, duration: duration)
            action.timingMode = UIAccessibility.isReduceMotionEnabled ? .linear : .easeInEaseOut

            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            let finish: () -> Void = { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.dissolvePivot(pivot, settleTo: after, keys: affectedKeys)
                    self.renderedCube = after
                    self.isTurning = false
                    self.pump()
                }
            }
            if reduceMotion {
                pivot.simdRotation = simd_float4(Float(axisVec.x), Float(axisVec.y), Float(axisVec.z), Float(angle))
                finish()
            } else {
                pivot.runAction(action, completionHandler: finish)
            }
            _ = scnView
        }

        /// Re-parents the pivot's children back to the cube root and snaps the
        /// affected cubies onto the exact model-derived transforms.
        private func dissolvePivot(_ pivot: SCNNode, settleTo state: RubiksCube, keys: [String]) {
            guard let cubeRoot else { return }
            for node in pivot.childNodes {
                let world = node.worldTransform
                node.removeFromParentNode()
                cubeRoot.addChildNode(node)
                node.transform = cubeRoot.convertTransform(world, from: nil)
            }
            pivot.removeFromParentNode()
            if activePivot === pivot { activePivot = nil }
            let byHome = Dictionary(uniqueKeysWithValues: state.cubies.map { (RubiksSceneGeometry.key($0.home), $0) })
            for key in keys {
                if let node = nodes[key], let cubie = byHome[key] {
                    node.simdTransform = RubiksSceneGeometry.transform(for: cubie)
                }
            }
        }

        /// Hard sync: cancel any running turn and place every cubie exactly.
        private func snapEverything(to target: RubiksCube) {
            if let pivot = activePivot {
                pivot.removeAllActions()
                dissolvePivot(pivot, settleTo: renderedCube, keys: [])
            }
            queue.removeAll()
            isTurning = false
            renderedCube = target
            logicalCube = target
            for cubie in target.cubies {
                nodes[RubiksSceneGeometry.key(cubie.home)]?.simdTransform = RubiksSceneGeometry.transform(for: cubie)
            }
        }

        // MARK: Swipe-a-sticker layer turns

        private var dragStart: CGPoint = .zero
        private var dragHit: (key: String, normal: CubeVec, world: SCNVector3)?
        private var dragConsumed = false

        func installLayerDragRecognizer(on view: SCNView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleLayerDrag(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            view.addGestureRecognizer(pan)
            // Camera gestures only engage when the sticker-drag declines
            // (i.e. the touch started on empty space).
            for recognizer in view.gestureRecognizers ?? [] where recognizer !== pan {
                recognizer.require(toFail: pan)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = scnView else { return false }
            let point = gestureRecognizer.location(in: view)
            guard let hit = stickerHit(at: point, in: view) else { return false }
            dragStart = point
            dragHit = hit
            dragConsumed = false
            return true
        }

        @objc private func handleLayerDrag(_ recognizer: UIPanGestureRecognizer) {
            guard let view = scnView, let hit = dragHit, !dragConsumed else { return }
            guard recognizer.state == .changed || recognizer.state == .ended else { return }
            let translation = recognizer.translation(in: view)
            let distance = hypot(translation.x, translation.y)
            guard distance >= 22 else { return }
            dragConsumed = true
            if let move = resolveMove(hit: hit, drag: translation, in: view) {
                onDragTurn?(move)
            }
        }

        /// Hit-test that resolves to (cubie key, outward sticker normal, world point).
        private func stickerHit(at point: CGPoint, in view: SCNView) -> (key: String, normal: CubeVec, world: SCNVector3)? {
            let options: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.closest.rawValue]
            guard let hit = view.hitTest(point, options: options).first else { return nil }
            guard let key = nodes.first(where: { $0.value === hit.node })?.key else { return nil }
            let n = hit.worldNormal
            let axisNormal: CubeVec
            if abs(n.x) >= abs(n.y), abs(n.x) >= abs(n.z) {
                axisNormal = CubeVec(n.x > 0 ? 1 : -1, 0, 0)
            } else if abs(n.y) >= abs(n.z) {
                axisNormal = CubeVec(0, n.y > 0 ? 1 : -1, 0)
            } else {
                axisNormal = CubeVec(0, 0, n.z > 0 ? 1 : -1)
            }
            return (key, axisNormal, hit.worldCoordinates)
        }

        /// Maps a drag on a sticker to the face turn whose motion best matches
        /// the on-screen drag direction. Candidates: ±90° about each axis
        /// perpendicular to the sticker normal whose layer is an outer face.
        private func resolveMove(hit: (key: String, normal: CubeVec, world: SCNVector3), drag: CGPoint, in view: SCNView) -> RubiksMove? {
            guard let cubie = logicalCube.cubies.first(where: { RubiksSceneGeometry.key($0.home) == hit.key }) else { return nil }
            let p = cubie.position

            var best: (move: RubiksMove, score: CGFloat)?
            let dragLen = hypot(drag.x, drag.y)
            guard dragLen > 0 else { return nil }

            for axis in 0..<3 {
                let normalComponent = axis == 0 ? hit.normal.x : (axis == 1 ? hit.normal.y : hit.normal.z)
                if normalComponent != 0 { continue }   // can't turn about the sticker's own normal
                let layerCoord = axis == 0 ? p.x : (axis == 1 ? p.y : p.z)
                guard abs(layerCoord) == 1 else { continue }   // middle slice: no face move
                guard let face = Self.face(axis: axis, layer: layerCoord) else { continue }

                for spin in [1, -1] {
                    // Screen-space motion of the grabbed point under this turn:
                    // v = ω × r with ω = spin·axis, projected through the camera.
                    let axisF = SIMD3<Float>(axis == 0 ? 1 : 0, axis == 1 ? 1 : 0, axis == 2 ? 1 : 0) * Float(spin)
                    let r = SIMD3<Float>(Float(hit.world.x), Float(hit.world.y), Float(hit.world.z))
                    let v = simd_cross(axisF, r)
                    let p0 = view.projectPoint(hit.world)
                    let p1 = view.projectPoint(SCNVector3(r.x + v.x * 0.3, r.y + v.y * 0.3, r.z + v.z * 0.3))
                    let screen = CGPoint(x: CGFloat(p1.x - p0.x), y: CGFloat(p1.y - p0.y))
                    let screenLen = hypot(screen.x, screen.y)
                    guard screenLen > 0.001 else { continue }
                    let score = (screen.x * drag.x + screen.y * drag.y) / (screenLen * dragLen)
                    if score > (best?.score ?? 0.45) {
                        let quarters = spin == 1 ? 1 : 3
                        best = (RubiksMove.move(face: face, quarters: quarters), score)
                    }
                }
            }
            return best?.move
        }

        private static func face(axis: Int, layer: Int) -> CubeFace? {
            switch (axis, layer) {
            case (0, 1): return .R
            case (0, -1): return .L
            case (1, 1): return .U
            case (1, -1): return .D
            case (2, 1): return .F
            case (2, -1): return .B
            default: return nil
            }
        }
    }

    // MARK: - Scene construction (unchanged)

    private static func makeCubieNode(home: CubeVec) -> SCNNode {
        let box = SCNBox(width: 0.95, height: 0.95, length: 0.95, chamferRadius: 0.08)
        box.materials = [
            material(forBodyDirection: CubeVec(0, 0, 1), home: home),
            material(forBodyDirection: CubeVec(1, 0, 0), home: home),
            material(forBodyDirection: CubeVec(0, 0, -1), home: home),
            material(forBodyDirection: CubeVec(-1, 0, 0), home: home),
            material(forBodyDirection: CubeVec(0, 1, 0), home: home),
            material(forBodyDirection: CubeVec(0, -1, 0), home: home)
        ]
        return SCNNode(geometry: box)
    }

    private static func material(forBodyDirection direction: CubeVec, home: CubeVec) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.specular.contents = UIColor(white: 0.4, alpha: 1)
        material.shininess = 0.3
        if home.dot(direction) == 1 {
            material.diffuse.contents = stickerColors[RubiksCube.colourIndex(of: direction)]
        } else {
            material.diffuse.contents = plastic
        }
        return material
    }

    private func buildCamera(in scene: SCNScene, view: SCNView) {
        let camera = SCNCamera()
        camera.fieldOfView = 32
        camera.zNear = 0.1
        camera.zFar = 100

        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(5.2, 5.2, 6.6)
        node.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(node)
        view.pointOfView = node
    }

    private func buildLights(in scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 520
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 760
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(6, 9, 7)
        keyNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 240
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-7, -4, -6)
        scene.rootNode.addChildNode(fillNode)
    }

    private static let stickerColors: [UIColor] = [
        UIColor(red: 0.78, green: 0.16, blue: 0.18, alpha: 1),
        UIColor(red: 0.95, green: 0.52, blue: 0.13, alpha: 1),
        UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1),
        UIColor(red: 0.98, green: 0.85, blue: 0.18, alpha: 1),
        UIColor(red: 0.16, green: 0.62, blue: 0.30, alpha: 1),
        UIColor(red: 0.12, green: 0.36, blue: 0.78, alpha: 1)
    ]

    private static let plastic = UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
}
