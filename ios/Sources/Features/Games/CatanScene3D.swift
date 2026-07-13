import SceneKit
import UIKit

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). SceneKit scene builder.
//
// Turns CatanGame state into a cozy low-poly 3D world. Follows the house SceneKit conventions
// (see ChessSceneKitBoardView / LegoBuilder3DView): .blinn materials with low shininess + dark
// specular, a warm three-light rig, primitives with chamfered edges, separate root nodes per
// layer so a placement doesn't churn the static board. Geometry/coords come from
// CatanSceneGeometry; colors from the active CatanTheme.
//
// Layers (children of `root`, which the view adds to scene.rootNode):
//   waterRoot   sea disc + sandy rim         (rebuilt only on theme change)
//   boardRoot   hex tiles + emblems + tokens (rebuilt only when the tile layout changes)
//   roadsRoot / buildingsRoot / robberRoot   (rebuilt on any game-state change)
//   markersRoot glowing legal-move targets   (rebuilt whenever legal targets change)
final class CatanScene3D {
    var theme: CatanTheme
    var pieceStyle: CatanPieceStyle
    var playerColors: [CatanRGB]
    let board = CatanBoard.standard

    let root = SCNNode()
    private let waterRoot = SCNNode()
    private let boardRoot = SCNNode()
    private let roadsRoot = SCNNode()
    private let buildingsRoot = SCNNode()
    private let robberRoot = SCNNode()
    let markersRoot = SCNNode()

    private var renderedTiles: [CatanTile] = []
    private var renderedThemeID: String = ""
    private var renderedBuildings: [Int: CatanBuildingKind] = [:]
    private var renderedRoads: Set<Int> = []
    private var robberNode: SCNNode?
    private var renderedRobberHex: Int = -1
    var reduceMotion = false

    private let G = CatanSceneGeometry.self

    init(theme: CatanTheme, pieceStyle: CatanPieceStyle, playerColors: [CatanRGB]) {
        self.theme = theme
        self.pieceStyle = pieceStyle
        self.playerColors = playerColors
        for n in [waterRoot, boardRoot, roadsRoot, buildingsRoot, robberRoot, markersRoot] {
            root.addChildNode(n)
        }
    }

    // MARK: Public sync

    /// Rebuild everything from scratch (used on new game / theme / piece-style change and by the
    /// offscreen snapshot harness). Cheap enough for a 19-hex board.
    func fullSync(game: CatanGame) {
        buildWater()
        buildBoard(game: game)
        renderedTiles = game.tiles
        renderedThemeID = theme.id
        robberNode?.removeFromParentNode(); robberNode = nil; renderedRobberHex = -1
        syncPieces(game: game, animate: false)
        clearMarkers()
    }

    /// Light-touch update after a move: rebuild water/board only if theme or layout changed, then
    /// refresh the dynamic pieces, popping anything newly placed and hopping the robber.
    func sync(game: CatanGame) {
        if theme.id != renderedThemeID { buildWater(); renderedThemeID = theme.id }
        if game.tiles != renderedTiles { buildBoard(game: game); renderedTiles = game.tiles }
        syncPieces(game: game, animate: true)
    }

    private func syncPieces(game: CatanGame, animate: Bool) {
        var roads = Set<Int>()
        rebuild(roadsRoot) { root in
            for (edge, owner) in game.roads {
                let node = makeRoad(edge: edge, owner: owner)
                if animate && !renderedRoads.contains(edge) { pop(node) }
                root.addChildNode(node)
                roads.insert(edge)
            }
        }
        renderedRoads = roads

        var buildings: [Int: CatanBuildingKind] = [:]
        rebuild(buildingsRoot) { root in
            for (vertex, b) in game.buildings {
                let node = makeBuilding(vertex: vertex, building: b)
                if animate && renderedBuildings[vertex] != b.kind { pop(node) }   // new or upgraded
                root.addChildNode(node)
                buildings[vertex] = b.kind
            }
        }
        renderedBuildings = buildings

        syncRobber(hex: game.robberHex, animate: animate)
    }

    private func syncRobber(hex: Int, animate: Bool) {
        let dest = G.world(board.hexCenters[hex], y: G.topY)
        if robberNode == nil {
            let n = makeRobber(hex: hex)
            robberRoot.addChildNode(n)
            robberNode = n
            renderedRobberHex = hex
            return
        }
        guard let node = robberNode, hex != renderedRobberHex else { return }
        renderedRobberHex = hex
        if !animate || reduceMotion {
            node.position = dest
        } else {
            let up = SCNAction.moveBy(x: 0, y: 0.55, z: 0, duration: 0.15); up.timingMode = .easeOut
            let over = SCNAction.move(to: dest, duration: 0.26); over.timingMode = .easeInEaseOut
            node.runAction(.sequence([up, over]))
        }
    }

