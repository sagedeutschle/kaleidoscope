import Foundation

// PRISM: RELEASE Agent-Design/Claude 2026-07-12 — Catan (Settlers) rules engine.
//
// Pure-Swift, value-type, deterministic (all randomness flows through a stored
// SeededGenerator so saves resume exactly). The board topology is fixed and lives in
// CatanBoard; only per-game layout + play state is modeled and encoded here.
//
// Scope for this first playable version (documented simplifications, all winnable):
//   • 3 players — you + two bots.
//   • Standard 19-hex board, random resource/number layout each game.
//   • Snake-draft setup, dice production, robber on 7 (+ automatic over-7 discards),
//     roads/settlements/cities, Longest Road (+2) and Largest Army (+2), win at 10 VP.
//   • Development cards: Knight and Victory Point (the three progress cards are a
//     follow-up). Trading is bank 4:1 (ports and player-to-player trades are a
//     follow-up). Robber steals from the richest adjacent opponent; discards drop
//     from the largest stacks.

struct CatanTile: Codable, Equatable, Hashable {
    var resource: CatanResource?   // nil == desert
    var number: Int?               // nil == desert
}

struct CatanDiceRoll: Codable, Equatable, Hashable {
    var a: Int
    var b: Int
    var total: Int { a + b }
}

enum CatanBuildingKind: String, Codable, Equatable, Hashable {
    case settlement, city
}

struct CatanBuilding: Codable, Equatable, Hashable {
    var owner: Int
    var kind: CatanBuildingKind
}

enum CatanDevCard: String, Codable, Equatable, Hashable, CaseIterable {
    case knight, victoryPoint
}

enum CatanPhase: String, Codable, Equatable {
    case setupSettlement, setupRoad, roll, build, moveRobber, gameOver
}

struct CatanPlayer: Codable, Equatable {
    var index: Int
    var name: String
    var isBot: Bool
    var resources: [CatanResource: Int]
    var settlementsLeft: Int
    var citiesLeft: Int
    var roadsLeft: Int
    var devCards: [CatanDevCard]        // playable (held from a previous turn)
    var newDevCards: [CatanDevCard]     // bought this turn — not yet playable
    var knightsPlayed: Int
    var playedDevThisTurn: Bool

    init(index: Int, name: String, isBot: Bool) {
        self.index = index
        self.name = name
        self.isBot = isBot
        self.resources = Dictionary(uniqueKeysWithValues: CatanResource.allCases.map { ($0, 0) })
        self.settlementsLeft = 5
        self.citiesLeft = 4
        self.roadsLeft = 15
        self.devCards = []
        self.newDevCards = []
        self.knightsPlayed = 0
        self.playedDevThisTurn = false
    }

    var totalResourceCount: Int { resources.values.reduce(0, +) }
    var victoryPointDevCards: Int {
        devCards.filter { $0 == .victoryPoint }.count + newDevCards.filter { $0 == .victoryPoint }.count
    }
}

struct CatanGame: Codable, Equatable {
    // Costs (public so the UI can show/enable actions).
    static let roadCost: [CatanResource: Int] = [.brick: 1, .lumber: 1]
    static let settlementCost: [CatanResource: Int] = [.brick: 1, .lumber: 1, .wool: 1, .grain: 1]
    static let cityCost: [CatanResource: Int] = [.grain: 2, .ore: 3]
    static let devCardCost: [CatanResource: Int] = [.wool: 1, .grain: 1, .ore: 1]
    static let winningPoints = 10

    private(set) var tiles: [CatanTile]
    private(set) var robberHex: Int
    private(set) var buildings: [Int: CatanBuilding]   // vertex index -> building
    private(set) var roads: [Int: Int]                 // edge index -> owner
    private(set) var players: [CatanPlayer]
    private(set) var currentPlayer: Int
    private(set) var phase: CatanPhase
    private(set) var lastRoll: CatanDiceRoll?
    private(set) var setupOrder: [Int]
    private(set) var setupStep: Int
    private(set) var lastSetupVertex: Int?
    private(set) var devDeck: [CatanDevCard]
    private(set) var winner: Int?
    private(set) var longestRoadOwner: Int?
    private(set) var largestArmyOwner: Int?
    private(set) var log: [String]
    private var rng: SeededGenerator

