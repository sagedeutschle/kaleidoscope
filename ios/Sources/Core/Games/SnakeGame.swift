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

    // MARK: Speed tuning
    // Snake speed is a pure function of the score so the view timer and tests
    // share one source of truth. Start gently (easy to react to) and ramp up
    // smoothly as the snake grows, clamped so it never becomes impossible.
    static let initialTickInterval: Double = 0.32   // gentle starting pace (was ~0.18)
    static let minTickInterval: Double = 0.11        // floor — never faster than this
    static let tickSpeedupPerScore: Double = 0.012   // how much each apple shortens the tick

    /// Seconds between steps for a given score. Non-increasing in `score`,
    /// clamped at `minTickInterval`. Pure — no side effects, safe to unit test.
    static func tickInterval(forScore score: Int) -> Double {
        let eased = initialTickInterval - Double(max(0, score)) * tickSpeedupPerScore
        return max(minTickInterval, eased)
    }

    let width: Int
    let height: Int
    private(set) var body: [SnakePoint]
    private(set) var direction: Direction
    private(set) var apple: SnakePoint
    private(set) var score: Int = 0
    private(set) var status: Status = .playing
    // Buffered next turn. A swipe stores its intent here; `step` commits it on the
    // next tick. This lets quick successive swipes register cleanly and blocks
    // 180° reversals relative to the last *committed* heading (self-death guard).
    private(set) var pendingDirection: Direction?

    /// Current effective tick interval for this game's score.
    var tickInterval: Double { SnakeGame.tickInterval(forScore: score) }

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
        // Validate against the committed heading, not any earlier buffered turn,
        // so a fast right→up→down flick can't sneak a reversal into the snake.
        guard !newDirection.isOpposite(of: direction) else { return }
        guard newDirection != direction else { return }
        pendingDirection = newDirection
    }

    mutating func step(rng: inout SeededGenerator) {
        guard status == .playing, let head = body.first else { return }
        // Commit the buffered turn (if any) exactly once per tick.
        if let pending = pendingDirection {
            if !pending.isOpposite(of: direction) {
                direction = pending
            }
            pendingDirection = nil
        }
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
