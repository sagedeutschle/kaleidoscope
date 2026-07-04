import Foundation

enum SeaBattlePlayer: String, Codable, Equatable, Hashable {
    case host
    case guest

    var opponent: SeaBattlePlayer {
        self == .host ? .guest : .host
    }
}

struct SeaBattlePoint: Codable, Equatable, Hashable {
    var row: Int
    var col: Int
}

struct SeaBattleBoard: Codable, Equatable, Hashable {
    var shipCells: Set<SeaBattlePoint>
    var shots: Set<SeaBattlePoint>

    init(shipCells: Set<SeaBattlePoint>, shots: Set<SeaBattlePoint> = []) {
        self.shipCells = shipCells
        self.shots = shots
    }

    func wasHit(_ point: SeaBattlePoint) -> Bool {
        shipCells.contains(point) && shots.contains(point)
    }

    var allShipsSunk: Bool {
        !shipCells.isEmpty && shipCells.isSubset(of: shots)
    }
}

enum SeaBattleShotResult: Equatable {
    case hit
    case miss
    case sunk
    case alreadyTried
    case invalid
}

enum SeaBattleOrientation: String, CaseIterable, Codable, Equatable, Hashable {
    case horizontal
    case vertical
}

struct SeaBattlePlacement: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    var length: Int
    var origin: SeaBattlePoint
    var orientation: SeaBattleOrientation

    var cells: [SeaBattlePoint] {
        SeaBattleFleetDeployment.cells(length: length, at: origin, orientation: orientation)
    }
}

struct SeaBattleFleetDeployment: Codable, Equatable, Hashable {
    private(set) var placements: [SeaBattlePlacement]

    init(placements: [SeaBattlePlacement] = []) {
        self.placements = []
        for placement in placements {
            _ = place(length: placement.length, at: placement.origin, orientation: placement.orientation)
        }
    }

    var shipCells: Set<SeaBattlePoint> {
        Set(placements.flatMap(\.cells))
    }

    var isComplete: Bool {
        placements.map(\.length).sorted() == SeaBattleGame.fleet.sorted()
            && shipCells.count == SeaBattleGame.fleet.reduce(0, +)
    }

    var remainingFleet: [Int] {
        var remaining = SeaBattleGame.fleet
        for placement in placements {
            if let index = remaining.firstIndex(of: placement.length) {
                remaining.remove(at: index)
            }
        }
        return remaining
    }

    var nextLength: Int? {
        remainingFleet.first
    }

    @discardableResult
    mutating func place(length: Int, at origin: SeaBattlePoint, orientation: SeaBattleOrientation) -> Bool {
        guard remainingFleet.contains(length) else { return false }
        let placement = SeaBattlePlacement(length: length, origin: origin, orientation: orientation)
        guard Self.canPlace(placement, against: shipCells) else { return false }
        placements.append(placement)
        return true
    }

    @discardableResult
    mutating func removeShip(containing point: SeaBattlePoint) -> Bool {
        guard let index = placements.firstIndex(where: { $0.cells.contains(point) }) else { return false }
        placements.remove(at: index)
        return true
    }

    func placement(containing point: SeaBattlePoint) -> SeaBattlePlacement? {
        placements.first { $0.cells.contains(point) }
    }

    func placement(id: SeaBattlePlacement.ID) -> SeaBattlePlacement? {
        placements.first { $0.id == id }
    }

    func canMoveShip(id: SeaBattlePlacement.ID, to origin: SeaBattlePoint, orientation: SeaBattleOrientation) -> Bool {
        guard let moving = placement(id: id) else { return false }
        let moved = SeaBattlePlacement(id: moving.id, length: moving.length, origin: origin, orientation: orientation)
        let occupied = Set(placements.filter { $0.id != id }.flatMap(\.cells))
        return Self.canPlace(moved, against: occupied)
    }