    // MARK: New game

    static func newGame(playerCount: Int = 3, seed: UInt64, humanName: String = "You") -> CatanGame {
        var rng = SeededGenerator(seed: seed)

        var producing: [CatanResource] = []
        producing += Array(repeating: CatanResource.brick, count: 3)
        producing += Array(repeating: CatanResource.lumber, count: 4)
        producing += Array(repeating: CatanResource.wool, count: 4)
        producing += Array(repeating: CatanResource.grain, count: 4)
        producing += Array(repeating: CatanResource.ore, count: 3)
        var bag: [CatanResource?] = producing.map { Optional($0) }
        bag.append(nil)  // desert
        catanShuffle(&bag, using: &rng)

        var numberTokens = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
        catanShuffle(&numberTokens, using: &rng)

        var tiles: [CatanTile] = []
        var robber = 0
        var tokenCursor = 0
        for (i, res) in bag.enumerated() {
            if res == nil {
                tiles.append(CatanTile(resource: nil, number: nil))
                robber = i
            } else {
                tiles.append(CatanTile(resource: res, number: numberTokens[tokenCursor]))
                tokenCursor += 1
            }
        }

        let count = max(2, min(4, playerCount))
        let names = [humanName, "Amber", "Jade", "Garnet"]
        var players: [CatanPlayer] = []
        for i in 0..<count {
            players.append(CatanPlayer(index: i, name: names[i], isBot: i != 0))
        }

        var deck: [CatanDevCard] = Array(repeating: .knight, count: 14) + Array(repeating: .victoryPoint, count: 5)
        catanShuffle(&deck, using: &rng)

        let order = Array(0..<count) + Array((0..<count).reversed())

        return CatanGame(
            tiles: tiles,
            robberHex: robber,
            buildings: [:],
            roads: [:],
            players: players,
            currentPlayer: order.first ?? 0,
            phase: .setupSettlement,
            lastRoll: nil,
            setupOrder: order,
            setupStep: 0,
            lastSetupVertex: nil,
            devDeck: deck,
            winner: nil,
            longestRoadOwner: nil,
            largestArmyOwner: nil,
            log: ["Place your first settlement"],
            rng: rng
        )
    }

    // MARK: Derived state

    var board: CatanBoard { CatanBoard.standard }
    var currentPlayerIsBot: Bool { players[currentPlayer].isBot }
    var isSetupPhase: Bool { phase == .setupSettlement || phase == .setupRoad }
    var isSecondSetupRound: Bool { setupStep >= players.count }

    func totalResources(_ p: Int) -> Int { players[p].totalResourceCount }

    func victoryPoints(for p: Int, includeHidden: Bool) -> Int {
        var vp = 0
        for (_, b) in buildings where b.owner == p { vp += (b.kind == .city ? 2 : 1) }
        if longestRoadOwner == p { vp += 2 }
        if largestArmyOwner == p { vp += 2 }
        if includeHidden { vp += players[p].victoryPointDevCards }
        return vp
    }

    /// The publicly visible score (hidden VP cards excluded) — for the scoreboard.
    func publicScore(for p: Int) -> Int { victoryPoints(for: p, includeHidden: false) }

    static func pips(for number: Int?) -> Int {
        guard let n = number else { return 0 }
        switch n {
        case 2, 12: return 1
        case 3, 11: return 2
        case 4, 10: return 3
        case 5, 9: return 4
        case 6, 8: return 5
        default: return 0
        }
    }

    func canAfford(_ cost: [CatanResource: Int], player p: Int) -> Bool {
        for (r, n) in cost where (players[p].resources[r] ?? 0) < n { return false }
        return true
    }

    // MARK: Placement legality

    func canPlaceSettlement(vertex v: Int, for p: Int, isSetup: Bool) -> Bool {
        guard players[p].settlementsLeft > 0 else { return false }
        guard buildings[v] == nil else { return false }
        for n in board.vertexAdjacency[v] where buildings[n] != nil { return false }  // distance rule
        if isSetup { return true }
        for e in board.vertexEdgeIndices[v] where roads[e] == p { return true }        // road-connected
        return false
    }

