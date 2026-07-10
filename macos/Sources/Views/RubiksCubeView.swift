import SwiftUI
import AppKit
@preconcurrency import SceneKit
import simd

// PRISM: RELEASE Agent-B 2026-06-27 — persisted session controls and undo.

// MARK: - Facet view

/// The Rubik's Cube facet: a SceneKit 3×3×3 cube you scramble and solve with
/// on-screen face buttons (drag-to-turn is a later-wave stretch). Tracks elapsed
/// time and move count, and celebrates a solve.
struct RubiksCubeView: View {
    @ObservedObject private var session: RubiksCubeSession

    private let accent = FacetRegistry.accent(for: "rubiks-cube")
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var fullscreenWindow: NSWindow?
    @FocusState private var isFocused: Bool

    init(session: RubiksCubeSession = RubiksCubeSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            RubiksSceneView(cube: session.cube, onDragTurn: { dragTurn($0) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) { solvedBanner }
            controls
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(action: handleKey)
        .onReceive(ticker) { _ in
            session.tick(by: 0.1)
        }
    }

    // MARK: Header

    private var header: some View {
        GameHeader(title: "Rubik's Cube", systemImage: "cube.transparent", accent: accent, subtitle: statusText) {
            HStack(spacing: 18) {
                StatBadge(label: "Time",
                          value: String(format: "%01d:%04.1f", Int(session.elapsed) / 60, session.elapsed.truncatingRemainder(dividingBy: 60)),
                          accent: accent)
                StatBadge(label: "Moves", value: "\(session.moveCount)", accent: accent)
                fullscreenButton
            }
        }
        .frame(maxWidth: 620)
    }

    private var fullscreenButton: some View {
        Button { presentFullscreenCubeWindow() } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityLabel("Fullscreen cube")
        }
        .buttonStyle(.plain)
    }

