import SwiftUI
import WatchKit
import WatchFieldDeckCore

struct CatanHarvestView: View {
    private static let saveKey = "prismet.fieldDeck.game.catanHarvest"

    @State private var game: CatanHarvest
    @State private var eventText = "Roll to gather the first harvest."

    init() {
        _game = State(
            initialValue: GamePersistence.load(
                CatanHarvest.self,
                key: Self.saveKey,
                default: CatanHarvest(seed: Self.freshSeed())
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                progressCard
                diceRow

                Text(eventText)
                    .font(.caption)
                    .foregroundStyle(WatchTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 32)
                    .accessibilityLabel("Last harvest event: \(eventText)")

                HStack(spacing: 7) {
                    Button {
                        roll()
                    } label: {
                        Label("Roll", systemImage: "dice.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WatchTheme.gold)
                    .disabled(game.didWin)
                    .accessibilityLabel("Roll dice")

                    Button {
                        bank()
                    } label: {
                        Label("Bank", systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(WatchTheme.mint)
                    .disabled(game.unbanked == 0 || game.didWin)
                    .accessibilityLabel("Bank harvest")
                }

                if game.didWin {
                    FieldDeckCard {
                        Text("SETTLEMENT SECURED")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(WatchTheme.mint)
                        Text("You banked \(game.banked) harvest.")
                            .font(.caption2)
                            .foregroundStyle(WatchTheme.muted)
                        Button("New Harvest") { restart() }
                            .buttonStyle(.borderedProminent)
                            .tint(WatchTheme.mint)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle("Catan Harvest")
        .onAppear { restoreEventText() }
    }

    private var progressCard: some View {
        FieldDeckCard {
            HStack {
                harvestStat(label: "BANKED", value: game.banked, color: WatchTheme.mint)
                Divider().overlay(Color.white.opacity(0.12))
                harvestStat(label: "AT RISK", value: game.unbanked, color: WatchTheme.gold)
            }
            ProgressView(value: Double(game.banked), total: Double(CatanHarvest.winningHarvest))
                .tint(WatchTheme.mint)
            Text("Goal \(CatanHarvest.winningHarvest)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchTheme.muted)
        }
    }

    private var diceRow: some View {
        HStack(spacing: 10) {
            die(game.lastDice?.first)
            die(game.lastDice?.second)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            game.lastDice.map { "Dice show \($0.first) and \($0.second), total \($0.total)" }
                ?? "Dice have not been rolled"
        )
    }

    private func die(_ value: Int?) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white)
            .overlay {
                Text(value.map(String.init) ?? "–")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(WatchTheme.navy)
            }
            .frame(width: 66, height: 58)
            .shadow(color: WatchTheme.gold.opacity(0.2), radius: 6)
    }

    private func harvestStat(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
            Text("\(value)")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func roll() {
        let event = game.roll()
        eventText = describe(event)
        GamePersistence.save(game, key: Self.saveKey)
        switch event {
        case .productive:
            WKInterfaceDevice.current().play(game.didWin ? .success : .directionUp)
        case .robber:
            WKInterfaceDevice.current().play(.failure)
        case .barren:
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func bank() {
        let amount = game.bank()
        eventText = "Banked \(amount). \(CatanHarvest.winningHarvest - game.banked) to the goal."
        GamePersistence.save(game, key: Self.saveKey)
        WKInterfaceDevice.current().play(game.didWin ? .success : .notification)
    }

    private func restart() {
        game = CatanHarvest(seed: Self.freshSeed())
        eventText = "Roll to gather the first harvest."
        GamePersistence.save(game, key: Self.saveKey)
        WKInterfaceDevice.current().play(.start)
    }

    private func restoreEventText() {
        guard let event = game.lastEvent else { return }
        eventText = describe(event)
    }

    private func describe(_ event: HarvestEvent) -> String {
        switch event {
        case let .productive(total, gained):
            "Rolled \(total): +\(gained) harvest at risk."
        case let .robber(lost):
            "Robber! Lost \(lost) unbanked harvest."
        case let .barren(total):
            "Rolled \(total): quiet fields this turn."
        }
    }

    private static func freshSeed() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000) &+ 0xCA7A
    }
}