    func canPlaceCity(vertex v: Int, for p: Int) -> Bool {
        guard players[p].citiesLeft > 0 else { return false }
        guard let b = buildings[v] else { return false }
        return b.owner == p && b.kind == .settlement
    }

    func canPlaceRoad(edge e: Int, for p: Int, isSetup: Bool) -> Bool {
        guard players[p].roadsLeft > 0 else { return false }
        guard roads[e] == nil else { return false }
        let (a, b) = board.endpoints(of: e)
        if isSetup {
            guard let sv = lastSetupVertex else { return false }
            return a == sv || b == sv
        }
        return roadConnects(vertex: a, for: p) || roadConnects(vertex: b, for: p)
    }

    private func roadConnects(vertex v: Int, for p: Int) -> Bool {
        if let bld = buildings[v] { return bld.owner == p }  // opponent building breaks connection
        for e in board.vertexEdgeIndices[v] where roads[e] == p { return true }
        return false
    }

    func legalSettlementVertices(for p: Int, isSetup: Bool) -> [Int] {
        board.vertices.indices.filter { canPlaceSettlement(vertex: $0, for: p, isSetup: isSetup) }
    }
    func legalCityVertices(for p: Int) -> [Int] {
        board.vertices.indices.filter { canPlaceCity(vertex: $0, for: p) }
    }
    func legalRoadEdges(for p: Int, isSetup: Bool) -> [Int] {
        board.edges.indices.filter { canPlaceRoad(edge: $0, for: p, isSetup: isSetup) }
    }
    func legalRobberHexes() -> [Int] {
        tiles.indices.filter { $0 != robberHex }
    }

    // MARK: Actions

    @discardableResult
    mutating func roll() -> Bool {
        guard phase == .roll, winner == nil else { return false }
        let d1 = rng.nextInt(upperBound: 6) + 1
        let d2 = rng.nextInt(upperBound: 6) + 1
        lastRoll = CatanDiceRoll(a: d1, b: d2)
        let total = d1 + d2
        addLog("\(players[currentPlayer].name) rolled \(total)")
        if total == 7 {
            applyDiscards()
            phase = .moveRobber
        } else {
            produce(total)
            phase = .build
        }
        return true
    }

    @discardableResult
    mutating func placeSettlement(vertex v: Int) -> Bool {
        let p = currentPlayer
        switch phase {
        case .setupSettlement:
            guard canPlaceSettlement(vertex: v, for: p, isSetup: true) else { return false }
            buildings[v] = CatanBuilding(owner: p, kind: .settlement)
            players[p].settlementsLeft -= 1
            lastSetupVertex = v
            if isSecondSetupRound { grantSetupResources(vertex: v, to: p) }
            addLog("\(players[p].name) placed a settlement")
            phase = .setupRoad
            return true
        case .build:
            guard canPlaceSettlement(vertex: v, for: p, isSetup: false),
                  canAfford(Self.settlementCost, player: p) else { return false }
            pay(Self.settlementCost, player: p)
            buildings[v] = CatanBuilding(owner: p, kind: .settlement)
            players[p].settlementsLeft -= 1
            addLog("\(players[p].name) built a settlement")
            recomputeLongestRoad()
            checkWin()
            return true
        default:
            return false
        }
    }

    @discardableResult
    mutating func placeCity(vertex v: Int) -> Bool {
        guard phase == .build else { return false }
        let p = currentPlayer
        guard canPlaceCity(vertex: v, for: p), canAfford(Self.cityCost, player: p) else { return false }
        pay(Self.cityCost, player: p)
        buildings[v] = CatanBuilding(owner: p, kind: .city)
        players[p].citiesLeft -= 1
        players[p].settlementsLeft += 1  // settlement returns to supply
        addLog("\(players[p].name) upgraded to a city")
        checkWin()
        return true
    }

    @discardableResult
    mutating func placeRoad(edge e: Int) -> Bool {
        let p = currentPlayer
        switch phase {
        case .setupRoad:
            guard canPlaceRoad(edge: e, for: p, isSetup: true) else { return false }
            roads[e] = p
            players[p].roadsLeft -= 1
            addLog("\(players[p].name) laid a road")
            advanceSetup()
            return true
        case .build:
            guard canPlaceRoad(edge: e, for: p, isSetup: false),
                  canAfford(Self.roadCost, player: p) else { return false }
            pay(Self.roadCost, player: p)
            roads[e] = p
            players[p].roadsLeft -= 1
            addLog("\(players[p].name) built a road")
            recomputeLongestRoad()
            checkWin()
            return true
        default:
            return false
        }
    }

