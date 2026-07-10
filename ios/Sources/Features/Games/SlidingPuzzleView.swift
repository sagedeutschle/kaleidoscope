import SwiftUI

struct SlidingPuzzleView: View {
    private static let accent = Color(red: 0.30, green: 0.50, blue: 0.70)
    private let accountID: UUID?

    @StateObject private var persistence = PersistedGameSession<SlidingPuzzleSnapshot>(gameID: .slidingPuzzle)
    @State private var game = SlidingPuzzle.shuffled(seed: 1)
    @State private var moves = 0
    @State private var seed: UInt64 = 1

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "Sliding Puzzle",
                systemImage: "square.grid.3x3.fill",
                accent: Self.accent,
                subtitle: game.isSolved ? "Solved!" : "Order 1-15"
            ) {
                StatBadge(label: "Moves", value: "\(moves)", accent: Self.accent)
            }

            board

            HStack(spacing: 12) {
                Button {
                    newGame()
                } label: {
                    Label("New Game", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: Self.accent))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(Self.accent)
        .navigationTitle("Sliding Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: moves)
        .sensoryFeedback(.success, trigger: game.isSolved)
        .onChange(of: game.isSolved) { _, solved in
            if solved { LeaderboardCoordinator.shared.submit(.slidingPuzzle, score: moves) }
        }
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
        }
        .onDisappear { save(forceCloud: true) }
    }

    private var board: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let spacing: CGFloat = 8
            let cell = (side - spacing * 5) / 4

            VStack(spacing: spacing) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { col in
                            let index = row * 4 + col
                            tileView(at: index, size: cell)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(16)
        .prismetCard()
    }

    @ViewBuilder
    private func tileView(at index: Int, size: CGFloat) -> some View {
        let value = game.tiles[index]
        if value == 0 {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PrismetDesign.ground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PrismetDesign.hairline, lineWidth: 1)
                )
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PrismetDesign.panelHi)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Self.accent.opacity(0.55), lineWidth: 1.5)
                )
                .overlay(
                    Text("\(value)")
                        .font(PrismetDesign.rounded(min(size * 0.42, 30)))
                        .foregroundStyle(PrismetDesign.ink)
                )
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        if game.moveTile(at: index) {
                            moves += 1
                            save(forceCloud: game.isSolved)
                        }
                    }
                }
        }
    }

    private func newGame() {
        seed &+= 1
        withAnimation(.easeInOut(duration: 0.3)) {
            game = SlidingPuzzle.shuffled(seed: seed)
            moves = 0
        }
        save(forceCloud: true)
    }

    private func snapshot() -> SlidingPuzzleSnapshot {
        SlidingPuzzleSnapshot(game: game, moves: moves, seed: seed)
    }

    private func restore(_ snapshot: SlidingPuzzleSnapshot) {
        game = snapshot.game
        moves = snapshot.moves
        seed = snapshot.seed
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: moves, forceCloud: forceCloud)
    }
}
