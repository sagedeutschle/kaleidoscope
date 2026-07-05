import Foundation

struct SpiderCard: Codable, Equatable, Hashable {
    var card: Card
    var isFaceUp: Bool
}

struct SpiderGame: Codable, Equatable, Hashable {
    static let columnCount = 10
    static let stockRowCount = 5

    var tableau: [[SpiderCard]]
    private(set) var stockRows: [[Card]]
    private(set) var completedSets: Int
    private(set) var moves: Int

    init(
        tableau: [[SpiderCard]],
        stockRows: [[Card]],
        completedSets: Int = 0,
        moves: Int = 0
    ) {
        precondition(tableau.count == Self.columnCount, "Spider uses ten tableau columns.")
        self.tableau = tableau
        self.stockRows = stockRows
        self.completedSets = completedSets
        self.moves = moves
    }

    static func newGame(seed: UInt64) -> SpiderGame {
        var deck = oneSuitDeck()
        var rng = SeededGenerator(seed: seed)
        for index in stride(from: deck.count - 1, through: 1, by: -1) {
            deck.swapAt(index, rng.nextInt(upperBound: index + 1))
        }

        var next = 0
        var tableau: [[SpiderCard]] = []
        for column in 0..<Self.columnCount {
            let count = column < 4 ? 6 : 5
            var pile: [SpiderCard] = []
            for row in 0..<count {
                pile.append(SpiderCard(card: deck[next], isFaceUp: row == count - 1))
                next += 1
            }
            tableau.append(pile)
        }

        var stockRows: [[Card]] = []
        for _ in 0..<Self.stockRowCount {
            stockRows.append(Array(deck[next..<(next + Self.columnCount)]))
            next += Self.columnCount
        }

        return SpiderGame(tableau: tableau, stockRows: stockRows)
    }

    var isWon: Bool {
        completedSets == 8
    }

    @discardableResult
    mutating func dealRow() -> Bool {
        guard !stockRows.isEmpty, tableau.allSatisfy({ !$0.isEmpty }) else { return false }
        let row = stockRows.removeFirst()
        guard row.count == Self.columnCount else { return false }
        for index in 0..<Self.columnCount {
            tableau[index].append(SpiderCard(card: row[index], isFaceUp: true))
        }
        moves += 1
        collectCompletedRuns()
        return true
    }

    @discardableResult
    mutating func moveRun(from: Int, cardIndex: Int, to: Int) -> Bool {
        guard tableau.indices.contains(from),
              tableau.indices.contains(to),
              from != to,
              tableau[from].indices.contains(cardIndex)
        else { return false }

        let run = Array(tableau[from][cardIndex...])
        guard isMovableRun(run), let first = run.first, canPlace(first.card, on: to) else { return false }
        tableau[to].append(contentsOf: run)
        tableau[from].removeSubrange(cardIndex...)
        flipExposedCard(in: from)
        moves += 1
        collectCompletedRuns()
        return true
    }

    mutating func collectCompletedRuns() {
        let completeRanks = Rank.allCases.reversed().map(\.rawValue)
        for column in tableau.indices {
            guard tableau[column].count >= completeRanks.count else { continue }
            let suffixStart = tableau[column].count - completeRanks.count
            let suffix = Array(tableau[column][suffixStart...])
            guard suffix.allSatisfy(\.isFaceUp),
                  Set(suffix.map(\.card.suit)).count == 1,
                  suffix.map(\.card.rank.rawValue) == completeRanks
            else { continue }
            tableau[column].removeSubrange(suffixStart...)
            completedSets += 1
            flipExposedCard(in: column)
        }
    }

    private func canPlace(_ card: Card, on column: Int) -> Bool {
        guard let top = tableau[column].last else { return true }
        return top.isFaceUp && top.card.rank.rawValue == card.rank.rawValue + 1
    }

    private func isMovableRun(_ run: [SpiderCard]) -> Bool {
        guard !run.isEmpty, run.allSatisfy(\.isFaceUp) else { return false }
        guard run.count > 1 else { return true }
        for index in 1..<run.count {
            let previous = run[index - 1].card
            let current = run[index].card
            guard current.suit == previous.suit,
                  current.rank.rawValue == previous.rank.rawValue - 1
            else { return false }
        }
        return true
    }

    private mutating func flipExposedCard(in column: Int) {
        guard let last = tableau[column].indices.last, !tableau[column][last].isFaceUp else { return }
        tableau[column][last].isFaceUp = true
    }

    private static func oneSuitDeck() -> [Card] {
        Array(repeating: Rank.allCases.map { Card(rank: $0, suit: .spades) }, count: 8).flatMap { $0 }
    }
}
