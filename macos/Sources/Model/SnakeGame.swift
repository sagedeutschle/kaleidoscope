import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — active arcade persistence snapshots.
struct SnakePoint: Codable, Hashable {
    var row: Int
    var col: Int
}

struct SnakeGame: Codable, Equatable, Hashable {
    enum Direction: Codable, Hashable {
        case up
        case down
        case left
        case right

        var delta: (row: Int, col: Int) {
            switch self {
            case .up: return (-1, 0)
            case .down: return (1, 0)
            case .left: return (0, -1)
            case .right: return (0, 1)
            }
        }

        func isOpposite(of other: Direction) -> Bool {
            switch (self, other) {
            case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
                return true
            default:
                return false
            }
        }
    }

    enum Status: Codable, Equatable, Hashable {
        case playing
        case lost
    }

    let width: Int
    let height: Int
    private(set) var body: [SnakePoint]
    private(set) var direction: Direction
    private(set) var apple: SnakePoint
    private(set) var score: Int = 0
    private(set) var status: Status = .playing

    init(width: Int = 14,
         height: Int = 14,
         body: [SnakePoint] = [SnakePoint(row: 7, col: 6), SnakePoint(row: 7, col: 5), SnakePoint(row: 7, col: 4)],
         direction: Direction = .right,
         apple: SnakePoint = SnakePoint(row: 5, col: 10),
         score: Int = 0,
         status: Status = .playing) {
        precondition(width > 2 && height > 2)
        self.width = width
        self.height = height
        self.body = body
        self.direction = direction
        self.apple = apple
        self.score = score
        self.status = status
    }

    mutating func turn(_ newDirection: Direction) {
        guard !newDirection.isOpposite(of: direction) else { return }
        direction = newDirection
    }

    mutating func step(rng: inout SeededGenerator) {
        guard status == .playing, let head = body.first else { return }
        let delta = direction.delta
        let next = SnakePoint(row: head.row + delta.row, col: head.col + delta.col)
        let willEat = next == apple
        let occupied = willEat ? Set(body) : Set(body.dropLast())

        guard (0..<height).contains(next.row), (0..<width).contains(next.col), !occupied.contains(next) else {
            status = .lost
            return
        }

        body.insert(next, at: 0)
        if willEat {
            score += 1
            spawnApple(rng: &rng)
        } else {
            body.removeLast()
        }
    }

    private mutating func spawnApple(rng: inout SeededGenerator) {
        let occupied = Set(body)
        let empty = (0..<(width * height))
            .map { SnakePoint(row: $0 / width, col: $0 % width) }
            .filter { !occupied.contains($0) }
        guard !empty.isEmpty else { return }
        apple = empty[rng.nextInt(upperBound: empty.count)]
    }
}
