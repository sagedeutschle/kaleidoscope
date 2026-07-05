import Foundation

enum CrazyEightMove: Equatable {
    case play(Card, declaredSuit: Suit?)
    case draw
}

struct CrazyEightAI {
    var player: CrazyEightPlayer
    var targetELO: Int

    init(player: CrazyEightPlayer = .guest, targetELO: Int = 1200) {
        self.player = player
        self.targetELO = min(2400, max(600, targetELO))
    }

    static func searchDepth(forELO elo: Int) -> Int {
        switch min(2400, max(600, elo)) {
        case ..<900: return 1
        case 900..<1300: return 2
        case 1300..<1700: return 3
        case 1700..<2100: return 4
        default: return 5
        }
    }

    func move(in game: CrazyEightGame) -> CrazyEightMove? {
        guard game.currentPlayer == player, !game.isGameOver else { return nil }
        let candidates = legalMoves(in: game)
        guard !candidates.isEmpty else { return nil }

        return candidates.max { lhs, rhs in
            score(lhs, in: game) < score(rhs, in: game)
        }
    }

    private func score(_ move: CrazyEightMove, in game: CrazyEightGame) -> Int {
        var next = game
        apply(move, to: &next)
        if next.winner == player { return 50_000 }
        if next.winner == player.opponent { return -50_000 }

        let depth = Self.searchDepth(forELO: targetELO) - 1
        return tacticalScore(move, in: game) + minimax(next, depth: depth, alpha: -60_000, beta: 60_000)
    }

    private func minimax(_ game: CrazyEightGame, depth: Int, alpha: Int, beta: Int) -> Int {
        if game.winner == player { return 50_000 + depth }
        if game.winner == player.opponent { return -50_000 - depth }
        if depth == 0 { return evaluate(game) }

        let moves = legalMoves(in: game)
        guard !moves.isEmpty else { return evaluate(game) }

        if game.currentPlayer == player {
            var alpha = alpha
            var best = -60_000
            for move in moves {
                var next = game
                apply(move, to: &next)
                let score = minimax(next, depth: depth - 1, alpha: alpha, beta: beta)
                best = max(best, score)
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var beta = beta
            var best = 60_000
            for move in moves {
                var next = game
                apply(move, to: &next)
                let score = minimax(next, depth: depth - 1, alpha: alpha, beta: beta)
                best = min(best, score)
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    private func legalMoves(in game: CrazyEightGame) -> [CrazyEightMove] {
        let playable = game.hand(for: game.currentPlayer)
            .filter { game.canPlay($0) }
            .map { card in
                CrazyEightMove.play(card, declaredSuit: card.rank == .eight ? declaredSuit(afterPlaying: card, in: game) : nil)
            }

        if !playable.isEmpty { return playable }
        return game.drawPile.isEmpty && game.discardPile.count <= 1 ? [] : [.draw]
    }

    private func apply(_ move: CrazyEightMove, to game: inout CrazyEightGame) {
        switch move {
        case .play(let card, let declaredSuit):
            _ = game.playCard(card, declaredSuit: declaredSuit)
        case .draw:
            _ = game.drawCard()
        }
    }

    private func tacticalScore(_ move: CrazyEightMove, in game: CrazyEightGame) -> Int {
        switch move {
        case .draw:
            return -60
        case .play(let card, let declaredSuit):
            var score = 80
            if card.rank == .eight { score += 120 }
            if let declaredSuit {
                score += game.hand(for: game.currentPlayer).filter { $0.suit == declaredSuit }.count * 18
            }
            if game.hand(for: game.currentPlayer).count == 1 { score += 1_000 }
            return score
        }
    }

    private func evaluate(_ game: CrazyEightGame) -> Int {
        let ownHand = game.hand(for: player)
        let opponentHand = game.hand(for: player.opponent)
        var score = (opponentHand.count - ownHand.count) * 160
        score += playableCount(for: player, in: game) * 28
        score -= playableCount(for: player.opponent, in: game) * 22
        score += ownHand.filter { $0.rank == .eight }.count * 60
        score -= opponentHand.filter { $0.rank == .eight }.count * 45
        if game.currentPlayer == player { score += 20 } else { score -= 20 }
        return score
    }

    private func playableCount(for side: CrazyEightPlayer, in game: CrazyEightGame) -> Int {
        game.hand(for: side).filter { game.canPlay($0) }.count
    }

    private func declaredSuit(afterPlaying card: Card, in game: CrazyEightGame) -> Suit {
        let remaining = game.hand(for: game.currentPlayer).filter { $0 != card }
        guard !remaining.isEmpty else { return card.suit }

        return Suit.allCases.max { lhs, rhs in
            let lhsScore = suitScore(lhs, in: remaining)
            let rhsScore = suitScore(rhs, in: remaining)
            if lhsScore == rhsScore {
                return lhs.rawValue > rhs.rawValue
            }
            return lhsScore < rhsScore
        } ?? card.suit
    }

    private func suitScore(_ suit: Suit, in hand: [Card]) -> Int {
        hand.filter { $0.suit == suit }.reduce(0) { total, card in
            total + 10 + card.rank.rawValue
        }
    }
}