    private func pop(_ node: SCNNode) {
        guard !reduceMotion else { return }
        node.scale = SCNVector3(0.01, 0.01, 0.01)
        let grow = SCNAction.scale(to: 1.12, duration: 0.16); grow.timingMode = .easeOut
        let settle = SCNAction.scale(to: 1.0, duration: 0.09); settle.timingMode = .easeInEaseOut
        node.runAction(.sequence([grow, settle]))
    }

    func setMarkers(vertices: [Int], edges: [Int], hexes: [Int], accent: CatanRGB) {
        rebuild(markersRoot) { root in
            for v in vertices { root.addChildNode(makeVertexMarker(v, color: accent)) }
            for e in edges { root.addChildNode(makeEdgeMarker(e, color: accent)) }
            for h in hexes { root.addChildNode(makeHexMarker(h)) }
        }
    }
    func clearMarkers() { rebuild(markersRoot) { _ in } }

    private func rebuild(_ node: SCNNode, _ body: (SCNNode) -> Void) {
        for c in node.childNodes { c.removeFromParentNode() }
        body(node)
    }

    // MARK: Lights + camera (shared with the offscreen snapshot harness)

    /// Idempotent: clears any previously-installed Catan lights first, so re-calling on a theme
    /// change swaps the rig instead of stacking a second one (which would wash the scene out).
    func installLights(in scene: SCNScene) {
        scene.rootNode.childNodes.filter { $0.name == "catan.light" }.forEach { $0.removeFromParentNode() }

        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color = UIColor.white
        ambient.intensity = 430 * theme.ambientScale
        let an = SCNNode(); an.light = ambient; an.name = "catan.light"; scene.rootNode.addChildNode(an)

        let key = SCNLight(); key.type = .directional
        key.color = theme.lightTint.uiColor
        key.intensity = 820 * theme.keyScale
        key.castsShadow = true
        key.shadowSampleCount = 16
        key.shadowRadius = 4
        key.shadowColor = UIColor(white: 0, alpha: 0.30)
        let kn = SCNNode(); kn.light = key; kn.name = "catan.light"
        kn.position = SCNVector3(6, 15, 8)
        kn.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(kn)

        let fill = SCNLight(); fill.type = .omni
        fill.color = theme.lightTint.uiColor
        fill.intensity = 210 * theme.ambientScale
        let fn = SCNNode(); fn.light = fill; fn.name = "catan.light"; fn.position = SCNVector3(-7, 8, -6)
        scene.rootNode.addChildNode(fn)
    }

    func makeCameraNode() -> SCNNode {
        let cam = SCNCamera()
        cam.fieldOfView = 44
        cam.zNear = 0.1
        cam.zFar = 400
        let radius = Float(G.boardWorldRadius(board))
        let node = SCNNode()
        node.camera = cam
        // Above + in front, framed to fit the island with a little margin.
        node.position = SCNVector3(0, radius * 1.55, radius * 1.7)
        node.look(at: SCNVector3(0, 0, 0))
        return node
    }

    // MARK: Materials

    private func solid(_ rgb: CatanRGB, shininess: CGFloat = 0.12, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = rgb.uiColor
        m.specular.contents = UIColor(white: 0.22, alpha: 1)
        m.shininess = shininess
        m.locksAmbientWithDiffuse = true
        if glow && theme.isNight { m.emission.contents = rgb.adjusted(0.15).uiColor }
        return m
    }
    private func unlit(_ rgb: CatanRGB, alpha: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = rgb.uiColor
        m.transparency = alpha
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        return m
    }
    private func color(_ owner: Int) -> CatanRGB { playerColors[owner % max(1, playerColors.count)] }

    // MARK: Water + rim