    private func presentFullscreenCubeWindow() {
        if let fullscreenWindow, fullscreenWindow.isVisible {
            fullscreenWindow.makeKeyAndOrderFront(nil)
            return
        }
        fullscreenWindow = nil
        var window: NSWindow!
        window = NSWindow(
            contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Rubik's Cube"
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentViewController = NSHostingController(
            rootView: RubiksFullscreenWindowContent(session: session, accent: accent) { [weak window] in
                window?.close()
            }
        )
        fullscreenWindow = window
        window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(nil)
    }

    private var statusText: String {
        if session.cube.isSolved && session.hasStarted { return "Solved!" }
        if !session.hasStarted { return "Scramble to begin." }
        return "Turn faces until every side is one colour."
    }

    @ViewBuilder
    private var solvedBanner: some View {
        if session.cube.isSolved && session.hasStarted {
            Text("Solved!")
                .font(.title2.bold())
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.green.gradient, in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 10)
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            Picker("Turn", selection: $session.direction) {
                ForEach(TurnDirection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .onChange(of: session.direction) { _, _ in
                session.saveNow()
            }

            HStack(spacing: 8) {
                ForEach(RubiksMove.baseMoves) { base in
                    Button(base.face.rawValue) { turn(base.face) }
                }
            }
            .buttonStyle(GlassButtonStyle())
            .font(.title3.monospaced().bold())

            HStack(spacing: 8) {
                ForEach(CubeSlice.allCases) { slice in
                    Button(slice.label) { turnSlice(slice) }
                }
                Text("middle slices")
                    .font(.caption2)
                    .foregroundStyle(PrismetDesign.ink3)
            }
            .buttonStyle(GlassButtonStyle())
            .font(.title3.monospaced().bold())

            HStack(spacing: 12) {
                Button {
                    scramble()
                } label: {
                    Label("Scramble", systemImage: "shuffle")
                }
                    .buttonStyle(AccentButtonStyle(accent: accent))
                Button {
                    undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(!session.canUndo)
                Button {
                    reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlassButtonStyle())
                Menu {
                    Button("Save") { session.saveNow() }
                    Button("Load") { session.reloadSavedState() }
                } label: {
                    Label("State", systemImage: "externaldrive")
                }
                .buttonStyle(GlassButtonStyle())
            }

            Text("Drag a sticker to turn its layer · drag the background to orbit · Arrows + WASD turn faces · M/E/S middle slices · picker sets CW / CCW / 180°")
                .font(.caption2)
                .foregroundStyle(PrismetDesign.ink3)
        }
    }

    // MARK: Actions

    /// Arrow keys + WASD both turn faces. Arrows map by on-screen position
    /// (↑ U · ↓ D · ← L · → R); WASD covers the side ring (W F · S B · A L · D R),
    /// so every face is reachable from the keyboard. The CW/CCW/180 picker chooses
    /// the turn direction, exactly like the on-screen face buttons.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let face: CubeFace?
        switch press.key {
        case .upArrow:    face = .U
        case .downArrow:  face = .D
        case .leftArrow:  face = .L
        case .rightArrow: face = .R
        default:
            switch press.characters.lowercased() {
            case "w": face = .F
            case "s": face = .B
            case "a": face = .L
            case "d": face = .R
            default:  face = nil
            }
        }
        guard let face else { return .ignored }
        turn(face)
        return .handled
    }

    private func turn(_ face: CubeFace) {
        withAnimation(.easeInOut(duration: 0.18)) {
            session.turn(face: face)
        }
    }

    /// A sticker drag from the scene, already resolved to a move. Routes
    /// through the session's normal turn path (undo/timer/persistence), and
    /// reflects the drag's direction in the CW/CCW picker.
    private func dragTurn(_ move: RubiksMove) {
        session.direction = move.quarters == 3 ? .counter : .clockwise
        session.turn(face: move.face)
    }

    private func turnSlice(_ slice: CubeSlice) {
        withAnimation(.easeInOut(duration: 0.18)) {
            session.turn(slice: slice)
        }
    }

    private func scramble() {
        withAnimation(.easeInOut(duration: 0.25)) {
            session.scramble()
        }
    }

    private func reset() {
        withAnimation(.easeInOut(duration: 0.25)) {
            session.reset()
        }
    }

    private func undo() {
        withAnimation(.easeInOut(duration: 0.18)) {
            session.undo()
        }
    }
}

private struct RubiksFullscreenWindowContent: View {
    @ObservedObject var session: RubiksCubeSession
    let accent: Color
    let close: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.052, blue: 0.070),
                    Color(red: 0.135, green: 0.095, blue: 0.180)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RubiksSceneView(cube: session.cube, onDragTurn: { dragTurn($0) })
                .padding(.top, 78)
                .padding(.bottom, 92)
                .padding(.horizontal, 18)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        close()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    .buttonStyle(GlassButtonStyle())

                    Spacer(minLength: 12)

                    StatBadge(label: "Time",
                              value: String(format: "%01d:%04.1f", Int(session.elapsed) / 60, session.elapsed.truncatingRemainder(dividingBy: 60)),
                              accent: accent)
                    StatBadge(label: "Moves", value: "\(session.moveCount)", accent: accent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer()

                HStack(spacing: 12) {
                    Button { undo() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(!session.canUndo)

                    Button { scramble() } label: {
                        Label("Scramble", systemImage: "shuffle")
                    }
                    .buttonStyle(AccentButtonStyle(accent: accent))

                    Button { reset() } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func dragTurn(_ move: RubiksMove) {
        session.direction = move.quarters == 3 ? .counter : .clockwise
        session.turn(face: move.face)
    }

    private func undo() {
        withAnimation(.easeInOut(duration: 0.18)) {
            session.undo()
        }
    }

    private func scramble() {
        withAnimation(.easeInOut(duration: 0.25)) {
            session.scramble()
        }
    }

    private func reset() {
        withAnimation(.easeInOut(duration: 0.25)) {
            session.reset()
        }
    }
}

// MARK: - SceneKit cube

/// Renders the cube as 26 persistent cubie nodes. Each cubie's stickers are
/// coloured by its solved "home" faces; on every state change the node's
/// transform animates to the model's current position/orientation, so a face
/// turn reads as a smooth layer rotation.
private struct RubiksSceneView: NSViewRepresentable {
    let cube: RubiksCube
    /// A drag on a sticker resolved to a face turn (mirrors the iOS cube-app
    /// interaction). The SwiftUI owner routes it through the session.
    var onDragTurn: ((RubiksMove) -> Void)? = nil

    private static let spacing: Float = 1.04

    /// Sticker colours indexed to match `RubiksCube.colourIndex(of:)`.
    /// 0:+x R(red) 1:-x L(orange) 2:+y U(white) 3:-y D(yellow) 4:+z F(green) 5:-z B(blue)
    private static let stickerColors: [NSColor] = [
        NSColor(srgbRed: 0.78, green: 0.16, blue: 0.18, alpha: 1),  // red
        NSColor(srgbRed: 0.95, green: 0.52, blue: 0.13, alpha: 1),  // orange
        NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1),  // white
        NSColor(srgbRed: 0.98, green: 0.85, blue: 0.18, alpha: 1),  // yellow
        NSColor(srgbRed: 0.16, green: 0.62, blue: 0.30, alpha: 1),  // green
        NSColor(srgbRed: 0.12, green: 0.36, blue: 0.78, alpha: 1)   // blue
    ]
    private static let plastic = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let coord = context.coordinator
        let view = SCNView(frame: .zero)
        let scene = SCNScene()
        view.scene = scene

        let cubeRoot = SCNNode()
        scene.rootNode.addChildNode(cubeRoot)
        coord.cubeRoot = cubeRoot

        for cubie in cube.cubies {
            let node = Self.makeCubieNode(home: cubie.home)
            node.simdTransform = Self.transform(for: cubie)
            cubeRoot.addChildNode(node)
            coord.nodes[Self.key(cubie.home)] = node
        }

        buildCamera(in: scene, view: view)
        buildLights(in: scene)

        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = NSColor(srgbRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)

        coord.renderedCube = cube
        coord.logicalCube = cube
        coord.scnView = view
        coord.onDragTurn = onDragTurn
        coord.installLayerDragRecognizer(on: view)

        return view
    }

    /// Mash-safe sync (mirrors the iOS v10 fix): recognize the update as face
    /// turns and play them sequentially on a pivot node; snap for anything
    /// bigger (scramble/reset/restore). The old overlapping SCNTransaction
    /// matrix-lerps skewed cubies when buttons were mashed.
    func updateNSView(_ nsView: SCNView, context: Context) {
        let coord = context.coordinator
        coord.onDragTurn = onDragTurn
        coord.consume(target: cube)
    }

    // MARK: Node construction

    static func key(_ home: CubeVec) -> String { "\(home.x),\(home.y),\(home.z)" }

    private static func makeCubieNode(home: CubeVec) -> SCNNode {
        let box = SCNBox(width: 0.95, height: 0.95, length: 0.95, chamferRadius: 0.08)
        // SCNBox material order: +Z (front), +X (right), -Z (back), -X (left), +Y (top), -Y (bottom).
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

    /// A face shows its sticker colour only if the cubie's home borders that
    /// direction; otherwise it is interior plastic.
    private static func material(forBodyDirection dir: CubeVec, home: CubeVec) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.specular.contents = NSColor(white: 0.4, alpha: 1)
        mat.shininess = 0.3
        if home.dot(dir) == 1 {
            mat.diffuse.contents = stickerColors[RubiksCube.colourIndex(of: dir)]
        } else {
            mat.diffuse.contents = plastic
        }
        return mat
    }

    static func transform(for cubie: RubiksCube.Cubie) -> simd_float4x4 {
        let m = cubie.orientation
        let s = spacing
        return simd_float4x4(
            SIMD4<Float>(Float(m.c0.x), Float(m.c0.y), Float(m.c0.z), 0),
            SIMD4<Float>(Float(m.c1.x), Float(m.c1.y), Float(m.c1.z), 0),
            SIMD4<Float>(Float(m.c2.x), Float(m.c2.y), Float(m.c2.z), 0),
            SIMD4<Float>(Float(cubie.position.x) * s, Float(cubie.position.y) * s, Float(cubie.position.z) * s, 1)
        )
    }

    private func buildCamera(in scene: SCNScene, view: SCNView) {
        let cam = SCNCamera()
        cam.fieldOfView = 32
        cam.zNear = 0.1
        cam.zFar = 100
        let node = SCNNode()
        node.camera = cam
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

    @MainActor
    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
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
        private let maxQueuedTurns = 6
        private static let turnDuration: TimeInterval = 0.14

        func consume(target: RubiksCube) {
            if target == logicalCube { return }
            if let moves = Self.movesReaching(target, from: logicalCube), queue.count + moves.count <= maxQueuedTurns {
                logicalCube = target
                queue.append(contentsOf: moves)
                pump()
            } else {
                snapEverything(to: target)
            }
        }

        private static func movesReaching(_ to: RubiksCube, from: RubiksCube) -> [RubiksMove]? {
            for m in RubiksMove.allCases where from.applying([m]) == to { return [m] }
            for m1 in RubiksMove.allCases {
                let mid = from.applying([m1])
                for m2 in RubiksMove.allCases where mid.applying([m2]) == to { return [m1, m2] }
            }
            return nil
        }

        private func pump() {
            guard !isTurning, !queue.isEmpty, let cubeRoot else { return }
            isTurning = true
            let move = queue.removeFirst()
            let before = renderedCube
            let after = before.applying([move])

            let axis = move.face.axis
            let layer = move.face.layer
            var affectedKeys: [String] = []
            for cubie in before.cubies {
                let coord = axis == 0 ? cubie.position.x : (axis == 1 ? cubie.position.y : cubie.position.z)
                if coord == layer { affectedKeys.append(RubiksSceneView.key(cubie.home)) }
            }

            let pivot = SCNNode()
            cubeRoot.addChildNode(pivot)
            activePivot = pivot
            for keyName in affectedKeys {
                guard let node = nodes[keyName] else { continue }
                let world = node.worldTransform
                node.removeFromParentNode()
                pivot.addChildNode(node)
                node.transform = pivot.convertTransform(world, from: nil)
            }

            let quarters = move.quarters
            let angle: CGFloat = quarters == 2 ? .pi : (quarters == 3 ? -.pi / 2 : .pi / 2)
            let axisVec = SCNVector3(axis == 0 ? 1 : 0, axis == 1 ? 1 : 0, axis == 2 ? 1 : 0)
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let duration = Self.turnDuration * (quarters == 2 ? 1.6 : 1.0)
            let action = SCNAction.rotate(by: angle, around: axisVec, duration: duration)
            action.timingMode = .easeInEaseOut

            if reduceMotion {
                pivot.simdRotation = simd_float4(Float(axisVec.x), Float(axisVec.y), Float(axisVec.z), Float(angle))
                dissolvePivot(pivot, settleTo: after, keys: affectedKeys)
                renderedCube = after
                isTurning = false
                pump()
            } else {
                pivot.runAction(action) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.dissolvePivot(pivot, settleTo: after, keys: affectedKeys)
                        self.renderedCube = after
                        self.isTurning = false
                        self.pump()
                    }
                }
            }
        }

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
            let byHome = Dictionary(uniqueKeysWithValues: state.cubies.map { (RubiksSceneView.key($0.home), $0) })
            for keyName in keys {
                if let node = nodes[keyName], let cubie = byHome[keyName] {
                    node.simdTransform = RubiksSceneView.transform(for: cubie)
                }
            }
        }

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
                nodes[RubiksSceneView.key(cubie.home)]?.simdTransform = RubiksSceneView.transform(for: cubie)
            }
        }

        // MARK: Drag a sticker to turn its layer

        private var dragHit: (key: String, normal: CubeVec, world: SCNVector3)?
        private var dragConsumed = false

        func installLayerDragRecognizer(on view: SCNView) {
            let pan = NSPanGestureRecognizer(target: self, action: #selector(handleLayerDrag(_:)))
            pan.delegate = self
            view.addGestureRecognizer(pan)
        }

        /// AppKit equivalent of UIKit's `require(toFail:)`: the camera's
        /// gestures must wait for the sticker-drag to decline (it declines
        /// instantly when the press starts on empty space).
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            guard let view = scnView else { return false }
            let point = gestureRecognizer.location(in: view)
            guard let hit = stickerHit(at: point, in: view) else { return false }
            dragHit = hit
            dragConsumed = false
            return true
        }

        @objc private func handleLayerDrag(_ recognizer: NSPanGestureRecognizer) {
            guard let view = scnView, let hit = dragHit, !dragConsumed else { return }
            guard recognizer.state == .changed || recognizer.state == .ended else { return }
            let translation = recognizer.translation(in: view)
            let distance = hypot(translation.x, translation.y)
            guard distance >= 18 else { return }
            dragConsumed = true
            if let move = resolveMove(hit: hit, drag: translation, in: view) {
                onDragTurn?(move)
            }
        }

        private func stickerHit(at point: CGPoint, in view: SCNView) -> (key: String, normal: CubeVec, world: SCNVector3)? {
            let options: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.closest.rawValue]
            guard let hit = view.hitTest(point, options: options).first else { return nil }
            guard let keyName = nodes.first(where: { $0.value === hit.node })?.key else { return nil }
            let n = hit.worldNormal
            let axisNormal: CubeVec
            if abs(n.x) >= abs(n.y), abs(n.x) >= abs(n.z) {
                axisNormal = CubeVec(n.x > 0 ? 1 : -1, 0, 0)
            } else if abs(n.y) >= abs(n.z) {
                axisNormal = CubeVec(0, n.y > 0 ? 1 : -1, 0)
            } else {
                axisNormal = CubeVec(0, 0, n.z > 0 ? 1 : -1)
            }
            return (keyName, axisNormal, hit.worldCoordinates)
        }

        private func resolveMove(hit: (key: String, normal: CubeVec, world: SCNVector3), drag: CGPoint, in view: SCNView) -> RubiksMove? {
            guard let cubie = logicalCube.cubies.first(where: { RubiksSceneView.key($0.home) == hit.key }) else { return nil }
            let p = cubie.position

            var best: (move: RubiksMove, score: CGFloat)?
            let dragLen = hypot(drag.x, drag.y)
            guard dragLen > 0 else { return nil }

            for axis in 0..<3 {
                let normalComponent = axis == 0 ? hit.normal.x : (axis == 1 ? hit.normal.y : hit.normal.z)
                if normalComponent != 0 { continue }
                let layerCoord = axis == 0 ? p.x : (axis == 1 ? p.y : p.z)
                guard abs(layerCoord) == 1 else { continue }
                guard let face = Self.face(axis: axis, layer: layerCoord) else { continue }

                for spin in [1, -1] {
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
                        best = (RubiksMove.move(face: face, quarters: spin == 1 ? 1 : 3), score)
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
}
