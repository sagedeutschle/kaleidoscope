import Foundation

struct ReversiAI {
    var player: ReversiPiece
    var targetELO: Int

    init(player: ReversiPiece = .white, targetELO: Int = 1200) {
        self.player = player
        self.targetELO = min(2400, max(600, targetELO))
    }

    static func searchDepth(forELO elo: Int) -> Int {
        let e = min(2400, max(600, elo))
        switch e {
        case ..<800: return 1
        case 800..<1100: return 2
        case 1100..<1500: return 3
        case 1500..<2000: return 4
        default: return 5
        }
    }

    func move(in game: ReversiGame) -> ReversiMove? {
        guard game.currentPlayer == player, !game.isGameOver else { return nil }
        let moves = orderedMoves(game.legalMoves(for: player))
        guard !moves.isEmpty else { return nil }
        if let corner = moves.first(where: { Self.corners.contains($0) }) {
            return corner
        }

        let depth = Self.searchDepth(forELO: targetELO)
        var bestMove = moves[0]
        var bestScore = Int.min

        for move in moves {
            var next = game
            guard next.applyMove(row: move.row, col: move.col) else { continue }
            let score = minimax(next, depth: depth - 1, alpha: Int.min / 4, beta: Int.max / 4)
            if score > bestScore || (score == bestScore && movePriority(move) > movePriority(bestMove)) {
                bestScore = score
                bestMove = move
            }
        }

        return bestMove
    }

    private func minimax(_ game: ReversiGame, depth: Int, alpha: Int, beta: Int) -> Int {
        if game.isGameOver || depth == 0 {
            return evaluate(game)
        }

        let legalMoves = orderedMoves(game.legalMoves(for: game.currentPlayer))
        if legalMoves.isEmpty {
            var passed = game
            passed.passIfNeeded()
            if passed == game { return evaluate(game) }
            return minimax(passed, depth: depth - 1, alpha: alpha, beta: beta)
        }

        if game.currentPlayer == player {
            var alpha = alpha
            var best = Int.min / 4
            for move in legalMoves {
                var next = game
                guard next.applyMove(row: move.row, col: move.col) else { continue }
                best = max(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var beta = beta
            var best = Int.max / 4
            for move in legalMoves {
                var next = game
                guard next.applyMove(row: move.row, col: move.col) else { continue }
                best = min(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    private func evaluate(_ game: ReversiGame) -> Int {
        if game.isGameOver {
            let mine = game.count(for: player)
            let theirs = game.count(for: player.opponent)
            if mine > theirs { return 1_000_000 + mine - theirs }
            if theirs > mine { return -1_000_000 - theirs + mine }
            return 0
        }

        var score = (game.count(for: player) - game.count(for: player.opponent)) * 10
        score += (game.legalMoves(for: player).count - game.legalMoves(for: player.opponent).count) * 22

        for row in 0..<ReversiGame.size {
            for col in 0..<ReversiGame.size {
                guard let piece = game.piece(row: row, col: col) else { continue }
                let value = Self.positionWeights[row * ReversiGame.size + col]
                score += piece == player ? value : -value
            }
        }

        for corner in Self.corners {
            if game.piece(row: corner.row, col: corner.col) == nil {
                for adjacent in adjacentToCorner(corner) {
                    guard let piece = game.piece(row: adjacent.row, col: adjacent.col) else { continue }
                    score += piece == player ? -55 : 55
                }
            }
        }

        return score
    }

    private func orderedMoves(_ moves: [ReversiMove]) -> [ReversiMove] {
        moves.sorted { lhs, rhs in
            let left = movePriority(lhs)
            let right = movePriority(rhs)
            if left != right { return left > right }
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.col < rhs.col
        }
    }

    private func movePriority(_ move: ReversiMove) -> Int {
        if Self.corners.contains(move) { return 10_000 }
        if isEdge(move) { return 1_000 }
        let centerDistance = abs(move.row - 3) + abs(move.col - 3)
        return 100 - centerDistance
    }

    private func isEdge(_ move: ReversiMove) -> Bool {
        move.row == 0 || move.row == ReversiGame.size - 1 || move.col == 0 || move.col == ReversiGame.size - 1
    }

    private func adjacentToCorner(_ corner: ReversiMove) -> [ReversiMove] {
        let rowStep = corner.row == 0 ? 1 : -1
        let colStep = corner.col == 0 ? 1 : -1
        return [
            ReversiMove(row: corner.row + rowStep, col: corner.col),
            ReversiMove(row: corner.row, col: corner.col + colStep),
            ReversiMove(row: corner.row + rowStep, col: corner.col + colStep)
        ]
    }

    private static let corners: [ReversiMove] = [
        ReversiMove(row: 0, col: 0),
        ReversiMove(row: 0, col: ReversiGame.size - 1),
        ReversiMove(row: ReversiGame.size - 1, col: 0),
        ReversiMove(row: ReversiGame.size - 1, col: ReversiGame.size - 1)
    ]

    private static let positionWeights: [Int] = [
        120, -24,  20,   6,   6,  20, -24, 120,
        -24, -48,  -6,  -6,  -6,  -6, -48, -24,
         20,  -6,  16,   4,   4,  16,  -6,  20,
          6,  -6,   4,   2,   2,   4,  -6,   6,
          6,  -6,   4,   2,   2,   4,  -6,   6,
         20,  -6,  16,   4,   4,  16,  -6,  20,
        -24, -48,  -6,  -6,  -6,  -6, -48, -24,
        120, -24,  20,   6,   6,  20, -24, 120
    ]
}
