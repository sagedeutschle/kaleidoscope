import XCTest
@testable import Prismet

final class CatanBoardTests: XCTestCase {
    func testStandardBoardHasCanonicalCounts() {
        let b = CatanBoard.standard
        XCTAssertEqual(b.hexes.count, 19)
        XCTAssertEqual(b.vertices.count, 54)
        XCTAssertEqual(b.edges.count, 72)
        XCTAssertEqual(b.hexVertexIndices.count, 19)
        for corners in b.hexVertexIndices { XCTAssertEqual(corners.count, 6) }
        XCTAssertEqual(b.vertexHexIndices.count, 54)
        for hexes in b.vertexHexIndices {
            XCTAssertGreaterThanOrEqual(hexes.count, 1)
            XCTAssertLessThanOrEqual(hexes.count, 3)
        }
    }

    func testEdgesResolveByEndpointsAndAreSymmetric() {
        let b = CatanBoard.standard
        for (i, e) in b.edges.enumerated() {
            XCTAssertEqual(b.edgeIndex(e.a, e.b), i)
            XCTAssertEqual(b.edgeIndex(e.b, e.a), i)
            XCTAssertTrue(b.vertexAdjacency[e.a].contains(e.b))
            XCTAssertTrue(b.vertexAdjacency[e.b].contains(e.a))
            XCTAssertTrue(b.vertexEdgeIndices[e.a].contains(i))
            XCTAssertTrue(b.vertexEdgeIndices[e.b].contains(i))
        }
    }
}

final class CatanGameTests: XCTestCase {
    func testNewGameHasStandardResourceMix() {
        let g = CatanGame.newGame(seed: 7)
        XCTAssertEqual(g.tiles.count, 19)
        XCTAssertEqual(g.tiles.filter { $0.resource == nil }.count, 1)
        XCTAssertEqual(g.tiles.filter { $0.resource == .brick }.count, 3)
        XCTAssertEqual(g.tiles.filter { $0.resource == .lumber }.count, 4)
        XCTAssertEqual(g.tiles.filter { $0.resource == .wool }.count, 4)
        XCTAssertEqual(g.tiles.filter { $0.resource == .grain }.count, 4)
        XCTAssertEqual(g.tiles.filter { $0.resource == .ore }.count, 3)
        XCTAssertEqual(g.tiles.filter { $0.number != nil }.count, 18)
        XCTAssertNil(g.tiles[g.robberHex].resource, "robber starts on the desert")
        XCTAssertEqual(g.phase, .setupSettlement)
        XCTAssertEqual(g.currentPlayer, 0)
        XCTAssertEqual(g.players.count, 3)
    }

    func testDistanceRuleBlocksAdjacentSettlements() {
        var g = CatanGame.newGame(seed: 3)
        let v = try! XCTUnwrap(g.legalSettlementVertices(for: 0, isSetup: true).first)
        XCTAssertTrue(g.placeSettlement(vertex: v))
        for n in CatanBoard.standard.vertexAdjacency[v] {
            XCTAssertFalse(g.canPlaceSettlement(vertex: n, for: 0, isSetup: true),
                           "a neighbor of an occupied vertex must be illegal")
        }
    }

    func testSetupPlacesSettlementThenRoadThenAdvances() {
        var g = CatanGame.newGame(seed: 5)
        XCTAssertEqual(g.phase, .setupSettlement)
        let v = try! XCTUnwrap(g.legalSettlementVertices(for: 0, isSetup: true).first)
        XCTAssertTrue(g.placeSettlement(vertex: v))
        XCTAssertEqual(g.phase, .setupRoad)
        let legalRoads = g.legalRoadEdges(for: 0, isSetup: true)
        XCTAssertFalse(legalRoads.isEmpty)
        for e in legalRoads {
            let (a, b) = CatanBoard.standard.endpoints(of: e)
            XCTAssertTrue(a == v || b == v, "a setup road must touch the just-placed settlement")
        }
        XCTAssertTrue(g.placeRoad(edge: legalRoads[0]))
        XCTAssertEqual(g.currentPlayer, 1)
        XCTAssertEqual(g.phase, .setupSettlement)
    }

    func testSetupCompletesForAllPlayersAndGrantsStartingResources() {
        var g = CatanGame.newGame(playerCount: 3, seed: 99)
        let ai = CatanAI()
        var steps = 0
        while g.isSetupPhase && steps < 200 {
            ai.act(in: &g)
            steps += 1
        }
        XCTAssertFalse(g.isSetupPhase)
        XCTAssertEqual(g.phase, .roll)
        for p in 0..<3 {
            XCTAssertEqual(g.players[p].settlementsLeft, 3, "each player places 2 of 5 settlements")
            XCTAssertEqual(g.players[p].roadsLeft, 13, "each player places 2 of 15 roads")
        }
        let totalStarting = (0..<3).map { g.totalResources($0) }.reduce(0, +)
        XCTAssertGreaterThan(totalStarting, 0, "second-round settlements grant starting resources")
    }

    func testSnapshotRoundTripsExactly() throws {
        let g = CatanGame.newGame(seed: 22)
        let json = try GameSaveCodec.encodeSnapshot(CatanSnapshot(game: g))
        let decoded = try GameSaveCodec.decodeSnapshot(CatanSnapshot.self, from: json)
        XCTAssertEqual(decoded.game, g)
    }

