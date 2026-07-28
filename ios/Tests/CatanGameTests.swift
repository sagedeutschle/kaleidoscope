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