    private func buildWater() {
        rebuild(waterRoot) { root in
            let R = CGFloat(G.boardWorldRadius(board))
            let sea = SCNCylinder(radius: R + 2.6, height: 0.5)
            sea.radialSegmentCount = 64
            sea.materials = [solid(theme.water, shininess: 0.06)]
            let seaNode = SCNNode(geometry: sea)
            seaNode.position = SCNVector3(0, -0.28, 0)   // top just under the tiles
            seaNode.castsShadow = false
            root.addChildNode(seaNode)

            let shore = SCNCylinder(radius: R + 0.55, height: 0.5)
            shore.radialSegmentCount = 64
            shore.materials = [solid(theme.rim, shininess: 0.05)]
            let shoreNode = SCNNode(geometry: shore)
            shoreNode.position = SCNVector3(0, -0.12, 0)
            root.addChildNode(shoreNode)
        }
    }

    // MARK: Board (hexes + emblems + tokens)

    private func buildBoard(game: CatanGame) {
        rebuild(boardRoot) { root in
            for i in board.hexes.indices {
                let tile = game.tiles[i]
                root.addChildNode(makeHex(i, tile: tile))
                let center = board.hexCenters[i]
                let base = G.world(center, y: G.topY)
                if let emblem = makeEmblem(for: tile.resource) {
                    emblem.position = base
                    root.addChildNode(emblem)
                }
                if let n = tile.number {
                    let token = makeToken(number: n)
                    token.position = SCNVector3(base.x, Float(G.topY) + 0.03, base.z)
                    root.addChildNode(token)
                }
            }
        }
    }