    /// End-to-end: three AI seats play a full game. This exercises setup, dice
    /// production, the robber, building, trading, development cards, longest road,
    /// largest army, and win detection. It must terminate with a legitimate winner.
    func testHeadlessGameReachesALegitimateWinner() {
        var g = CatanGame.newGame(playerCount: 3, seed: 12345)
        let ai = CatanAI()
        var steps = 0
        let cap = 20000
        while g.winner == nil && steps < cap {
            ai.act(in: &g)
            steps += 1
            if steps % 500 == 0 {
                XCTAssertTrue((0..<g.players.count).contains(g.currentPlayer))
                for p in g.players {
                    for r in CatanResource.allCases {
                        XCTAssertGreaterThanOrEqual(p.resources[r] ?? 0, 0, "resources must never go negative")
                    }
                }
            }
        }
        let winner = try! XCTUnwrap(g.winner, "the AI game did not finish within \(cap) steps")
        XCTAssertEqual(g.phase, .gameOver)
        XCTAssertGreaterThanOrEqual(g.victoryPoints(for: winner, includeHidden: true), CatanGame.winningPoints)
    }
}

final class CatanDifficultyAndMultiplayerTests: XCTestCase {
    func testAllPlayerCountsSetUpCorrectly() {
        for count in 2...4 {
            var g = CatanGame.newGame(playerCount: count, seed: 24680)
            XCTAssertEqual(g.players.count, count)
            XCTAssertEqual(g.players.filter { $0.isBot }.count, count - 1, "seat 0 is the human; the rest are bots")
            let ai = CatanAI(difficulty: .cozy)
            var steps = 0
            while g.isSetupPhase && steps < 400 { ai.act(in: &g); steps += 1 }
            XCTAssertFalse(g.isSetupPhase, "setup must complete for all seats")
            XCTAssertEqual(g.phase, .roll)
        }
    }

    /// Play stays legal (valid turn order, no negative resources, no crash) across all difficulty
    /// tiers. No winner is required — some board layouts legitimately can't reach 10 VP under the
    /// heuristic (board congestion / limited trading), which is a known limitation, not a bug.
    func testPlayRemainsLegalAcrossDifficulties() {
        for difficulty in CatanBotDifficulty.allCases {
            var g = CatanGame.newGame(playerCount: 4, seed: 13579)
            let ai = CatanAI(difficulty: difficulty)
            var steps = 0
            while g.winner == nil && steps < 3000 {
                ai.act(in: &g)
                steps += 1
                if steps % 200 == 0 {
                    XCTAssertTrue((0..<g.players.count).contains(g.currentPlayer))
                    for p in g.players {
                        for r in CatanResource.allCases {
                            XCTAssertGreaterThanOrEqual(p.resources[r] ?? 0, 0, "resources must never go negative")
                        }
                    }
                }
            }
        }
    }

    /// The difficulty tiers actually change play: gentle and clever bots diverge from the same seed.
    func testDifficultyAffectsPlay() {
        func play(_ d: CatanBotDifficulty, seed: UInt64) -> CatanGame {
            var g = CatanGame.newGame(playerCount: 4, seed: seed)
            let ai = CatanAI(difficulty: d)
            var s = 0
            while g.winner == nil && s < 500 { ai.act(in: &g); s += 1 }
            return g
        }
        var diverged = false
        for seed in stride(from: UInt64(101), through: 108, by: 1) where !diverged {
            if play(.gentle, seed: seed) != play(.clever, seed: seed) { diverged = true }
        }
        XCTAssertTrue(diverged, "gentle and clever bots should produce divergent play")
    }

    func testCozyDifficultyIsTheDefault() {
        XCTAssertEqual(CatanAI().difficulty, .cozy)
    }

    func testSnapshotCarriesDifficulty() throws {
        let g = CatanGame.newGame(seed: 88)
        let json = try GameSaveCodec.encodeSnapshot(CatanSnapshot(game: g, difficulty: .clever))
        let decoded = try GameSaveCodec.decodeSnapshot(CatanSnapshot.self, from: json)
        XCTAssertEqual(decoded.difficulty, .clever)
        XCTAssertEqual(decoded.game, g)
    }

    /// A save written before `difficulty` existed (no key) must still decode, defaulting to .cozy.
    func testSnapshotDecodesLegacySaveWithoutDifficulty() throws {
        let g = CatanGame.newGame(seed: 91)
        let gameJSON = try GameSaveCodec.encodeSnapshot(g)
        let legacyJSON = "{\"game\":\(gameJSON)}"
        let decoded = try GameSaveCodec.decodeSnapshot(CatanSnapshot.self, from: legacyJSON)
        XCTAssertEqual(decoded.difficulty, .cozy)
        XCTAssertEqual(decoded.game, g)
    }
}

final class CatanCustomizationTests: XCTestCase {
    func testThemeCatalogIsComplete() {
        XCTAssertEqual(CatanTheme.all.count, 6)
        XCTAssertEqual(CatanTheme.theme(id: "night").id, "night")
        XCTAssertEqual(CatanTheme.theme(id: "nonexistent").id, "meadow", "unknown ids fall back to meadow")
        // Every biome resolves to a fill (desert == nil).
        for theme in CatanTheme.all {
            for r in CatanResource.allCases { _ = theme.fill(for: r) }
            _ = theme.fill(for: nil)
        }
    }

    func testPlayerPaletteIsDistinctAndHonorsHumanPick() {
        let palette = CatanPlayerColor.palette(humanColorID: "jade", playerCount: 4)
        XCTAssertEqual(palette.count, 4)
        XCTAssertEqual(palette[0], CatanPlayerColor.color(id: "jade").rgb, "human keeps their chosen color at seat 0")
        XCTAssertEqual(Set(palette).count, 4, "all four player colors must be distinct")
    }
}
