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
    private var _targetELO: Int = 1200
    var level: Int {
        get { lock.lock(); defer { lock.unlock() }; return _level }
        set {
            lock.lock()
            _level = min(10, max(1, newValue))
            _targetELO = Self.elo(forLevel: _level)
            lock.unlock()
        }
    }

    /// ELO-based strength. Setting this derives an internal 1...10 `level` (so any
    /// `level`-driven code keeps working) and drives search depth, the per-move
    /// blunder probability, and the near-best slack. Clamped to 600...2400.
    var targetELO: Int {
        get { lock.lock(); defer { lock.unlock() }; return _targetELO }
        set {
            lock.lock()
            _targetELO = min(2400, max(600, newValue))
            _level = Self.level(forELO: _targetELO)
            lock.unlock()
        }
    }

    /// Convenience for callers that prefer a function over the property.
    func configure(elo: Int) { targetELO = elo }

    func bestMove(for position: Position) async -> Move? {
        let profile = Self.strengthProfile(forELO: targetELO)
        return await Task.detached(priority: .userInitiated) {
            Self.selectMove(position, profile: profile)
        }.value
    }

    // MARK: - ELO model
    //
    // Strength is governed by two dials that BOTH vary across the whole 600...2400
    // range, so every slider step changes how the bot plays:
    //  • search depth — how many plies it looks ahead (tactical sharpness), and
    //  • temperature — how strictly it plays the best move it found.
    // The old model used 4 coarse depth buckets (everything ≥1700 was identical)
    // plus a 40% chance of a *uniformly random* move at low ELO, which felt erratic
    // (random hung pieces) and made the top third of the slider do nothing. The
    // softmax/temperature policy below weakens the bot smoothly and believably:
    // a weak bot mostly plays reasonable moves and occasionally a worse one, rather
    // than flipping a coin between "best" and "garbage".

    /// Search depth from ELO. Finer bands than before, and a genuine depth-5 top
    /// tier so the strong end of the slider keeps getting sharper.
    static func searchDepth(forELO elo: Int) -> Int {
        let e = min(2400, max(600, elo))
        switch e {
        case ..<800:        return 1
        case 800..<1100:    return 2
        case 1100..<1450:   return 3
        case 1450..<1800:   return 4
        default:            return 5   // 1800...2400
        }
    }

    /// Softmax temperature (in centipawns) for root-move selection. High at low ELO
    /// (the engine spreads probability onto weaker moves → beatable, human-like
    /// mistakes), easing smoothly toward ~best-only at high ELO. ~210cp at 600 ELO
    /// down to ~6cp at 2400 ELO. This is the primary "feel" dial and it is
    /// continuous, so adjacent slider steps are perceptibly different.
    static func temperature(forELO elo: Int) -> Double {
        let e = Double(min(2400, max(600, elo)))
        let p = (e - 600) / (2400 - 600)            // 0...1
        let minT = 6.0
        let maxT = 820.0
        return minT + pow(1 - p, 1.35) * (maxT - minT)
    }

    struct StrengthProfile: Equatable {
        var elo: Int
        var depth: Int
        var temperature: Double
        var blunderChance: Double
        var blunderWindowCentipawns: Int
    }

    static func strengthProfile(forELO elo: Int) -> StrengthProfile {
        let clamped = min(2400, max(600, elo))
        let p = Double(clamped - 600) / Double(2400 - 600)
        return StrengthProfile(
            elo: clamped,
            depth: searchDepth(forELO: clamped),
            temperature: temperature(forELO: clamped),
            blunderChance: pow(1 - p, 1.25) * 0.76,
            blunderWindowCentipawns: Int((80.0 + pow(1 - p, 1.1) * 820.0).rounded())
        )
    }

    /// Map ELO (600...2400) onto the 1...10 level scale.
    static func level(forELO elo: Int) -> Int {
        let clamped = min(2400, max(600, elo))
        // 600 -> 1, 2400 -> 10, linearly.
        let scaled = 1.0 + Double(clamped - 600) / Double(2400 - 600) * 9.0
        return min(10, max(1, Int(scaled.rounded())))
    }

    /// Inverse of `level(forELO:)`: a representative ELO for a given level so
    /// that setting `level` keeps `targetELO` consistent.
    static func elo(forLevel level: Int) -> Int {
        let clamped = min(10, max(1, level))
        let elo = 600.0 + Double(clamped - 1) / 9.0 * Double(2400 - 600)
        return min(2400, max(600, Int(elo.rounded())))
    }

    // MARK: - Root search

    /// Exact score for every legal root move, each searched with a FULL window.
    /// Tightening alpha across siblings (as a normal alpha-beta root would) leaves
    /// every non-best move with only a fail-soft upper bound, which would corrupt
    /// the softmax weighting below — so the root deliberately forgoes that pruning.
    static func scoredRootMoves(_ pos: Position, depth: Int) -> [(move: Move, score: Int)] {
        orderedMoves(MoveGenerator.legalMoves(in: pos), pos: pos).map { m in
            let next = MoveGenerator.makeMove(m, in: pos)
            let score = -negamax(next, depth: depth - 1, alpha: -infinity, beta: infinity)
            return (move: m, score: score)
        }
    }

    /// Pick a root move by sampling a Boltzmann (softmax) distribution over the
    /// exact per-move scores: P(move) ∝ exp((score − best) / temperature). The best
    /// move is always the most likely; worse moves get exponentially less likely as
    /// `temperature` falls. A tiny temperature collapses to "always play the best",
    /// giving a clean, continuous strength dial instead of the old all-or-nothing
    /// random-blunder model.
    static func selectMove(_ pos: Position, depth: Int, temperature: Double) -> Move? {
        selectMove(
            pos,
            profile: StrengthProfile(
                elo: 1200,
                depth: depth,
                temperature: temperature,
                blunderChance: 0,
                blunderWindowCentipawns: 0
            )
        )
    }

    static func selectMove(_ pos: Position, profile: StrengthProfile) -> Move? {
        selectMove(pos, profile: profile, randomFraction: Double.random(in: 0..<1))
    }

    static func selectMove(_ pos: Position, profile: StrengthProfile, randomFraction: Double) -> Move? {
        let scored = scoredRootMoves(pos, depth: profile.depth).sorted {
            if $0.score == $1.score { return $0.move.uciNotation < $1.move.uciNotation }
            return $0.score > $1.score
        }
        guard !scored.isEmpty else { return nil }
        let best = scored[0].score

        let roll = min(0.999_999, max(0, randomFraction))
        if roll < profile.blunderChance {
            let weaker = scored.filter { entry in
                let loss = best - entry.score
                return loss >= 80 && loss <= max(80, profile.blunderWindowCentipawns)
            }
            if !weaker.isEmpty {
                let scaled = roll / max(profile.blunderChance, 0.000_001)
                let index = min(weaker.count - 1, Int(scaled * Double(weaker.count)))
                return weaker[index].move
            }
            if scored.count > 1 {
                return scored[min(scored.count - 1, 1)].move
            }
        }

        // Near-deterministic at very low temperature: just play one of the best moves.
        guard profile.temperature > 1 else {
            let top = scored.filter { $0.score == best }
            return (top.randomElement() ?? scored.first)?.move
        }

        // Boltzmann weights, normalized against `best` for numerical stability so
        // exp() never overflows (the largest exponent is exp(0) = 1).
        var weights = [Double]()
        weights.reserveCapacity(scored.count)
        var total = 0.0
        for entry in scored {
            let w = exp(Double(entry.score - best) / profile.temperature)
            weights.append(w)
            total += w
        }
        guard total > 0, total.isFinite else { return scored.first?.move }

        var r = roll * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return scored[i].move }
        }
        return scored.last?.move
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
