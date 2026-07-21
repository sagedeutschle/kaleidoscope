import SwiftUI

enum TTMark: String, Equatable {
    case x = "X"
    case o = "O"
}

/// Tic-tac-toe with an optimal minimax opponent. Pure value type — unit-tested.
struct TicTacToe: Equatable {
    private(set) var cells: [TTMark?]
    private(set) var current: TTMark

    init() {
        cells = Array(repeating: nil, count: 9)
        current = .x
    }

    static let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    var winner: TTMark? { Self.winner(in: cells) }
    var isFull: Bool { !cells.contains(nil) }
    var isOver: Bool { winner != nil || isFull }

    mutating func play(_ index: Int) {
        guard cells.indices.contains(index), cells[index] == nil, !isOver else { return }
        cells[index] = current
        current = Self.other(current)
    }

    mutating func reset() {
        cells = Array(repeating: nil, count: 9)
        current = .x
    }

    /// Optimal move for `mark` via minimax; nil when the game is already over.
    func bestMove(for mark: TTMark) -> Int? {
        guard !isOver else { return nil }
        var bestScore = Int.min
        var bestIndex: Int?
        for i in cells.indices where cells[i] == nil {
            var next = cells
            next[i] = mark
            let score = Self.minimax(next, ai: mark, turn: Self.other(mark), maximizing: false, depth: 1)
            if score > bestScore {
                bestScore = score
                bestIndex = i
            }
        }
        return bestIndex
    }

    static func other(_ mark: TTMark) -> TTMark { mark == .x ? .o : .x }

    static func winner(in cells: [TTMark?]) -> TTMark? {
        for line in lines {
            if let mark = cells[line[0]], cells[line[1]] == mark, cells[line[2]] == mark {
                return mark
            }
        }
        return nil
    }

    static func minimax(_ cells: [TTMark?], ai: TTMark, turn: TTMark, maximizing: Bool, depth: Int) -> Int {
        if let w = winner(in: cells) { return w == ai ? (10 - depth) : (depth - 10) }
        if !cells.contains(nil) { return 0 }
        var best = maximizing ? Int.min : Int.max
        for i in cells.indices where cells[i] == nil {
            var next = cells
            next[i] = turn
            let score = minimax(next, ai: ai, turn: other(turn), maximizing: !maximizing, depth: depth + 1)
            best = maximizing ? Swift.max(best, score) : Swift.min(best, score)
        }
        return best
    }
}

struct TicTacToeView: View {
    @State private var game = TicTacToe()
    private let human: TTMark = .x
    private let ai: TTMark = .o

    var body: some View {
        ZStack {
            CiceroTheme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(status)
                    .font(CiceroTheme.ui(20, weight: .semibold))
                    .foregroundStyle(CiceroTheme.ink)

                board

                Button {
                    withAnimation { game.reset() }
                } label: {
                    Label("New game", systemImage: "arrow.counterclockwise")
                        .font(CiceroTheme.ui(15, weight: .medium))
                }
                .tint(CiceroTheme.accent)
            }
            .padding()
        }
        .navigationTitle("Tic-Tac-Toe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var board: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        cell(row * 3 + col)
                    }
                }
            }
        }
    }

    private func cell(_ index: Int) -> some View {
        Button {
            tap(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(CiceroTheme.surfaceHi)
                if let mark = game.cells[index] {
                    Text(mark.rawValue)
                        .font(CiceroTheme.mono(44, weight: .bold))
                        .foregroundStyle(mark == human ? CiceroTheme.accent : CiceroTheme.accent2)
                }
            }
            .frame(width: 92, height: 92)
        }
        .disabled(game.cells[index] != nil || game.isOver)
    }

    private var status: String {
        if let w = game.winner { return w == human ? "You win! 🎉" : "Cicero wins." }
        if game.isFull { return "Draw." }
        return "Your move (\(human.rawValue))"
    }

    private func tap(_ index: Int) {
        guard game.current == human, game.cells[index] == nil, !game.isOver else { return }
        withAnimation(.easeOut(duration: 0.12)) { game.play(index) }
        if !game.isOver, game.current == ai, let move = game.bestMove(for: ai) {
            withAnimation(.easeOut(duration: 0.12)) { game.play(move) }
        }
    }
}
