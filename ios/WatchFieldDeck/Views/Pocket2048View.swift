import SwiftUI
import WatchKit
import WatchFieldDeckCore

struct Pocket2048View: View {
    private static let saveKey = "prismet.fieldDeck.game.2048"

    @State private var game: Pocket2048
    @AppStorage("prismet.fieldDeck.game.2048.best") private var bestScore = 0

    init() {
        _game = State(
            initialValue: GamePersistence.load(
                Pocket2048.self,
                key: Self.saveKey,
                default: Pocket2048.newGame(seed: Self.freshSeed())
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                scoreStrip
                board
                directionPad

                if game.hasWon || game.isGameOver {
                    FieldDeckCard {
                        Text(game.hasWon ? "2048 REACHED" : "NO MOVES LEFT")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(game.hasWon ? WatchTheme.mint : Color.red)
                        Button("New Board") { restart() }
                            .buttonStyle(.borderedProminent)
                            .tint(WatchTheme.gold)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle("Pocket 2048")
    }

    private var scoreStrip: some View {
        HStack(spacing: 6) {
            statBox(label: "SCORE", value: game.score)
            statBox(label: "BEST", value: bestScore)
        }
    }

    private var board: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 3
            let tile = (geometry.size.width - spacing * 3) / 4
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(tile), spacing: spacing), count: 4),
                spacing: spacing
            ) {
                ForEach(game.grid.indices, id: \.self) { index in
                    let value = game.grid[index]
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tileColor(value))
                        .overlay {
                            if value > 0 {
                                Text("\(value)")
                                    .font(.system(size: value >= 1024 ? 10 : 13, weight: .black, design: .rounded))
                                    .foregroundStyle(value <= 4 ? WatchTheme.navy : .white)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .frame(width: tile, height: tile)
                        .accessibilityLabel(value == 0 ? "Empty tile" : "Tile \(value)")
                }
            }
        }
        .frame(height: 172)
        .padding(4)
        .background(WatchTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var directionPad: some View {
        VStack(spacing: 5) {
            DirectionButton(symbol: "arrow.up", label: "Move up") { move(.up) }
            HStack(spacing: 5) {
                DirectionButton(symbol: "arrow.left", label: "Move left") { move(.left) }
                DirectionButton(symbol: "arrow.down", label: "Move down") { move(.down) }
                DirectionButton(symbol: "arrow.right", label: "Move right") { move(.right) }
            }
        }
    }

    private func statBox(label: String, value: Int) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(WatchTheme.muted)
            Text("\(value)")
                .font(.system(.headline, design: .rounded, weight: .black))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(WatchTheme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func move(_ direction: Pocket2048.Direction) {
        guard game.move(direction) else {
            WKInterfaceDevice.current().play(.retry)
            return
        }
        bestScore = max(bestScore, game.score)
        GamePersistence.save(game, key: Self.saveKey)
        WKInterfaceDevice.current().play(game.hasWon ? .success : .click)
    }

    private func restart() {
        game = .newGame(seed: Self.freshSeed())
        GamePersistence.save(game, key: Self.saveKey)
        WKInterfaceDevice.current().play(.start)
    }

    private func tileColor(_ value: Int) -> Color {
        switch value {
        case 0: WatchTheme.panelRaised.opacity(0.55)
        case 2: Color(hex: "D7E3ED")
        case 4: Color(hex: "B9D4DF")
        case 8: Color(hex: "ECA85C")
        case 16: Color(hex: "F08B4B")
        case 32: Color(hex: "EC6557")
        case 64: Color(hex: "DA3F54")
        case 128: Color(hex: "E5C85C")
        case 256: WatchTheme.gold
        case 512: Color(hex: "D9AD36")
        case 1024: Color(hex: "B687F1")
        default: Color(hex: "7C4DFF")
        }
    }

    private static func freshSeed() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000)
    }
}

private struct DirectionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(WatchTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
