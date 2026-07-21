import SwiftUI

/// Lights Out: tapping a cell toggles it and its orthogonal neighbors; clear the
/// board to win. Scrambles from a solved state so every start is solvable. Pure
/// value type — unit-tested (tapping the same cell twice is a no-op).
struct LightsOut: Equatable {
    let size: Int
    private(set) var grid: [Bool]
    private(set) var moves: Int

    init(size: Int = 5) {
        self.size = size
        grid = Array(repeating: false, count: size * size)
        moves = 0
        scramble()
    }

    var isSolved: Bool { !grid.contains(true) }

    func value(row: Int, col: Int) -> Bool { grid[row * size + col] }

    mutating func tap(row: Int, col: Int) {
        guard inBounds(row, col) else { return }
        press(row, col)
        moves += 1
    }

    mutating func scramble(taps: Int = 8) {
        grid = Array(repeating: false, count: size * size)
        moves = 0
        for _ in 0..<taps {
            press(Int.random(in: 0..<size), Int.random(in: 0..<size))
        }
        if isSolved { press(0, 0) } // never hand back an already-solved board
    }

    private mutating func press(_ row: Int, _ col: Int) {
        toggle(row, col)
        toggle(row - 1, col)
        toggle(row + 1, col)
        toggle(row, col - 1)
        toggle(row, col + 1)
    }

    private mutating func toggle(_ row: Int, _ col: Int) {
        guard inBounds(row, col) else { return }
        grid[row * size + col].toggle()
    }

    private func inBounds(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < size && col >= 0 && col < size
    }
}

struct LightsOutView: View {
    @State private var game = LightsOut()

    var body: some View {
        ZStack {
            CiceroTheme.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Text(game.isSolved ? "Solved in \(game.moves)! ✨" : "Moves: \(game.moves)")
                    .font(CiceroTheme.ui(20, weight: .semibold))
                    .foregroundStyle(game.isSolved ? CiceroTheme.good : CiceroTheme.ink)

                board

                Button {
                    withAnimation { game.scramble() }
                } label: {
                    Label("New board", systemImage: "shuffle")
                        .font(CiceroTheme.ui(15, weight: .medium))
                }
                .tint(CiceroTheme.accent)
            }
            .padding()
        }
        .navigationTitle("Lights Out")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var board: some View {
        VStack(spacing: 6) {
            ForEach(0..<game.size, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<game.size, id: \.self) { col in
                        Button {
                            withAnimation(.easeOut(duration: 0.1)) { game.tap(row: row, col: col) }
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(game.value(row: row, col: col) ? CiceroTheme.warn : CiceroTheme.surface)
                                .frame(width: 54, height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(CiceroTheme.border, lineWidth: 1))
                        }
                        .disabled(game.isSolved)
                    }
                }
            }
        }
    }
}
