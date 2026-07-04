import Foundation

struct CheckersAI {
    enum Difficulty: String, CaseIterable, Identifiable, Codable {
        case easy
        case normal
        case hard

        var id: String { rawValue }
    }

    var player: CheckersPlayer
    var difficulty: Difficulty
    var targetELO: Int

    init(player: CheckersPlayer = .light, difficulty: Difficulty = .normal) {
        self.player = player
        self.difficulty = difficulty
        self.targetELO = Self.elo(for: difficulty)
    }

    init(player: CheckersPlayer = .light, targetELO: Int) {
        let clamped = min(2400, max(600, targetELO))
        self.player = player
        self.targetELO = clamped
        self.difficulty = Self.difficulty(forELO: clamped)
    }

    static func searchDepth(forELO elo: Int) -> Int {
        let e = min(2400, max(600, elo))
        switch e {
        case ..<900: return 1
        case 900..<1300: return 2
        case 1300..<1900: return 3
        default: return 4
        }
    }

    func move(in game: CheckersGame) -> CheckersMove? {
        guard game.currentPlayer == player, !game.isGameOver else { return nil }
        let moves = game.legalMoves()
        guard !moves.isEmpty else { return nil }

        return moves.max { lhs, rhs in
            let left = score(lhs, in: game)
            let right = score(rhs, in: game)
            if left != right { return left < right }
            return tieBreakValue(lhs) < tieBreakValue(rhs)
        }
    }

    private func score(_ move: CheckersMove, in game: CheckersGame) -> Int {
        var next = game
        _ = next.applyMove(move)

        var score = tacticalScore(move, in: game)
        score += minimax(next, depth: Self.searchDepth(forELO: targetELO) - 1, alpha: Int.min / 4, beta: Int.max / 4)
        return score
    }

    private func minimax(_ game: CheckersGame, depth: Int, alpha: Int, beta: Int) -> Int {
        if game.isGameOver || depth <= 0 {
            return evaluate(game)
        }

        let moves = orderedMoves(game.legalMoves(), in: game)
        guard !moves.isEmpty else { return evaluate(game) }

        if game.currentPlayer == player {
            var alpha = alpha
            var best = Int.min / 4
            for move in moves {
                var next = game
                guard next.applyMove(move) else { continue }
                best = max(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var beta = beta
            var best = Int.max / 4
            for move in moves {
                var next = game
                guard next.applyMove(move) else { continue }
                best = min(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    private func evaluate(_ game: CheckersGame) -> Int {
        var score = boardScore(game, for: player)
        if game.winner == player { score += 100_000 }
        if game.winner == player.opponent { score -= 100_000 }

        if game.currentPlayer == player {
            score += game.legalMoves().count * 5
        } else {
            score -= game.legalMoves().count * 5
        }
        return score
    }

    private func tacticalScore(_ move: CheckersMove, in game: CheckersGame) -> Int {
        var score = 0
        if move.isCapture { score += 1_200 }
        if promotes(move, in: game) { score += 900 }
        score += simpleAdvanceScore(move, in: game) * 12
        return score
    }

    private func boardScore(_ game: CheckersGame, for player: CheckersPlayer) -> Int {
        var total = 0
        for row in 0..<CheckersGame.size {
            for col in 0..<CheckersGame.size {
                guard let piece = game.piece(row: row, col: col) else { continue }
                let material = piece.kind == .king ? 55 : 30
                let advancement: Int
                switch piece.player {
                case .dark:
                    advancement = CheckersGame.size - 1 - row
                case .light:
                    advancement = row
                }
                let value = material + advancement
                total += piece.player == player ? value : -value
            }
        }
        return total
    }

    private func mobilityScore(_ game: CheckersGame, for player: CheckersPlayer) -> Int {
        guard game.currentPlayer == player else { return 0 }
        return game.legalMoves().count * 3
    }

    private func promotes(_ move: CheckersMove, in game: CheckersGame) -> Bool {
        guard let piece = game.piece(at: move.from), piece.kind == .man else { return false }
        return move.to.row == piece.player.promotionRow
    }

    private func simpleAdvanceScore(_ move: CheckersMove, in game: CheckersGame) -> Int {
        guard let piece = game.piece(at: move.from), piece.kind == .man else { return 0 }
        switch piece.player {
        case .dark:
            return move.from.row - move.to.row
        case .light:
            return move.to.row - move.from.row
        }
    }

    private func tieBreakValue(_ move: CheckersMove) -> Int {
        move.to.row * 1_000 + move.to.col * 100 + move.from.row * 10 + move.from.col
    }

    private func orderedMoves(_ moves: [CheckersMove], in game: CheckersGame) -> [CheckersMove] {
        moves.sorted { lhs, rhs in
            let left = tacticalScore(lhs, in: game)
            let right = tacticalScore(rhs, in: game)
            if left != right { return left > right }
            return tieBreakValue(lhs) > tieBreakValue(rhs)
        }
    }

    private static func difficulty(forELO elo: Int) -> Difficulty {
        switch min(2400, max(600, elo)) {
        case ..<1000: return .easy
        case 1000..<1700: return .normal
        default: return .hard
        }
    }

    private static func elo(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 800
        case .normal: return 1200
        case .hard: return 1900
        }
    }
}
