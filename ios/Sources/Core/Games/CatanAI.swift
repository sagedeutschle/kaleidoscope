import Foundation

// PRISM: RELEASE Agent-Design/Claude 2026-07-12 — Catan bot.
//
// A pragmatic heuristic opponent, not a search bot. `act(in:)` fully resolves
// whatever the current (bot) player faces — a setup placement, or a whole turn
// (roll → resolve robber → greedy build → end turn). The view calls it whenever the
// current player is a bot and loops until it is the human's turn or the game is over.

/// How hard the bots play. `.cozy` reproduces the original balanced heuristic exactly; `.gentle`
/// is deliberately softer (kinder robber, no bank-trading, timid dev-buys) so new players can win;
/// `.clever` is sharper (hunts the leader with the robber, trades and buys development earlier).
enum CatanBotDifficulty: String, Codable, CaseIterable, Identifiable {
    case gentle, cozy, clever
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gentle: return "Gentle"
        case .cozy: return "Cozy"
        case .clever: return "Clever"
        }
    }
    var blurb: String {
        switch self {
        case .gentle: return "Kind and beatable — great for learning."
        case .cozy: return "A friendly, balanced game."
        case .clever: return "Sharp opponents who play to win."
        }
    }
}

struct CatanAI {
    /// Difficulty tier. `.cozy` is the original balanced heuristic and leaves behavior unchanged.
    var difficulty: CatanBotDifficulty = .cozy

    /// Resolve the current bot player's entire obligation, mutating the game in place.
    func act(in game: inout CatanGame) {
        guard game.winner == nil else { return }
        switch game.phase {
        case .setupSettlement, .setupRoad:
            doSetup(&game)
        case .roll:
            doTurn(&game)
        case .moveRobber:
            moveRobber(&game)
        case .build:
            buildPhase(&game)
            if game.phase == .build { game.endTurn() }
        case .gameOver:
            break
        }
    }

    // MARK: Setup

    private func doSetup(_ game: inout CatanGame) {
        let p = game.currentPlayer
        if game.phase == .setupSettlement {
            let spots = game.legalSettlementVertices(for: p, isSetup: true)
            if let v = spots.max(by: { pipSum(game, $0) < pipSum(game, $1) }) {
                game.placeSettlement(vertex: v)
            } else if let v = spots.first {
                game.placeSettlement(vertex: v)
            }
        }
        if game.phase == .setupRoad {
            let edges = game.legalRoadEdges(for: p, isSetup: true)
            if let e = edges.max(by: { setupRoadScore(game, $0) < setupRoadScore(game, $1) }) {
                game.placeRoad(edge: e)
            } else if let e = edges.first {
                game.placeRoad(edge: e)
            }
        }
    }

    private func setupRoadScore(_ game: CatanGame, _ e: Int) -> Int {
        let (a, b) = game.board.endpoints(of: e)
        let far = (a == game.lastSetupVertex) ? b : a
        return pipSum(game, far)
    }

    // MARK: Turn

    private func doTurn(_ game: inout CatanGame) {
        game.roll()
        if game.phase == .moveRobber { moveRobber(&game) }
        buildPhase(&game)
        if game.phase == .build { game.endTurn() }
    }

    private func buildPhase(_ game: inout CatanGame) {
        // Dev-card appetite by difficulty: clever buys earlier, gentle hoards resources longer.
        let devThreshold = (difficulty == .clever) ? 4 : (difficulty == .gentle ? 7 : 5)
        var guardCount = 0
        while game.phase == .build && game.winner == nil && guardCount < 40 {
            guardCount += 1
            let p = game.currentPlayer

            // 1) Upgrade to a city (best producer).
            if game.canAfford(CatanGame.cityCost, player: p), let v = bestCityVertex(game, p) {
                game.placeCity(vertex: v); continue
            }
            // 2) Build a settlement (best open, connected spot).
            if game.canAfford(CatanGame.settlementCost, player: p), let v = bestSettlementVertex(game, p) {
                game.placeSettlement(vertex: v); continue
            }
            // 3) Play a Knight when it helps (largest army, or robber sitting on us).
            if !game.players[p].playedDevThisTurn, game.players[p].devCards.contains(.knight),
               shouldPlayKnight(game, p) {
                game.playKnight()
                if game.phase == .moveRobber { moveRobber(&game) }
                continue
            }
            // 4) Extend the network toward a new settlement spot.
            if game.canAfford(CatanGame.roadCost, player: p), let e = bestExpansionRoad(game, p) {
                game.placeRoad(edge: e); continue
            }
            // 5) Buy a development card when flush.
            if game.canAfford(CatanGame.devCardCost, player: p), game.totalResources(p) >= devThreshold {
                game.buyDevCard(); continue
            }
            // 6) Trade 4:1 toward an affordable build, else stop. Gentle bots never bank-trade.
            if difficulty != .gentle, tryTradeTowardGoal(&game, p) { continue }
            break
        }
    }

