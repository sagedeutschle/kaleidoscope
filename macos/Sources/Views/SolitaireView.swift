// PRISM: RELEASE Agent-Mac 2026-07-03 — mirrored iOS v10 "Green Baize Table" material (visual layer only; session/logic untouched). Build green.
import SwiftUI

// MARK: - Baize material ("The Green Baize Table")

/// Game-local material palette mirrored from the iOS v10 `SolitaireTheme` (emerald
/// felt). Visual only — card ranks/suits and all interaction come from the model.
private struct SolitaireTheme {
    static let accent = Color(red: 0.20, green: 0.45, blue: 0.30)
    static let felt = Color(red: 0.114, green: 0.353, blue: 0.224)
    static let feltDeep = Color(red: 0.075, green: 0.255, blue: 0.157)
    static let well = Color(red: 0.088, green: 0.290, blue: 0.180)

    // Card stock.
    static let ivory = Color(red: 0.976, green: 0.957, blue: 0.906)
    static let ivoryEdge = Color(red: 0.72, green: 0.67, blue: 0.55)
    static let cardRed = Color(red: 0.72, green: 0.14, blue: 0.18)
    static let cardInk = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let cardBackField = Color(red: 0.078, green: 0.224, blue: 0.161)
}

private enum SolitaireSelection: Equatable {
    case waste
    case tableau(pile: Int, index: Int)
}

private enum SolitaireModal: Identifiable {
    case result(GameResult)
    case leaderboard

    var id: String {
        switch self {
        case .result(let result): return "result-\(result.id.uuidString)"
        case .leaderboard:         return "leaderboard"
        }
    }
}

/// Klondike Solitaire facet. Tap a card to pick it up, tap a destination pile or
/// foundation to drop it; tap the stock to deal. Tap-driven so it works with both
/// a mouse and touch (mobile-ready).
struct SolitaireView: View {
    @StateObject private var session = SolitaireSession()
    @State private var selection: SolitaireSelection?
    @State private var modal: SolitaireModal?
    @State private var now = Date()

    private let accent = SolitaireTheme.accent
    private let leaderboardService = KaleidoscopeLeaderboardService.shared
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let cardW: CGFloat = 52
    private let cardH: CGFloat = 72
    private let fanUp: CGFloat = 26
    private let fanDown: CGFloat = 12

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(title: "Solitaire",
                       systemImage: "suit.spade.fill",
                       accent: accent,
                       subtitle: statusText) {
                HStack(spacing: 8) {
                    StatBadge(label: "Moves", value: "\(session.moves)", accent: accent)
                    StatBadge(label: "Time", value: elapsedLabel, accent: accent)
                }
            }
            .frame(maxWidth: 760)

