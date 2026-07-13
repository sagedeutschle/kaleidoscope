import SwiftUI
import WatchKit
import WatchFieldDeckCore

struct PocketLightsOutView: View {
    private static let saveKey = "prismet.fieldDeck.game.lightsOut"

    @State private var game: PocketLightsOut

    init() {
        _game = State(
            initialValue: GamePersistence.load(
                PocketLightsOut.self,
                key: Self.saveKey,
                default: PocketLightsOut.newPuzzle(seed: Self.freshSeed())
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SIGNAL GRID")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(WatchTheme.cyan)
                        Text("\(game.litCount) lights remain")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    Text("\(game.moveCount)")
                        .font(.system(.title3, design: .monospaced, weight: .black))
                        .accessibilityLabel("\(game.moveCount) moves")
                }
                .padding(.horizontal, 3)

                board

                if game.isSolved {
                    Text("GRID CLEARED")
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .foregroundStyle(WatchTheme.mint)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(WatchTheme.mint.opacity(0.12), in: Capsule())
                        .accessibilityAddTraits(.isHeader)
                }

                Button("New Puzzle") { newPuzzle() }
                    .buttonStyle(.borderedProminent)
                    .tint(WatchTheme.cyan)
                    .accessibilityHint("Creates a new solvable Lights Out grid")
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle("Lights Out")
    }

    private var board: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 4
            let side = (geometry.size.width - spacing * 4) / 5
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: 5),
                spacing: spacing
            ) {
                ForEach(0..<25, id: \.self) { index in
                    let row = index / 5
                    let column = index % 5
                    let lit = game.isLit(row: row, col: column)
                    Button {
                        press(row: row, column: column)
                    } label: {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(lit ? WatchTheme.cyan : WatchTheme.panel)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(
                                        lit ? Color.white.opacity(0.85) : WatchTheme.muted.opacity(0.28),
                                        lineWidth: lit ? 2 : 1
                                    )
                            }
                            .overlay {
                                Image(systemName: lit ? "lightbulb.fill" : "circle")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(lit ? WatchTheme.navy : WatchTheme.muted.opacity(0.5))
                            }
                            .frame(width: side, height: side)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "Row \(row + 1), column \(column + 1), \(lit ? "lit" : "unlit")"
                    )
                    .accessibilityHint("Toggles this light and its neighbors")
                }
            }
        }
        .frame(height: 176)
        .padding(5)
        .background(WatchTheme.panelRaised.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func press(row: Int, column: Int) {
        let wasSolved = game.isSolved
        game.press(row: row, col: column)
        GamePersistence.save(game, key: Self.saveKey)
        WKInterfaceDevice.current().play(!wasSolved && game.isSolved ? .success : .click)
    }

    private func newPuzzle() {
        game = .newPuzzle(seed: Self.freshSeed())
        GamePersistence.save(game, key: Self.saveKey)
        WKInterfaceDevice.current().play(.start)
    }

    private static func freshSeed() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000) &+ 0x1A17
    }
}