    // MARK: Robber

    private func moveRobber(_ game: inout CatanGame) {
        guard game.phase == .moveRobber else { return }
        let me = game.currentPlayer
        let hexes = game.legalRobberHexes()
        // Clever bots hunt whoever is ahead; gentle bots go easy on the human (player 0).
        let leader = game.players.indices.max(by: { game.publicScore(for: $0) < game.publicScore(for: $1) })
        func score(_ h: Int) -> Int {
            var s = 0
            var touchesSelf = false
            let pips = CatanGame.pips(for: game.tiles[h].number)
            for v in game.board.hexVertexIndices[h] {
                if let b = game.buildings[v] {
                    if b.owner == me { touchesSelf = true }
                    else {
                        var w = (b.kind == .city ? 2 : 1) * pips
                        if difficulty == .clever, b.owner == leader { w += 3 * pips }
                        if difficulty == .gentle, b.owner == 0 { w -= 6 * pips }
                        s += w
                    }
                }
            }
            if touchesSelf { s -= 100 }
            return s
        }
        if let best = hexes.max(by: { score($0) < score($1) }) {
            game.moveRobber(to: best)
        } else if let any = hexes.first {
            game.moveRobber(to: any)
        }
    }

    private func shouldPlayKnight(_ game: CatanGame, _ p: Int) -> Bool {
        // Robber currently on one of our hexes → clear it.
        for v in game.board.hexVertexIndices[game.robberHex] {
            if let b = game.buildings[v], b.owner == p { return true }
        }
        if difficulty == .gentle { return false }   // gentle bots use knights only defensively
        // Playing would grab (or hold) Largest Army.
        let myKnights = game.players[p].knightsPlayed + 1
        let others = game.players.indices.filter { $0 != p }.map { game.players[$0].knightsPlayed }.max() ?? 0
        return myKnights >= 3 && myKnights > others
    }

    // MARK: Scoring helpers

    private func pipSum(_ game: CatanGame, _ v: Int) -> Int {
        var s = 0
        for h in game.board.vertexHexIndices[v] { s += CatanGame.pips(for: game.tiles[h].number) }
        return s
    }

    private func bestCityVertex(_ game: CatanGame, _ p: Int) -> Int? {
        game.legalCityVertices(for: p).max(by: { pipSum(game, $0) < pipSum(game, $1) })
    }

    private func bestSettlementVertex(_ game: CatanGame, _ p: Int) -> Int? {
        game.legalSettlementVertices(for: p, isSetup: false).max(by: { pipSum(game, $0) < pipSum(game, $1) })
    }

    /// Prefer a road whose far endpoint could later host a settlement (open + honors
    /// the distance rule), scored by that endpoint's production.
    private func bestExpansionRoad(_ game: CatanGame, _ p: Int) -> Int? {
        let edges = game.legalRoadEdges(for: p, isSetup: false)
        guard !edges.isEmpty else { return nil }
        func score(_ e: Int) -> Int {
            let (a, b) = game.board.endpoints(of: e)
            var best = 0
            for v in [a, b] {
                guard game.buildings[v] == nil else { continue }
                let blocked = game.board.vertexAdjacency[v].contains { game.buildings[$0] != nil }
                if !blocked { best = max(best, pipSum(game, v)) }
            }
            return best
        }
        let scored = edges.map { ($0, score($0)) }
        // Only lay a road if it opens something worthwhile.
        if let top = scored.max(by: { $0.1 < $1.1 }), top.1 > 0 { return top.0 }
        return nil
    }

    private func tryTradeTowardGoal(_ game: inout CatanGame, _ p: Int) -> Bool {
        // Toward a city if we own a settlement to upgrade; else toward a settlement.
        if bestCityVertex(game, p) != nil, tryTrade(&game, p, toward: CatanGame.cityCost) { return true }
        if !game.legalSettlementVertices(for: p, isSetup: false).isEmpty,
           tryTrade(&game, p, toward: CatanGame.settlementCost) { return true }
        return false
    }

    private func tryTrade(_ game: inout CatanGame, _ p: Int, toward cost: [CatanResource: Int]) -> Bool {
        guard let short = cost.keys.first(where: { (game.players[p].resources[$0] ?? 0) < (cost[$0] ?? 0) }) else {
            return false
        }
        for give in CatanResource.allCases where give != short {
            let have = game.players[p].resources[give] ?? 0
            let keepForCost = cost[give] ?? 0
            if have >= 4 && have - 4 >= keepForCost {
                return game.bankTrade(give: give, get: short)
            }
        }
        return false
    }
}