            table
            controls
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .onReceive(ticker) { now = $0 }
        .onChange(of: session.isWon) { _, won in
            if won { presentResult() }
        }
        .sheet(item: $modal) { modal in
            switch modal {
            case .result(let result):
                ResultSlipView(result: result,
                               accent: accent,
                               onPlayAgain: { self.modal = nil; session.newGame(); selection = nil },
                               onLeaderboard: { self.modal = .leaderboard },
                               onDismiss: { self.modal = nil })
            case .leaderboard:
                LocalLeaderboardPanel(service: leaderboardService,
                                      facetID: "solitaire",
                                      mode: "standard",
                                      accent: accent)
            }
        }
    }

    // MARK: - Table

    private var table: some View {
        VStack(spacing: 18) {
            topRow
            tableauRow
        }
        .padding(18)
        .background(feltSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Kaleido.gold.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
    }

    /// The green baize: deep felt with a soft radial vignette and a warm sheen,
    /// mirroring the iOS emerald table.
    private var feltSurface: some View {
        ZStack {
            SolitaireTheme.felt
            RadialGradient(colors: [Color.white.opacity(0.06), .clear],
                           center: UnitPoint(x: 0.5, y: 0.2),
                           startRadius: 20, endRadius: 460)
            RadialGradient(colors: [.clear, SolitaireTheme.feltDeep.opacity(0.9)],
                           center: .center,
                           startRadius: 180, endRadius: 560)
        }
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            stockPile
            wastePile
            Spacer(minLength: 12)
            ForEach(Suit.allCases) { suit in
                foundationPile(suit)
            }
        }
    }

    private var stockPile: some View {
        Button {
            session.draw()
            selection = nil
        } label: {
            ZStack {
                cardSlot
                if !session.game.stock.isEmpty {
                    cardBack
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var wastePile: some View {
        Button {
            handleWasteTap()
        } label: {
            ZStack {
                cardSlot
                if let top = session.game.wasteTop {
                    cardFace(top, selected: selection == .waste)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func foundationPile(_ suit: Suit) -> some View {
        Button {
            handleFoundationTap()
        } label: {
            ZStack {
                cardSlot.overlay(
                    Text(suit.symbol)
                        .font(.title)
                        .foregroundStyle(suit.isRed ? SolitaireTheme.cardRed.opacity(0.42) : Color.white.opacity(0.32))
                )
                if let top = session.game.foundationTop(suit) {
                    cardFace(top, selected: false)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var tableauRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<SolitaireGame.pileCount, id: \.self) { pile in
                tableauColumn(pile)
            }
        }
    }

    private func tableauColumn(_ pile: Int) -> some View {
        let cards = session.game.tableau[pile]
        return ZStack(alignment: .top) {
            cardSlot
                .contentShape(Rectangle())
                .onTapGesture { handleTableauTap(pile: pile, index: nil) }
            ForEach(Array(cards.enumerated()), id: \.offset) { index, pileCard in
                cardButton(pileCard, pile: pile, index: index)
                    .offset(y: yOffset(cards, upTo: index))
            }
        }
        .frame(width: cardW, height: columnHeight(cards), alignment: .top)
    }

    private func cardButton(_ pileCard: SolitairePileCard, pile: Int, index: Int) -> some View {
        Button {
            handleTableauTap(pile: pile, index: index)
        } label: {
            if pileCard.isFaceUp {
                cardFace(pileCard.card, selected: isSelected(pile: pile, index: index))
            } else {
                cardBack
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card pieces

    /// A card well recessed into the felt — a darker patch pressed into the baize
    /// with a subtle inner shadow, mirroring the iOS wells.
    private var cardSlot: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(SolitaireTheme.well)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color.black.opacity(0.22), .clear],
                                         startPoint: .top, endPoint: .center))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.28), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
            .frame(width: cardW, height: cardH)
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.30, blue: 0.52),
                                          Color(red: 0.10, green: 0.19, blue: 0.38)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .inset(by: 4)
                    .strokeBorder(Kaleido.gold.opacity(0.55), lineWidth: 1)
            )
            .overlay(Image(systemName: "seal.fill").font(.title3).foregroundStyle(Kaleido.gold.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SolitaireTheme.ivoryEdge.opacity(0.7), lineWidth: 1))
            .frame(width: cardW, height: cardH)
    }

    private func cardFace(_ card: Card, selected: Bool) -> some View {
        let ink = card.isRed ? SolitaireTheme.cardRed : SolitaireTheme.cardInk
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(SolitaireTheme.ivory)
            .overlay(
                VStack(spacing: 0) {
                    HStack {
                        Text(card.rank.shortLabel).font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    Text(card.suit.symbol).font(.system(size: 22))
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Text(card.rank.shortLabel).font(.system(size: 14, weight: .bold)).rotationEffect(.degrees(180))
                    }
                }
                .padding(5)
                .foregroundStyle(ink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? Kaleido.gold : SolitaireTheme.ivoryEdge.opacity(0.8), lineWidth: selected ? 3 : 1)
            )
            .frame(width: cardW, height: cardH)
            .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Button { session.newGame(); selection = nil } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

            Button { session.undo(); selection = nil } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(!session.canUndo)

            Button { session.autoCollect(); selection = nil } label: {
                Label("Auto", systemImage: "wand.and.stars")
            }
            .buttonStyle(GlassButtonStyle())

            Picker("Draw", selection: Binding(get: { session.drawCount },
                                              set: { session.setDrawCount($0); selection = nil })) {
                Text("Draw 1").tag(1)
                Text("Draw 3").tag(3)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Button { modal = .leaderboard } label: {
                Label("Scores", systemImage: "trophy")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    // MARK: - Interaction

    private func handleWasteTap() {
        if case .waste = selection {
            session.sendWasteToFoundation()
            selection = nil
        } else {
            selection = session.game.wasteTop != nil ? .waste : nil
        }
    }

    private func handleFoundationTap() {
        switch selection {
        case .waste:
            session.sendWasteToFoundation()
        case .tableau(let pile, let index):
            if index == session.game.tableau[pile].count - 1 {
                session.sendTableauToFoundation(pile)
            }
        case .none:
            break
        }
        selection = nil
    }

    private func handleTableauTap(pile: Int, index: Int?) {
        switch selection {
        case .none:
            if let index,
               session.game.tableau[pile].indices.contains(index),
               session.game.tableau[pile][index].isFaceUp {
                selection = .tableau(pile: pile, index: index)
            }
        case .waste:
            session.moveWasteToTableau(pile)
            selection = nil
        case .tableau(let fromPile, let fromIndex):
            if fromPile == pile {
                // Tapping the selected top card again sends it home; otherwise deselect.
                if let index, index == fromIndex, fromIndex == session.game.tableau[pile].count - 1 {
                    session.sendTableauToFoundation(pile)
                }
                selection = nil
            } else {
                session.moveTableau(from: fromPile, cardIndex: fromIndex, to: pile)
                selection = nil
            }
        }
    }

    // MARK: - Layout / derived

    private func isSelected(pile: Int, index: Int) -> Bool {
        if case .tableau(let p, let i) = selection, p == pile, index >= i { return true }
        return false
    }

    private func yOffset(_ cards: [SolitairePileCard], upTo index: Int) -> CGFloat {
        var y: CGFloat = 0
        for i in 0..<index { y += cards[i].isFaceUp ? fanUp : fanDown }
        return y
    }

    private func columnHeight(_ cards: [SolitairePileCard]) -> CGFloat {
        guard !cards.isEmpty else { return cardH }
        return yOffset(cards, upTo: cards.count - 1) + cardH
    }

    private var foundationTotal: Int {
        session.game.foundations.values.reduce(0) { $0 + $1.count }
    }

    private var statusText: String {
        session.isWon ? "Solved! 🎉" : "\(foundationTotal)/52 home"
    }

    private var elapsedSeconds: Int {
        session.elapsedSecondsAtWin ?? max(0, Int(now.timeIntervalSince(session.startedAt)))
    }

    private var elapsedLabel: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private func presentResult() {
        let elapsed = session.elapsedSecondsAtWin ?? elapsedSeconds
        modal = .result(session.makeResult(elapsedSeconds: elapsed))
    }
}