    @discardableResult
    mutating func buyDevCard() -> Bool {
        guard phase == .build, !devDeck.isEmpty, canAfford(Self.devCardCost, player: currentPlayer) else { return false }
        pay(Self.devCardCost, player: currentPlayer)
        let card = devDeck.removeFirst()
        players[currentPlayer].newDevCards.append(card)
        addLog("\(players[currentPlayer].name) bought a development card")
        checkWin()  // a Victory Point card can clinch the win immediately
        return true
    }

    @discardableResult
    mutating func playKnight() -> Bool {
        guard phase == .build, !players[currentPlayer].playedDevThisTurn,
              let idx = players[currentPlayer].devCards.firstIndex(of: .knight) else { return false }
        players[currentPlayer].devCards.remove(at: idx)
        players[currentPlayer].knightsPlayed += 1
        players[currentPlayer].playedDevThisTurn = true
        addLog("\(players[currentPlayer].name) played a Knight")
        recomputeLargestArmy()
        checkWin()
        if phase == .gameOver { return true }
        phase = .moveRobber
        return true
    }

    @discardableResult
    mutating func bankTrade(give: CatanResource, get: CatanResource) -> Bool {
        guard phase == .build, give != get, (players[currentPlayer].resources[give] ?? 0) >= 4 else { return false }
        players[currentPlayer].resources[give, default: 0] -= 4
        players[currentPlayer].resources[get, default: 0] += 1
        addLog("\(players[currentPlayer].name) traded 4 \(give.label) → 1 \(get.label)")
        return true
    }

    @discardableResult
    mutating func moveRobber(to hex: Int) -> Bool {
        guard phase == .moveRobber, hex != robberHex, tiles.indices.contains(hex) else { return false }
        robberHex = hex
        var candidates = Set<Int>()
        for v in board.hexVertexIndices[hex] {
            if let b = buildings[v], b.owner != currentPlayer { candidates.insert(b.owner) }
        }
        if !candidates.isEmpty {
            let maxCount = candidates.map { totalResources($0) }.max() ?? 0
            if maxCount > 0, let victim = candidates.filter({ totalResources($0) == maxCount }).min() {
                stealRandom(from: victim, to: currentPlayer)
            }
        }
        addLog("\(players[currentPlayer].name) moved the robber")
        phase = .build
        return true
    }

    @discardableResult
    mutating func endTurn() -> Bool {
        guard phase == .build else { return false }
        players[currentPlayer].devCards.append(contentsOf: players[currentPlayer].newDevCards)
        players[currentPlayer].newDevCards.removeAll()
        players[currentPlayer].playedDevThisTurn = false
        currentPlayer = (currentPlayer + 1) % players.count
        phase = .roll
        addLog("— \(players[currentPlayer].name)'s turn —")
        return true
    }

    // MARK: Longest road / largest army

    /// Longest continuous road (trail — no edge reused) for a player. A road can't be
    /// traced *through* a vertex holding an opponent's settlement or city.
    func longestRoadLength(for p: Int) -> Int {
        var playerEdges = Set<Int>()
        for (e, o) in roads where o == p { playerEdges.insert(e) }
        guard !playerEdges.isEmpty else { return 0 }

        var best = 0
        var starts = Set<Int>()
        for e in playerEdges {
            let (a, b) = board.endpoints(of: e)
            starts.insert(a); starts.insert(b)
        }

        func canPassThrough(_ v: Int) -> Bool {
            if let b = buildings[v], b.owner != p { return false }
            return true
        }

        func dfs(_ v: Int, _ used: inout Set<Int>, _ length: Int) {
            best = max(best, length)
            guard canPassThrough(v) else { return }
            for e in board.vertexEdgeIndices[v] where playerEdges.contains(e) && !used.contains(e) {
                let (a, b) = board.endpoints(of: e)
                let other = (a == v) ? b : a
                used.insert(e)
                dfs(other, &used, length + 1)
                used.remove(e)
            }
        }

        for s in starts {
            var used = Set<Int>()
            dfs(s, &used, 0)
        }
        return best
    }

