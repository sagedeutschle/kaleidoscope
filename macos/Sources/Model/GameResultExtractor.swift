import Foundation

enum GameResultExtractor {
    static func result(for game: Game2048, completedAt: Date = Date()) -> GameResult? {
        guard game.hasWon || game.isGameOver else { return nil }

        return GameResult(id: UUID(),
                          facetID: "2048",
                          mode: "standard",
                          outcome: game.hasWon ? .won : .lost,
                          score: Int64(game.score),
                          durationSeconds: nil,
                          moveCount: nil,
                          completedAt: completedAt,
                          metadata: [
                            "boardSize": "\(game.size)",
                            "maxTile": "\(game.grid.max() ?? 0)"
                          ])
    }

    static func result(for game: SnakeGame, completedAt: Date = Date()) -> GameResult? {
        guard game.status == .lost else { return nil }

        return GameResult(id: UUID(),
                          facetID: "snake",
                          mode: "standard",
                          outcome: .lost,
                          score: Int64(game.score),
                          durationSeconds: nil,
                          moveCount: nil,
                          completedAt: completedAt,
                          metadata: [
                            "length": "\(game.body.count)",
                            "board": "\(game.width)x\(game.height)"
                          ])
    }

    static func result(for game: ConnectFourGame, completedAt: Date = Date()) -> GameResult? {
        guard game.winner != nil || game.isDraw else { return nil }

        let redTokens = game.tokenCount(for: .red)
        let yellowTokens = game.tokenCount(for: .yellow)
        let remainingCells = max(0, game.rows * game.columns - game.moveCount)
        let score = game.winner == nil ? 0 : abs(redTokens - yellowTokens) * 100 + remainingCells

        return GameResult(id: UUID(),
                          facetID: "connect-four",
                          mode: "standard",
                          outcome: game.winner == nil ? .completed : .won,
                          score: Int64(score),
                          durationSeconds: nil,
                          moveCount: game.moveCount,
                          completedAt: completedAt,
                          metadata: [
                            "winner": game.winner?.rawValue ?? "Draw",
                            "redTokens": "\(redTokens)",
                            "yellowTokens": "\(yellowTokens)"
                          ])
    }

    static func result(for game: CheckersGame, completedAt: Date = Date()) -> GameResult? {
        guard let winner = game.winner else { return nil }

        let darkPieces = game.count(for: .dark)
        let lightPieces = game.count(for: .light)
        let winnerPieces = winner == .dark ? darkPieces : lightPieces
        let loserPieces = winner == .dark ? lightPieces : darkPieces
        let winnerKings = game.board.compactMap { $0 }
            .filter { $0.player == winner && $0.kind == .king }
            .count
        let score = max(0, winnerPieces - loserPieces) * 100 + winnerKings * 25

        return GameResult(id: UUID(),
                          facetID: "checkers",
                          mode: "standard",
                          outcome: .won,
                          score: Int64(score),
                          durationSeconds: nil,
                          moveCount: nil,
                          completedAt: completedAt,
                          metadata: [
                            "winner": winner.rawValue,
                            "darkPieces": "\(darkPieces)",
                            "lightPieces": "\(lightPieces)",
                            "darkKings": "\(game.board.compactMap { $0 }.filter { $0.player == .dark && $0.kind == .king }.count)",
                            "lightKings": "\(game.board.compactMap { $0 }.filter { $0.player == .light && $0.kind == .king }.count)"
                          ])
    }
}