    @discardableResult
    mutating func moveShip(id: SeaBattlePlacement.ID, to origin: SeaBattlePoint, orientation: SeaBattleOrientation) -> Bool {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return false }
        let moved = SeaBattlePlacement(id: placements[index].id, length: placements[index].length, origin: origin, orientation: orientation)
        let occupied = Set(placements.enumerated().filter { $0.offset != index }.flatMap { $0.element.cells })
        guard Self.canPlace(moved, against: occupied) else { return false }
        placements[index] = moved
        return true
    }

    mutating func reset() {
        placements.removeAll()
    }

    static func random(seed: UInt64) -> SeaBattleFleetDeployment {
        var rng = SeededGenerator(seed: seed)
        var deployment = SeaBattleFleetDeployment()
        for length in SeaBattleGame.fleet {
            var placed = false
            while !placed {
                let orientation: SeaBattleOrientation = rng.nextInt(upperBound: 2) == 0 ? .horizontal : .vertical
                let maxRow = orientation == .horizontal ? SeaBattleGame.size - 1 : SeaBattleGame.size - length
                let maxCol = orientation == .horizontal ? SeaBattleGame.size - length : SeaBattleGame.size - 1
                let row = rng.nextInt(upperBound: maxRow + 1)
                let col = rng.nextInt(upperBound: maxCol + 1)
                placed = deployment.place(length: length, at: SeaBattlePoint(row: row, col: col), orientation: orientation)
            }
        }
        return deployment
    }

    static func cells(length: Int, at origin: SeaBattlePoint, orientation: SeaBattleOrientation) -> [SeaBattlePoint] {
        (0..<length).map { offset in
            SeaBattlePoint(
                row: origin.row + (orientation == .vertical ? offset : 0),
                col: origin.col + (orientation == .horizontal ? offset : 0)
            )
        }
    }

    private static func canPlace(_ placement: SeaBattlePlacement, against occupied: Set<SeaBattlePoint>) -> Bool {
        let cells = placement.cells
        guard cells.count == placement.length else { return false }
        guard cells.allSatisfy(Self.isValid) else { return false }
        return occupied.isDisjoint(with: cells)
    }

    private static func isValid(_ point: SeaBattlePoint) -> Bool {
        (0..<SeaBattleGame.size).contains(point.row) && (0..<SeaBattleGame.size).contains(point.col)
    }
}

struct SeaBattleGame: Codable, Equatable, Hashable {
    static let size = 10
    static let fleet = [5, 4, 3, 3, 2]

    private(set) var boards: [SeaBattlePlayer: SeaBattleBoard]
    private(set) var currentPlayer: SeaBattlePlayer
    private(set) var winner: SeaBattlePlayer?
    private(set) var moveCount: Int

    init(
        boards: [SeaBattlePlayer: SeaBattleBoard],
        currentPlayer: SeaBattlePlayer = .host,
        winner: SeaBattlePlayer? = nil,
        moveCount: Int = 0
    ) {
        self.boards = boards
        self.currentPlayer = currentPlayer
        self.winner = winner
        self.moveCount = moveCount
    }

    static func newGame(seed: UInt64) -> SeaBattleGame {
        var hostRNG = SeededGenerator(seed: seed)
        var guestRNG = SeededGenerator(seed: seed ^ 0x9E3779B97F4A7C15)
        return SeaBattleGame(boards: [
            .host: SeaBattleBoard(shipCells: placeFleet(rng: &hostRNG)),
            .guest: SeaBattleBoard(shipCells: placeFleet(rng: &guestRNG))
        ])
    }

    static var deploymentGame: SeaBattleGame {
        SeaBattleGame(boards: [
            .host: SeaBattleBoard(shipCells: []),
            .guest: SeaBattleBoard(shipCells: [])
        ])
    }

    static func gameFromDeployments(host: SeaBattleFleetDeployment, guest: SeaBattleFleetDeployment) -> SeaBattleGame? {
        guard host.isComplete, guest.isComplete else { return nil }
        return SeaBattleGame(boards: [
            .host: SeaBattleBoard(shipCells: host.shipCells),
            .guest: SeaBattleBoard(shipCells: guest.shipCells)
        ])
    }

    var isGameOver: Bool { winner != nil }

    func board(for player: SeaBattlePlayer) -> SeaBattleBoard {
        boards[player] ?? SeaBattleBoard(shipCells: [])
    }

    @discardableResult
    mutating func fire(at point: SeaBattlePoint) -> SeaBattleShotResult {
        guard winner == nil else { return .invalid }
        guard Self.isValid(point) else { return .invalid }
        let targetPlayer = currentPlayer.opponent
        var targetBoard = board(for: targetPlayer)
        guard !targetBoard.shots.contains(point) else { return .alreadyTried }

        targetBoard.shots.insert(point)
        boards[targetPlayer] = targetBoard
        moveCount += 1

        if targetBoard.shipCells.contains(point) {
            if targetBoard.allShipsSunk {
                winner = currentPlayer
                return .hit
            }
            return .hit
        }

        currentPlayer = targetPlayer
        return .miss
    }

    private static func placeFleet(rng: inout SeededGenerator) -> Set<SeaBattlePoint> {
        var occupied = Set<SeaBattlePoint>()
        for length in fleet {
            var placed = false
            while !placed {
                let horizontal = rng.nextInt(upperBound: 2) == 0
                let maxRow = horizontal ? size - 1 : size - length
                let maxCol = horizontal ? size - length : size - 1
                let row = rng.nextInt(upperBound: maxRow + 1)
                let col = rng.nextInt(upperBound: maxCol + 1)
                let cells = (0..<length).map { offset in
                    SeaBattlePoint(row: row + (horizontal ? 0 : offset), col: col + (horizontal ? offset : 0))
                }
                if cells.allSatisfy({ !occupied.contains($0) }) {
                    occupied.formUnion(cells)
                    placed = true
                }
            }
        }
        return occupied
    }

    private static func isValid(_ point: SeaBattlePoint) -> Bool {
        (0..<size).contains(point.row) && (0..<size).contains(point.col)
    }
}