    private mutating func recomputeLongestRoad() {
        var maxLen = 0
        for p in players.indices { maxLen = max(maxLen, longestRoadLength(for: p)) }
        guard maxLen >= 5 else { longestRoadOwner = nil; return }
        let leaders = players.indices.filter { longestRoadLength(for: $0) == maxLen }
        if let cur = longestRoadOwner, leaders.contains(cur) { return }  // holder keeps it on a tie
        longestRoadOwner = leaders.min()
    }

    private mutating func recomputeLargestArmy() {
        let maxK = players.map(\.knightsPlayed).max() ?? 0
        guard maxK >= 3 else { largestArmyOwner = nil; return }
        let leaders = players.indices.filter { players[$0].knightsPlayed == maxK }
        if let cur = largestArmyOwner, leaders.contains(cur) { return }
        largestArmyOwner = leaders.min()
    }

    // MARK: Internals

    private mutating func produce(_ total: Int) {
        for (hi, tile) in tiles.enumerated() {
            guard hi != robberHex, tile.number == total, let res = tile.resource else { continue }
            for v in board.hexVertexIndices[hi] {
                if let b = buildings[v] {
                    players[b.owner].resources[res, default: 0] += (b.kind == .city ? 2 : 1)
                }
            }
        }
    }

    private mutating func grantSetupResources(vertex v: Int, to p: Int) {
        for hi in board.vertexHexIndices[v] {
            if let res = tiles[hi].resource {
                players[p].resources[res, default: 0] += 1
            }
        }
    }

    private mutating func applyDiscards() {
        for p in players.indices {
            let total = players[p].totalResourceCount
            guard total > 7 else { continue }
            var toDiscard = total / 2
            let discarded = toDiscard
            while toDiscard > 0 {
                guard let res = CatanResource.allCases.max(by: {
                    (players[p].resources[$0] ?? 0) < (players[p].resources[$1] ?? 0)
                }), (players[p].resources[res] ?? 0) > 0 else { break }
                players[p].resources[res, default: 0] -= 1
                toDiscard -= 1
            }
            addLog("\(players[p].name) discarded \(discarded)")
        }
    }

    private mutating func stealRandom(from victim: Int, to thief: Int) {
        var bag: [CatanResource] = []
        for res in CatanResource.allCases {
            bag.append(contentsOf: Array(repeating: res, count: players[victim].resources[res] ?? 0))
        }
        guard !bag.isEmpty else { return }
        let idx = rng.nextInt(upperBound: bag.count)
        let res = bag[idx]
        players[victim].resources[res, default: 0] -= 1
        players[thief].resources[res, default: 0] += 1
        addLog("\(players[thief].name) stole from \(players[victim].name)")
    }

    private mutating func pay(_ cost: [CatanResource: Int], player p: Int) {
        for (r, n) in cost { players[p].resources[r, default: 0] -= n }
    }

    private mutating func advanceSetup() {
        setupStep += 1
        lastSetupVertex = nil
        if setupStep >= setupOrder.count {
            currentPlayer = 0
            phase = .roll
            addLog("Setup complete — \(players[0].name) to roll")
        } else {
            currentPlayer = setupOrder[setupStep]
            phase = .setupSettlement
        }
    }

    private mutating func checkWin() {
        guard phase != .gameOver else { return }
        if victoryPoints(for: currentPlayer, includeHidden: true) >= Self.winningPoints {
            winner = currentPlayer
            phase = .gameOver
            addLog("🏆 \(players[currentPlayer].name) wins!")
        }
    }

    private mutating func addLog(_ s: String) {
        log.append(s)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// Deterministic in-place Fisher–Yates using the repo's SeededGenerator, matching the
/// `swapAt` + `nextInt(upperBound:)` idiom used across the other game models.
private func catanShuffle<T>(_ array: inout [T], using rng: inout SeededGenerator) {
    guard array.count > 1 else { return }
    for index in stride(from: array.count - 1, through: 1, by: -1) {
        let swap = rng.nextInt(upperBound: index + 1)
        array.swapAt(index, swap)
    }
}
