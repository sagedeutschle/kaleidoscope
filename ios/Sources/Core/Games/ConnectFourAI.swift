import Foundation

struct ConnectFourAI {
    var player: ConnectFourPlayer
    var targetELO: Int

    init(player: ConnectFourPlayer = .yellow, targetELO: Int = 1200) {
        self.player = player
        self.targetELO = min(2400, max(600, targetELO))
    }

    static func searchDepth(forELO elo: Int) -> Int {
        let e = min(2400, max(600, elo))
        switch e {
        case ..<800: return 1
        case 800..<1100: return 2
        case 1100..<1450: return 3
        case 1450..<1800: return 4
        case 1800..<2200: return 5
        default: return 6
        }
    }

    func move(in game: ConnectFourGame) -> Int? {
        guard game.currentPlayer == player, !game.isGameOver else { return nil }
        let legalColumns = orderedColumns(game.legalColumns)
        guard !legalColumns.isEmpty else { return nil }

        if let win = winningColumn(for: player, in: game, orderedLegalColumns: legalColumns) {
            return win
        }
        if let block = winningColumn(for: player.opponent, in: game, orderedLegalColumns: legalColumns) {
            return block
        }

        let depth = Self.searchDepth(forELO: targetELO)
        var bestColumn = legalColumns[0]
        var bestScore = Int.min

        for column in legalColumns {
            var next = game
            guard next.dropToken(in: column) else { continue }
            let score = minimax(next, depth: depth - 1, alpha: Int.min / 4, beta: Int.max / 4)
            if score > bestScore || (score == bestScore && tieBreak(column) > tieBreak(bestColumn)) {
                bestScore = score
                bestColumn = column
            }
        }

        return bestColumn
    }

    private func minimax(_ game: ConnectFourGame, depth: Int, alpha: Int, beta: Int) -> Int {
        if game.isGameOver || depth == 0 {
            return evaluate(game, remainingDepth: depth)
        }

        let legalColumns = orderedColumns(game.legalColumns)
        guard !legalColumns.isEmpty else { return evaluate(game, remainingDepth: depth) }

        if game.currentPlayer == player {
            var alpha = alpha
            var best = Int.min / 4
            for column in legalColumns {
                var next = game
                guard next.dropToken(in: column) else { continue }
                best = max(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var beta = beta
            var best = Int.max / 4
            for column in legalColumns {
                var next = game
                guard next.dropToken(in: column) else { continue }
                best = min(best, minimax(next, depth: depth - 1, alpha: alpha, beta: beta))
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    private func evaluate(_ game: ConnectFourGame, remainingDepth: Int) -> Int {
        if game.winner == player { return 1_000_000 + remainingDepth }
        if game.winner == player.opponent { return -1_000_000 - remainingDepth }
        if game.isDraw { return 0 }

        var score = 0
        let center = ConnectFourGame.columnCount / 2
        score += game.tokenCount(for: player) - game.tokenCount(for: player.opponent)
        score += columnTokenCount(center, in: game, for: player) * 14
        score -= columnTokenCount(center, in: game, for: player.opponent) * 14

        for row in 0..<ConnectFourGame.rowCount {
            for column in 0..<ConnectFourGame.columnCount {
                for direction in Self.directions {
                    let cells = (0..<4).map { offset in
                        (row + direction.0 * offset, column + direction.1 * offset)
                    }
                    guard cells.allSatisfy({ cell in
                        (0..<ConnectFourGame.rowCount).contains(cell.0)
                            && (0..<ConnectFourGame.columnCount).contains(cell.1)
                    }) else { continue }
                    score += scoreWindow(cells.map { game.token(row: $0.0, column: $0.1) })
                }
            }
        }

        return score
    }

    private func scoreWindow(_ window: [ConnectFourPlayer?]) -> Int {
        let mine = window.filter { $0 == player }.count
        let theirs = window.filter { $0 == player.opponent }.count
        let empty = window.filter { $0 == nil }.count

        if mine > 0 && theirs > 0 { return 0 }
        if mine == 4 { return 100_000 }
        if theirs == 4 { return -100_000 }
        if mine == 3 && empty == 1 { return 850 }
        if theirs == 3 && empty == 1 { return -950 }
        if mine == 2 && empty == 2 { return 110 }
        if theirs == 2 && empty == 2 { return -130 }
        if mine == 1 && empty == 3 { return 8 }
        if theirs == 1 && empty == 3 { return -9 }
        return 0
    }

    private func winningColumn(for candidate: ConnectFourPlayer,
                               in game: ConnectFourGame,
                               orderedLegalColumns: [Int]) -> Int? {
        for column in orderedLegalColumns {
            var next = ConnectFourGame(board: game.board, currentPlayer: candidate)
            guard next.dropToken(in: column), next.winner == candidate else { continue }
            return column
        }
        return nil
    }

    private func columnTokenCount(_ column: Int, in game: ConnectFourGame, for player: ConnectFourPlayer) -> Int {
        (0..<ConnectFourGame.rowCount).filter { game.token(row: $0, column: column) == player }.count
    }

    private func orderedColumns(_ columns: [Int]) -> [Int] {
        columns.sorted { tieBreak($0) > tieBreak($1) }
    }

    private func tieBreak(_ column: Int) -> Int {
        ConnectFourGame.columnCount - abs(column - ConnectFourGame.columnCount / 2)
    }

    private static let directions: [(Int, Int)] = [
        (0, 1),
        (1, 0),
        (1, 1),
        (1, -1)
    ]
}
