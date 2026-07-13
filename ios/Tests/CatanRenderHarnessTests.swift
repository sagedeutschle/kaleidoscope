import XCTest
import SceneKit
import Metal
@testable import Prismet

// Offscreen render harness for the 3D Catan board. Not a pass/fail correctness test — it renders
// the SceneKit scene to PNGs under ~/Library/Caches/Prismet-build/shots so the look can be
// reviewed without a physical device. Skips cleanly where Metal is unavailable.
final class CatanRenderHarnessTests: XCTestCase {
    func testRenderBoardScreenshots() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available in this environment")
        }

        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Caches/Prismet-build/shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // A settled mid-game: finish setup, then play a few turns so roads/houses/cities appear.
        var game = CatanGame.newGame(playerCount: 4, seed: 2026)
        let ai = CatanAI(difficulty: .cozy)
        var s = 0
        while game.isSetupPhase && s < 200 { ai.act(in: &game); s += 1 }
        var t = 0
        while game.winner == nil && t < 80 { ai.act(in: &game); t += 1 }

        let palette = CatanPlayerColor.palette(humanColorID: "lapis", playerCount: 4)

        for (themeID, style) in [("meadow", CatanPieceStyle.cottage),
                                 ("night", .cottage),
                                 ("candy", .blocky)] {
            let theme = CatanTheme.theme(id: themeID)
            let scene = SCNScene()
            let builder = CatanScene3D(theme: theme, pieceStyle: style, playerColors: palette)
            scene.rootNode.addChildNode(builder.root)
            builder.fullSync(game: game)
            // Show legal settlement + road markers so highlighting is visible in the shot.
            builder.setMarkers(vertices: Array(game.legalSettlementVertices(for: 0, isSetup: false).prefix(6)),
                               edges: Array(game.legalRoadEdges(for: 0, isSetup: false).prefix(6)),
                               hexes: [],
                               accent: CatanRGB(r: 0.98, g: 0.86, b: 0.30))
            builder.installLights(in: scene)
            let cam = builder.makeCameraNode()
            scene.rootNode.addChildNode(cam)
            scene.background.contents = theme.background.uiColor

            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            renderer.pointOfView = cam
            let img = renderer.snapshot(atTime: 0,
                                        with: CGSize(width: 1100, height: 850),
                                        antialiasingMode: .multisampling4X)
            let data = try XCTUnwrap(img.pngData(), "failed to encode PNG for \(themeID)")
            let url = dir.appendingPathComponent("catan-\(themeID).png")
            try data.write(to: url)
            print("SHOT \(url.path) \(data.count) bytes")
        }
    }
}
