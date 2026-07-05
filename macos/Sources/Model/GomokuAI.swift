import Foundation

struct GomokuAI {
    var player: GomokuPlayer
    var targetELO: Int

    init(player: GomokuPlayer = .white, targetELO: Int = 1200) {
        self.player = player
        self.targetELO = min(2400, max(600, targetELO))
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

    func move(in game: GomokuGame) -> GomokuPoint? {
        guard game.currentPlayer == player, !game.isGameOver else { return nil }
        if game.moveCount == 0 {
            return GomokuPoint(row: GomokuGame.size / 2, col: GomokuGame.size / 2)
        }

        let candidates = candidateMoves(in: game, limit: candidateLimit(forELO: targetELO))
        guard !candidates.isEmpty else { return nil }

        if let win = winningMove(for: player, in: game, candidates: candidates) {
            return win
        }
        if let block = winningMove(for: player.opponent, in: game, candidates: candidates) {
            return block
        }

        let depth = Self.searchDepth(forELO: targetELO)
        var bestMove = candidates[0]
        var bestScore = Int.min / 4

        for move in candidates {
            var next = game
            guard next.placeStone(row: move.row, col: move.col) else { continue }
            let score = minimax(next, depth: depth - 1, alpha: Int.min / 4, beta: Int.max / 4)
            if score > bestScore || (score == bestScore && movePriority(move, in: game, for: player) > movePriority(bestMove, in: game, for: player)) {
                bestScore = score
                bestMove = move
            }
        }

        return bestMove
    }

    private func minimax(_ game: GomokuGame, depth: Int, alpha: Int, beta: Int) -> Int {
        if game.isGameOver || depth == 0 {
            return evaluate(game)
        }

        let candidates = candidateMoves(in: game, limit: candidateLimit(forELO: targetELO))
        guard !candidates.isEmpty else { return evaluate(game) }

        if game.currentPlayer == player {
            var alpha = alpha
            var best = Int.min / 4
            for move in candidates {
                var next = game
                guard next.placeStone(row: move.row, col: move.col) else { continue }
                best = max(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var beta = beta
            var best = Int.max / 4
            for move in candidates {
                var next = game
                guard next.placeStone(row: move.row, col: move.col) else { continue }
                best = min(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    private func evaluate(_ game: GomokuGame) -> Int {
        if game.winner == player { return 1_000_000 }
        if game.winner == player.opponent { return -1_000_000 }
        if game.isDraw { return 0 }

        var score = 0
        for row in 0..<GomokuGame.size {
            for col in 0..<GomokuGame.size {
                for direction in Self.directions {
                    let cells = (0..<GomokuGame.stonesToWin).map { offset in
                        (row + direction.0 * offset, col + direction.1 * offset)
                    }
                    guard cells.allSatisfy({ inBounds(row: $0.0, col: $0.1) }) else { continue }
                    let stones = cells.map { game.stone(row: $0.0, col: $0.1) }
                    score += scoreWindow(stones)
                }
            }
        }

        return score
    }

    private func scoreWindow(_ stones: [GomokuPlayer?]) -> Int {
        let mine = stones.filter { $0 == player }.count
        let theirs = stones.filter { $0 == player.opponent }.count
        let empty = stones.filter { $0 == nil }.count

        if mine > 0 && theirs > 0 { return 0 }
        if mine == 5 { return 1_000_000 }
        if theirs == 5 { return -1_000_000 }
        if mine == 4 && empty == 1 { return 22_000 }
        if theirs == 4 && empty == 1 { return -26_000 }
        if mine == 3 && empty == 2 { return 1_500 }
        if theirs == 3 && empty == 2 { return -1_800 }
        if mine == 2 && empty == 3 { return 120 }
        if theirs == 2 && empty == 3 { return -140 }
        if mine == 1 && empty == 4 { return 8 }
        if theirs == 1 && empty == 4 { return -9 }
        return 0
    }

    private func candidateMoves(in game: GomokuGame, limit: Int) -> [GomokuPoint] {
        var occupied: [GomokuPoint] = []
        for row in 0..<GomokuGame.size {
            for col in 0..<GomokuGame.size where game.stone(row: row, col: col) != nil {
                occupied.append(GomokuPoint(row: row, col: col))
            }
        }

        guard !occupied.isEmpty else {
            return [GomokuPoint(row: GomokuGame.size / 2, col: GomokuGame.size / 2)]
        }

        var candidates = Set<GomokuPoint>()
        for stone in occupied {
            for row in max(0, stone.row - 2)...min(GomokuGame.size - 1, stone.row + 2) {
                for col in max(0, stone.col - 2)...min(GomokuGame.size - 1, stone.col + 2) where game.stone(row: row, col: col) == nil {
                    candidates.insert(GomokuPoint(row: row, col: col))
                }
            }
        }

        return candidates
            .sorted { lhs, rhs in
                let left = movePriority(lhs, in: game, for: game.currentPlayer)
                let right = movePriority(rhs, in: game, for: game.currentPlayer)
                if left != right { return left > right }
                if lhs.row != rhs.row { return lhs.row < rhs.row }
                return lhs.col < rhs.col
            }
            .prefix(limit)
            .map { $0 }
    }

    private func winningMove(for candidate: GomokuPlayer, in game: GomokuGame, candidates: [GomokuPoint]) -> GomokuPoint? {
        let ordered = candidates.sorted { lhs, rhs in
            let left = movePriority(lhs, in: game, for: candidate)
            let right = movePriority(rhs, in: game, for: candidate)
            if left != right { return left > right }
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.col < rhs.col
        }

        for move in ordered {
            var next = GomokuGame(board: game.board, currentPlayer: candidate)
            guard next.placeStone(row: move.row, col: move.col), next.winner == candidate else { continue }
            return move
        }
        return nil
    }

    private func movePriority(_ move: GomokuPoint, in game: GomokuGame, for current: GomokuPlayer) -> Int {
        let own = linePotential(at: move, in: game, for: current)
        let block = linePotential(at: move, in: game, for: current.opponent)
        return own * 3 + block * 2 + centerScore(move)
    }

    private func linePotential(at move: GomokuPoint, in game: GomokuGame, for candidate: GomokuPlayer) -> Int {
        var best = 0
        for direction in Self.directions {
            let forward = contiguousCount(from: move, delta: direction, in: game, for: candidate)
            let backward = contiguousCount(from: move, delta: (-direction.0, -direction.1), in: game, for: candidate)
            let openForward = openEnd(from: move, delta: direction, distance: forward + 1, in: game)
            let openBackward = openEnd(from: move, delta: (-direction.0, -direction.1), distance: backward + 1, in: game)
            let count = 1 + forward + backward
            let openEnds = (openForward ? 1 : 0) + (openBackward ? 1 : 0)
            best = max(best, patternScore(count: count, openEnds: openEnds))
        }
        return best
    }

    private func contiguousCount(from move: GomokuPoint,
                                 delta: (Int, Int),
                                 in game: GomokuGame,
                                 for candidate: GomokuPlayer) -> Int {
        var count = 0
        var row = move.row + delta.0
        var col = move.col + delta.1
        while inBounds(row: row, col: col), game.stone(row: row, col: col) == candidate {
            count += 1
            row += delta.0
            col += delta.1
        }
        return count
    }

    private func openEnd(from move: GomokuPoint, delta: (Int, Int), distance: Int, in game: GomokuGame) -> Bool {
        let row = move.row + delta.0 * distance
        let col = move.col + delta.1 * distance
        return inBounds(row: row, col: col) && game.stone(row: row, col: col) == nil
    }

    private func patternScore(count: Int, openEnds: Int) -> Int {
        if count >= 5 { return 100_000 }
        if count == 4 { return openEnds == 2 ? 18_000 : 9_000 }
        if count == 3 { return openEnds == 2 ? 1_200 : 450 }
        if count == 2 { return openEnds == 2 ? 120 : 45 }
        return openEnds == 2 ? 8 : 3
    }

    private func centerScore(_ move: GomokuPoint) -> Int {
        let center = GomokuGame.size / 2
        return 40 - abs(move.row - center) - abs(move.col - center)
    }

    private func candidateLimit(forELO elo: Int) -> Int {
        let e = min(2400, max(600, elo))
        switch e {
        case ..<900: return 8
        case 900..<1300: return 10
        case 1300..<1700: return 14
        case 1700..<2100: return 18
        default: return 24
        }
    }

    private func inBounds(row: Int, col: Int) -> Bool {
        (0..<GomokuGame.size).contains(row) && (0..<GomokuGame.size).contains(col)
    }

    private static let directions: [(Int, Int)] = [
        (0, 1),
        (1, 0),
        (1, 1),
        (1, -1)
    ]
}
