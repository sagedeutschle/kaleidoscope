import Foundation

/// The engine seam. The built-in MinimaxAI implements this today; a Stockfish
/// (UCI subprocess) adapter can be dropped in later without touching the views.
/// Strength is a 1...10 `level` (driven by the difficulty slider).
protocol ChessAI: AnyObject, Sendable {
    var level: Int { get set }            // 1 (weakest) ... 10 (strongest)
    func bestMove(for position: Position) async -> Move?
}

/// Self-contained alpha-beta (negamax) engine with material + piece-square
/// evaluation. Search runs off the main actor so the UI never blocks.
final class MinimaxAI: ChessAI, @unchecked Sendable {
    private let lock = NSLock()
    private var _level: Int = 5
    var level: Int {
        get { lock.lock(); defer { lock.unlock() }; return _level }
        set { lock.lock(); _level = min(10, max(1, newValue)); lock.unlock() }
    }

    func bestMove(for position: Position) async -> Move? {
        let lvl = level
        let depth = Self.searchDepth(forLevel: lvl)
        let slack = Self.slack(forLevel: lvl)
        return await Task.detached(priority: .userInitiated) {
            Self.searchRoot(position, depth: depth, slack: slack)
        }.value
    }

    /// Deeper search at higher levels.
    static func searchDepth(forLevel level: Int) -> Int {
        switch level {
        case ...2:  return 2
        case 3...5: return 3
        default:    return 4
        }
    }

    /// Centipawn slack: at the root the AI picks randomly among moves within
    /// this margin of the best score. Lower level = more slack = more beatable.
    static func slack(forLevel level: Int) -> Int {
        max(0, (10 - level) * 12)
    }

    // MARK: - Root search

    /// Exact score for every legal root move, each searched with a FULL window.
    /// Tightening alpha across siblings (as a normal alpha-beta root would) leaves
    /// every non-best move with only a fail-soft upper bound, which would corrupt
    /// the difficulty pool below — so the root deliberately forgoes that pruning.
    static func scoredRootMoves(_ pos: Position, depth: Int) -> [(move: Move, score: Int)] {
        orderedMoves(MoveGenerator.legalMoves(in: pos), pos: pos).map { m in
            let next = MoveGenerator.makeMove(m, in: pos)
            let score = -negamax(next, depth: depth - 1, alpha: -infinity, beta: infinity)
            return (move: m, score: score)
        }
    }

    static func searchRoot(_ pos: Position, depth: Int, slack: Int) -> Move? {
        let scored = scoredRootMoves(pos, depth: depth)
        guard !scored.isEmpty else { return nil }

        let best = scored.map(\.score).max() ?? 0
        // Difficulty slack: choose randomly among "good enough" moves. Scores are
        // now exact, so this is the true set of moves within `slack` of the best.
        let pool = scored.filter { $0.score >= best - slack }
        return (pool.randomElement() ?? scored.first)?.move
    }

    // MARK: - Negamax with alpha-beta

    private static let infinity = 1_000_000

    private static func negamax(_ pos: Position, depth: Int, alpha: Int, beta: Int) -> Int {
        if depth == 0 { return evaluate(pos) }
        let moves = orderedMoves(MoveGenerator.legalMoves(in: pos), pos: pos)
        if moves.isEmpty {
            // Checkmate (bad for side to move) or stalemate (neutral).
            if MoveGenerator.isInCheck(pos.sideToMove, in: pos) {
                return -infinity + (10 - depth)   // prefer quicker wins / later losses
            }
            return 0
        }
        var alpha = alpha
        var best = -infinity
        for m in moves {
            let next = MoveGenerator.makeMove(m, in: pos)
            let score = -negamax(next, depth: depth - 1, alpha: -beta, beta: -alpha)
            if score > best { best = score }
            if best > alpha { alpha = best }
            if alpha >= beta { break }            // cutoff
        }
        return best
    }

    /// Captures first (cheap, big alpha-beta win).
    private static func orderedMoves(_ moves: [Move], pos: Position) -> [Move] {
        moves.sorted { a, b in
            captureValue(a, pos) > captureValue(b, pos)
        }
    }

    private static func captureValue(_ move: Move, _ pos: Position) -> Int {
        guard let victim = pos.piece(at: move.to) else {
            return move.promotion != nil ? 800 : 0
        }
        let attacker = pos.piece(at: move.from)?.type.value ?? 0
        return victim.type.value * 10 - attacker   // MVV-LVA-ish
    }

    // MARK: - Evaluation (centipawns, from side-to-move's perspective)

    static func evaluate(_ pos: Position) -> Int {
        var score = 0
        for i in 0..<64 {
            guard let p = pos.board[i] else { continue }
            let sq = Square(index: i)
            // Tables are written from White's a1-at-bottom view; mirror for Black.
            let pstIndex = (p.color == .white) ? (sq.rank * 8 + sq.file)
                                               : ((7 - sq.rank) * 8 + sq.file)
            let material = p.type.value
            let positional = pst(for: p.type)[pstIndex]
            let sign = (p.color == pos.sideToMove) ? 1 : -1
            score += sign * (material + positional)
        }
        return score
    }

    private static func pst(for type: PieceType) -> [Int] {
        switch type {
        case .pawn:   return pawnPST
        case .knight: return knightPST
        case .bishop: return bishopPST
        case .rook:   return rookPST
        case .queen:  return queenPST
        case .king:   return kingPST
        }
    }

    // Index 0 = a1 ... 63 = h8 (White's perspective).
    private static let pawnPST: [Int] = [
         0,  0,  0,  0,  0,  0,  0,  0,
         5, 10, 10,-20,-20, 10, 10,  5,
         5, -5,-10,  0,  0,-10, -5,  5,
         0,  0,  0, 20, 20,  0,  0,  0,
         5,  5, 10, 25, 25, 10,  5,  5,
        10, 10, 20, 30, 30, 20, 10, 10,
        50, 50, 50, 50, 50, 50, 50, 50,
         0,  0,  0,  0,  0,  0,  0,  0]
    private static let knightPST: [Int] = [
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -30,  5, 10, 15, 15, 10,  5,-30,
        -30,  0, 15, 20, 20, 15,  0,-30,
        -30,  5, 15, 20, 20, 15,  5,-30,
        -30,  0, 10, 15, 15, 10,  0,-30,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50]
    private static let bishopPST: [Int] = [
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  0, 10, 10, 10, 10,  0,-10,
        -10,  5,  5, 10, 10,  5,  5,-10,
        -10,  0,  5, 10, 10,  5,  0,-10,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -20,-10,-10,-10,-10,-10,-10,-20]
    private static let rookPST: [Int] = [
         0,  0,  0,  5,  5,  0,  0,  0,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
         5, 10, 10, 10, 10, 10, 10,  5,
         0,  0,  0,  0,  0,  0,  0,  0]
    private static let queenPST: [Int] = [
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  5,  0,  0,  0,  0,-10,
        -10,  5,  5,  5,  5,  5,  0,-10,
          0,  0,  5,  5,  5,  5,  0, -5,
         -5,  0,  5,  5,  5,  5,  0, -5,
        -10,  0,  5,  5,  5,  5,  0,-10,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20]
    private static let kingPST: [Int] = [
         20, 30, 10,  0,  0, 10, 30, 20,
         20, 20,  0,  0,  0,  0, 20, 20,
        -10,-20,-20,-20,-20,-20,-20,-10,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30]
}