    private func makeHex(_ index: Int, tile: CatanTile) -> SCNNode {
        let corners = G.hexLocalPolygon(board, index)
        let path = UIBezierPath()
        if let first = corners.first {
            path.move(to: first)
            for c in corners.dropFirst() { path.addLine(to: c) }
            path.close()
        }
        let shape = SCNShape(path: path, extrusionDepth: G.hexThickness)
        let top = theme.fill(for: tile.resource)
        // SCNShape material order: [front (top after rotation), back, sides].
        shape.materials = [solid(top), solid(top.darkened), solid(top.darkened)]
        let node = SCNNode(geometry: shape)
        node.name = G.hexName(index)
        let c = board.hexCenters[index]
        node.position = SCNVector3(Float(c.x * G.scale), 0, Float(-c.y * G.scale))
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)   // lay flat, extrude upward
        node.castsShadow = true
        return node
    }

    private func makeToken(number: Int) -> SCNNode {
        let size: CGFloat = 0.66
        let plane = SCNPlane(width: size, height: size)
        let m = SCNMaterial()
        m.lightingModel = .constant                 // always legible, even at night
        m.diffuse.contents = tokenImage(number: number)
        m.isDoubleSided = true
        plane.materials = [m]
        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)   // lay flat, face up
        node.castsShadow = false
        return node
    }

    private func tokenImage(number: Int) -> UIImage {
        let px: CGFloat = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px))
        let hot = (number == 6 || number == 8)
        let face = theme.tokenFace.uiColor
        let ink = hot ? UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1) : UIColor(white: 0.12, alpha: 1)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let disc = CGRect(x: 8, y: 8, width: px - 16, height: px - 16)
            c.setFillColor(face.cgColor); c.fillEllipse(in: disc)
            c.setStrokeColor(UIColor(white: 0, alpha: 0.22).cgColor); c.setLineWidth(3); c.strokeEllipse(in: disc)
            let s = "\(number)"
            let font = UIFont.systemFont(ofSize: hot ? 62 : 54, weight: hot ? .heavy : .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (px - sz.width) / 2, y: (px - sz.height) / 2 - 6), withAttributes: attrs)
            // pips under the number (more pips = more likely)
            let pips = CatanGame.pips(for: number)
            let dotR: CGFloat = 4.5, gap: CGFloat = 5
            let totalW = CGFloat(pips) * (dotR * 2) + CGFloat(max(0, pips - 1)) * gap
            var x = (px - totalW) / 2
            let y = px - 30
            c.setFillColor(ink.cgColor)
            for _ in 0..<pips {
                c.fillEllipse(in: CGRect(x: x, y: y, width: dotR * 2, height: dotR * 2)); x += dotR * 2 + gap
            }
        }
    }

    // MARK: Emblems (little biome decorations)

    private func makeEmblem(for resource: CatanResource?) -> SCNNode? {
        let cluster = SCNNode()
        let offsets: [(Float, Float)] = [(-0.32, -0.18), (0.30, 0.10), (0.02, 0.36)]
        func place(_ n: SCNNode, _ o: (Float, Float), scale: Float = 1) {
            n.position = SCNVector3(o.0, 0, o.1); n.scale = SCNVector3(scale, scale, scale)
            cluster.addChildNode(n)
        }
        switch resource {
        case .lumber:
            for o in offsets { place(tree(), o, scale: Float.random(in: 0.9...1.1)) }
        case .wool:
            for o in offsets { place(sheep(), o) }
        case .grain:
            for o in offsets { place(wheat(), o) }
        case .brick:
            for o in offsets.prefix(2) { place(clayMound(), o) }
        case .ore:
            for o in offsets.prefix(2) { place(orePeak(), o) }
        case .none:
            place(cactus(), (0, 0))
        }
        return cluster.childNodes.isEmpty ? nil : cluster
    }

    private func tree() -> SCNNode {
        let n = SCNNode()
        let trunk = SCNCylinder(radius: 0.05, height: 0.18)
        trunk.materials = [solid(CatanRGB(r: 0.42, g: 0.28, b: 0.16))]
        let tn = SCNNode(geometry: trunk); tn.position = SCNVector3(0, 0.09, 0); n.addChildNode(tn)
        let leaves = SCNCone(topRadius: 0, bottomRadius: 0.2, height: 0.34)
        leaves.materials = [solid(CatanRGB(r: 0.20, g: 0.44, b: 0.26), glow: false)]
        let ln = SCNNode(geometry: leaves); ln.position = SCNVector3(0, 0.32, 0); n.addChildNode(ln)
        return n
    }
    private func sheep() -> SCNNode {
        let body = SCNSphere(radius: 0.13); body.materials = [solid(CatanRGB(r: 0.96, g: 0.96, b: 0.94))]
        let n = SCNNode(geometry: body); n.position = SCNVector3(0, 0.13, 0)
        let headGeo = SCNSphere(radius: 0.07); headGeo.materials = [solid(CatanRGB(r: 0.24, g: 0.22, b: 0.22))]
        let head = SCNNode(geometry: headGeo); head.position = SCNVector3(0.12, 0.03, 0); n.addChildNode(head)
        return n
    }
    private func wheat() -> SCNNode {
        let sheaf = SCNCone(topRadius: 0.02, bottomRadius: 0.12, height: 0.32)
        sheaf.materials = [solid(CatanRGB(r: 0.86, g: 0.70, b: 0.24))]
        let n = SCNNode(geometry: sheaf); n.position = SCNVector3(0, 0.16, 0)
        return n
    }
    private func clayMound() -> SCNNode {
        let box = SCNBox(width: 0.34, height: 0.14, length: 0.24, chamferRadius: 0.05)
        box.materials = [solid(CatanRGB(r: 0.72, g: 0.40, b: 0.26))]
        let n = SCNNode(geometry: box); n.position = SCNVector3(0, 0.07, 0)
        return n
    }
    private func orePeak() -> SCNNode {
        let p = SCNPyramid(width: 0.28, height: 0.34, length: 0.28)
        p.materials = [solid(CatanRGB(r: 0.52, g: 0.55, b: 0.62))]
        let n = SCNNode(geometry: p); n.position = SCNVector3(0, 0, 0)
        return n
    }
    private func cactus() -> SCNNode {
        let body = SCNCapsule(capRadius: 0.06, height: 0.34)
        body.materials = [solid(CatanRGB(r: 0.36, g: 0.52, b: 0.34))]
        let n = SCNNode(geometry: body); n.position = SCNVector3(0, 0.17, 0)
        return n
    }

    // MARK: Roads / buildings / robber

    private func makeRoad(edge: Int, owner: Int) -> SCNNode {
        let (mid, angleY, len) = G.edgeMidpointAndAngle(board, edge, y: G.topY + 0.02)
        let box = SCNBox(width: len * 0.84, height: 0.12, length: 0.15, chamferRadius: 0.05)
        box.materials = [solid(color(owner), glow: true)]
        let node = SCNNode(geometry: box)
        node.position = mid
        node.eulerAngles = SCNVector3(0, angleY, 0)
        return node
    }

    private func makeBuilding(vertex v: Int, building b: CatanBuilding) -> SCNNode {
        let parent = SCNNode()
        parent.position = G.world(board.vertices[v], y: G.topY)
        let rgb = color(b.owner)
        let isCity = (b.kind == .city)
        let roofColor = CatanRGB(r: 0.36, g: 0.20, b: 0.16)
        switch pieceStyle {
        case .cottage:
            let w: CGFloat = isCity ? 0.34 : 0.26
            let h: CGFloat = isCity ? 0.26 : 0.20
            let wall = SCNBox(width: w, height: h, length: w, chamferRadius: 0.03)
            wall.materials = [solid(rgb, glow: true)]
            let wallN = SCNNode(geometry: wall); wallN.position = SCNVector3(0, Float(h / 2), 0)
            parent.addChildNode(wallN)
            let roof = SCNPyramid(width: w * 1.18, height: isCity ? 0.22 : 0.16, length: w * 1.18)
            roof.materials = [solid(roofColor)]
            let roofN = SCNNode(geometry: roof); roofN.position = SCNVector3(0, Float(h), 0)
            parent.addChildNode(roofN)
            if isCity {
                let keep = SCNBox(width: 0.14, height: 0.30, length: 0.14, chamferRadius: 0.03)
                keep.materials = [solid(rgb.lightened, glow: true)]
                let keepN = SCNNode(geometry: keep); keepN.position = SCNVector3(0.12, 0.15, 0.12)
                parent.addChildNode(keepN)
            }
        case .blocky:
            let w: CGFloat = isCity ? 0.32 : 0.24
            let h: CGFloat = isCity ? 0.40 : 0.24
            let box = SCNBox(width: w, height: h, length: w, chamferRadius: 0.06)
            box.materials = [solid(rgb, glow: true)]
            let n = SCNNode(geometry: box); n.position = SCNVector3(0, Float(h / 2), 0)
            parent.addChildNode(n)
            if isCity {
                let cap = SCNBox(width: w * 0.6, height: 0.16, length: w * 0.6, chamferRadius: 0.05)
                cap.materials = [solid(rgb.lightened, glow: true)]
                let cn = SCNNode(geometry: cap); cn.position = SCNVector3(0, Float(h) + 0.08, 0)
                parent.addChildNode(cn)
            }
        }
        return parent
    }

    private func makeRobber(hex: Int) -> SCNNode {
        let parent = SCNNode()
        parent.name = "robber"
        parent.position = G.world(board.hexCenters[hex], y: G.topY)
        let dark = CatanRGB(r: 0.16, g: 0.16, b: 0.19)
        let body = SCNCone(topRadius: 0.06, bottomRadius: 0.17, height: 0.42)
        body.materials = [solid(dark)]
        let bn = SCNNode(geometry: body); bn.position = SCNVector3(0, 0.21, 0); parent.addChildNode(bn)
        let headGeo = SCNSphere(radius: 0.12); headGeo.materials = [solid(dark)]
        let head = SCNNode(geometry: headGeo); head.position = SCNVector3(0, 0.48, 0); parent.addChildNode(head)
        return parent
    }

    // MARK: Markers (legal targets — also the tap targets)

    private func makeVertexMarker(_ v: Int, color rgb: CatanRGB) -> SCNNode {
        let disc = SCNCylinder(radius: 0.15, height: 0.03)
        disc.materials = [unlit(rgb, alpha: 0.85)]
        let node = SCNNode(geometry: disc)
        node.name = G.vertexName(v)
        node.castsShadow = false
        node.position = G.world(board.vertices[v], y: G.topY + 0.05)
        if !reduceMotion {
            node.runAction(.repeatForever(.sequence([
                .scale(to: 1.25, duration: 0.6), .scale(to: 1.0, duration: 0.6)
            ])))
        }
        return node
    }
    private func makeEdgeMarker(_ e: Int, color rgb: CatanRGB) -> SCNNode {
        let (mid, angleY, len) = G.edgeMidpointAndAngle(board, e, y: G.topY + 0.05)
        let box = SCNBox(width: len * 0.7, height: 0.03, length: 0.1, chamferRadius: 0.02)
        box.materials = [unlit(rgb, alpha: 0.85)]
        let node = SCNNode(geometry: box)
        node.name = G.edgeName(e)
        node.castsShadow = false
        node.position = mid
        node.eulerAngles = SCNVector3(0, angleY, 0)
        return node
    }
    private func makeHexMarker(_ h: Int) -> SCNNode {
        let disc = SCNCylinder(radius: 0.7, height: 0.03)
        disc.radialSegmentCount = 6
        disc.materials = [unlit(CatanRGB(r: 0.1, g: 0.1, b: 0.12), alpha: 0.5)]
        let node = SCNNode(geometry: disc)
        node.name = G.hexName(h)
        node.castsShadow = false
        node.position = G.world(board.hexCenters[h], y: G.topY + 0.06)
        return node
    }
}
