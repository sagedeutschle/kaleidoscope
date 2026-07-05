// PRISM: RELEASE Agent-Mac 2026-07-04 — mirrored iOS v10/v11 "Green Baize Table"
// material onto macOS: real felt vignette + gold stitch border, printed-stock card
// faces (corner indices, pip grids, court medallions), ivory-margin rosette card
// backs. Visual layer only — session/model/interaction untouched. Build green.
import SwiftUI

// MARK: - Baize material ("The Green Baize Table")

/// Game-local material palette mirrored from the iOS v10/v11 `SolitaireTheme`
/// (emerald felt + ivory card stock). Visual only — card ranks/suits and all
/// interaction come from the model; nothing here touches game logic.
private struct SolitaireTheme {
    static let accent = Color(red: 0.20, green: 0.45, blue: 0.30)
    static let felt = Color(red: 0.114, green: 0.353, blue: 0.224)
    static let feltDeep = Color(red: 0.075, green: 0.255, blue: 0.157)
    static let well = Color(red: 0.088, green: 0.290, blue: 0.180)
    static let cardBackField = Color(red: 0.078, green: 0.224, blue: 0.161)
    static let stitch = Kaleido.gold.opacity(0.55)

    // Card stock.
    static let ivory = Color(red: 0.976, green: 0.957, blue: 0.906)
    static let ivoryEdge = Color(red: 0.72, green: 0.67, blue: 0.55)
    static let cardRed = Color(red: 0.72, green: 0.14, blue: 0.18)
    static let cardInk = Color(red: 0.12, green: 0.12, blue: 0.15)
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
        .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
    }

    /// The green baize: deep felt with a soft radial vignette, a thin gold stitch
    /// border, and a dark outer seam — mirrors the iOS emerald table.
    private var feltSurface: some View {
        SolitaireFeltSurface()
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
                    SolitaireRecycleGlyph(width: cardW)
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
                cardSlot.overlay(SolitaireFoundationGlyph(suit: suit, width: cardW))
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
                cardButton(pileCard, pile: pile, index: index, covered: index < cards.count - 1)
                    .offset(y: yOffset(cards, upTo: index))
            }
        }
        .frame(width: cardW, height: columnHeight(cards), alignment: .top)
    }

    /// `covered` mirrors the iOS tableau: another card sits on top of this one, so
    /// only its top sliver shows — the full pip/court face would be illegible, so a
    /// solid suit-colored index chip is drawn instead (tester-bug parity).
    private func cardButton(_ pileCard: SolitairePileCard, pile: Int, index: Int, covered: Bool) -> some View {
        Button {
            handleTableauTap(pile: pile, index: index)
        } label: {
            if pileCard.isFaceUp {
                cardFace(pileCard.card, selected: isSelected(pile: pile, index: index), covered: covered)
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
        SolitaireCardWell(width: cardW, height: cardH)
    }

    /// Ivory-margin card back carrying a 12-fold kaleidoscope rosette, mirroring
    /// the iOS printed-stock back (replaces the old flat blue/seal placeholder).
    private var cardBack: some View {
        SolitaireCardBack(width: cardW, height: cardH)
    }

    private func cardFace(_ card: Card, selected: Bool, covered: Bool = false) -> some View {
        SolitaireCardFace(card: card, selected: selected, covered: covered, width: cardW, height: cardH)
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

// MARK: - Baize table surface

/// Extracted to its own type (rather than a computed property with an inline
/// ZStack) so the SwiftUI type-checker doesn't have to re-solve a large nested
/// expression on every edit — a known repo gotcha for this target.
private struct SolitaireFeltSurface: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SolitaireTheme.felt)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    RadialGradient(colors: [Color.white.opacity(0.06), .clear, Color.black.opacity(0.22)],
                                   center: UnitPoint(x: 0.5, y: 0.2), startRadius: 20, endRadius: 460)
                )
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SolitaireTheme.stitch, lineWidth: 1)
                .padding(5)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
        }
    }
}

// MARK: - Card well

/// A card well recessed into the felt — a darker patch pressed into the baize
/// with a subtle inner shadow, mirroring the iOS wells.
private struct SolitaireCardWell: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
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
            .frame(width: width, height: height)
    }
}

// MARK: - Card face (real pips + courts)

/// `covered` = another card sits on top of this one in a tableau pile, so only its
/// top sliver shows. When covered we draw JUST the top-left index (rank+suit) on a
/// solid suit-colored chip so it stays legible in the sliver; when fully exposed we
/// draw a real card face: ivory stock, thin inner frame, corner indices (top-left +
/// rotated bottom-right), pip grids for 2–10, and geometric court medallions for
/// J/Q/K. Mirrors the iOS v10/v11 printed-deck identity.
private struct SolitaireCardFace: View {
    let card: Card
    let selected: Bool
    var covered: Bool = false
    let width: CGFloat
    let height: CGFloat

    private var suitColor: Color { card.isRed ? SolitaireTheme.cardRed : SolitaireTheme.cardInk }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(SolitaireTheme.ivory)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(selected ? Kaleido.gold : Color.black.opacity(0.25),
                              lineWidth: selected ? 2.5 : 1)

            if covered {
                coveredIndexChip
            } else {
                exposedFace
            }
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(selected ? 0.35 : (covered ? 0 : 0.18)),
                radius: selected ? 6 : 1.5, y: selected ? 4 : 1)
        .scaleEffect(selected ? 1.05 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: selected)
    }

    /// Solid, suit-colored index capsule pinned to the top edge — legible even
    /// against a busy pile underneath.
    private var coveredIndexChip: some View {
        HStack(spacing: 2) {
            Text(card.rank.shortLabel)
                .font(Kaleido.rounded(min(width * 0.40, 15), .black))
            Text(card.suit.symbol)
                .font(.system(size: min(width * 0.34, 13), weight: .heavy))
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, max(4, width * 0.09))
        .padding(.vertical, max(2, width * 0.05))
        .background(
            Capsule(style: .continuous)
                .fill(suitColor)
                .overlay(Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.25), radius: 1.5, y: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, max(3, width * 0.08))
        .padding(.top, max(2, width * 0.05))
    }

    /// Fully exposed printed face: inner frame, mirrored corner indices, center art.
    private var exposedFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(SolitaireTheme.ivoryEdge.opacity(0.55), lineWidth: 0.8)
                .padding(2.5)

            SolitaireCornerIndex(card: card, width: width, color: suitColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(max(2.5, width * 0.07))
            SolitaireCornerIndex(card: card, width: width, color: suitColor)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(max(2.5, width * 0.07))

            SolitaireCenterArt(card: card, width: width, height: height, color: suitColor)
        }
    }
}

/// Small rank-over-suit index printed in a card corner.
private struct SolitaireCornerIndex: View {
    let card: Card
    let width: CGFloat
    let color: Color

    var body: some View {
        let size = max(7, min(width * 0.20, 12))
        return VStack(spacing: -1) {
            Text(card.rank.shortLabel)
                .font(.system(size: size, weight: .bold, design: .serif))
            Text(card.suit.symbol)
                .font(.system(size: size * 0.85))
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// Center of an exposed face: pip grid for 2–10, geometric medallion for courts, a
/// single large pip for aces. Degrades to one center pip below width≈34.
private struct SolitaireCenterArt: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        Group {
            if width < 34 {
                Text(card.suit.symbol)
                    .font(.system(size: max(9, width * 0.34)))
                    .foregroundStyle(color)
            } else {
                switch card.rank {
                case .ace:
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.42))
                        .foregroundStyle(color)
                case .jack, .queen, .king:
                    SolitaireCourtMedallion(card: card, width: width, color: color)
                default:
                    SolitairePipGrid(card: card, width: width, height: height, color: color)
                }
            }
        }
    }
}

/// Real pip arrangements for 2–10, mirrored bottom-half pips rotated like a
/// printed deck. Positions are unit coordinates inside the pip field.
private struct SolitairePipGrid: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        let positions = Self.pipPositions(card.rank)
        let fieldW = width * 0.60
        let fieldH = height * 0.62
        let dense = card.rank.rawValue >= 9
        let pipSize = min(width * (dense ? 0.16 : 0.19), dense ? 12 : 13)
        return ZStack {
            ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                Text(card.suit.symbol)
                    .font(.system(size: pipSize))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(p.flipped ? 180 : 0))
                    .position(x: fieldW * p.x, y: fieldH * p.y)
            }
        }
        .frame(width: fieldW, height: fieldH)
    }

    private static func pipPositions(_ rank: Rank) -> [(x: CGFloat, y: CGFloat, flipped: Bool)] {
        let cols: [(CGFloat, CGFloat, Bool)] = [
            (0.22, 0.12, false), (0.78, 0.12, false),
            (0.22, 0.88, true), (0.78, 0.88, true)
        ]
        switch rank {
        case .two:   return [(0.5, 0.12, false), (0.5, 0.88, true)]
        case .three: return [(0.5, 0.12, false), (0.5, 0.5, false), (0.5, 0.88, true)]
        case .four:  return cols
        case .five:  return cols + [(0.5, 0.5, false)]
        case .six:   return cols + [(0.22, 0.5, false), (0.78, 0.5, false)]
        case .seven: return cols + [(0.22, 0.5, false), (0.78, 0.5, false), (0.5, 0.31, false)]
        case .eight: return cols + [(0.22, 0.5, false), (0.78, 0.5, false),
                                    (0.5, 0.31, false), (0.5, 0.69, true)]
        case .nine:  return [(0.22, 0.12, false), (0.78, 0.12, false),
                             (0.22, 0.375, false), (0.78, 0.375, false),
                             (0.22, 0.625, true), (0.78, 0.625, true),
                             (0.22, 0.88, true), (0.78, 0.88, true),
                             (0.5, 0.5, false)]
        case .ten:   return [(0.22, 0.12, false), (0.78, 0.12, false),
                             (0.22, 0.375, false), (0.78, 0.375, false),
                             (0.22, 0.625, true), (0.78, 0.625, true),
                             (0.22, 0.88, true), (0.78, 0.88, true),
                             (0.5, 0.245, false), (0.5, 0.755, true)]
        default:     return []
        }
    }
}

/// Geometric court medallion — a rotated-square frame around a serif letter,
/// crowned with 1/2/3 points for J/Q/K, suit pip beneath. No figure art needed.
private struct SolitaireCourtMedallion: View {
    let card: Card
    let width: CGFloat
    let color: Color

    private var points: Int {
        switch card.rank {
        case .king: return 3
        case .queen: return 2
        default: return 1
        }
    }

    var body: some View {
        let d = width * 0.46
        return VStack(spacing: max(1, width * 0.035)) {
            HStack(spacing: max(1.5, width * 0.05)) {
                ForEach(0..<points, id: \.self) { _ in
                    Rectangle()
                        .fill(Kaleido.gold)
                        .frame(width: max(2.5, width * 0.06), height: max(2.5, width * 0.06))
                        .rotationEffect(.degrees(45))
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: d * 0.12, style: .continuous)
                    .strokeBorder(color, lineWidth: max(1, width * 0.03))
                    .frame(width: d * 0.72, height: d * 0.72)
                    .rotationEffect(.degrees(45))
                Text(card.rank.shortLabel)
                    .font(.system(size: d * 0.5, weight: .bold, design: .serif))
                    .foregroundStyle(color)
            }
            .frame(width: d, height: d)
            Text(card.suit.symbol)
                .font(.system(size: width * 0.16))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Card back (printed rosette)

/// Card back: ivory margin frame around a deep field carrying the kaleidoscope
/// rosette motif — a 12-fold rosette built from the Kaleido.wheel colors. Drawn in
/// a single static Canvas so a full face-down tableau stays cheap. Replaces the
/// old flat blue-gradient/seal placeholder with the iOS printed-stock identity.
private struct SolitaireCardBack: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let margin = max(1.5, width * 0.07)
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(SolitaireTheme.ivory)
            innerField
                .padding(margin)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
        }
        .frame(width: width, height: height)
    }

    private var innerField: some View {
        let inner = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return ZStack {
            inner.fill(SolitaireTheme.cardBackField)
            Canvas { context, size in
                Self.drawRosette(context: context, size: size)
            }
            inner.strokeBorder(Kaleido.gold.opacity(0.4), lineWidth: 0.8)
        }
        .clipShape(inner)
    }

    /// 12-fold kaleidoscope rosette from the brand wheel, gold hub at center.
    private static func drawRosette(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.44
        for i in 0..<12 {
            let angle = Double(i) * .pi / 6
            var petal = Path()
            petal.addEllipse(in: CGRect(x: -radius * 0.16, y: -radius,
                                        width: radius * 0.32, height: radius))
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: angle)
            context.fill(petal.applying(transform),
                         with: .color(Kaleido.wheel[i % Kaleido.wheel.count].opacity(0.75)))
        }
        let hub = radius * 0.16
        context.fill(Path(ellipseIn: CGRect(x: center.x - hub, y: center.y - hub,
                                            width: hub * 2, height: hub * 2)),
                     with: .color(Kaleido.gold))
    }
}

// MARK: - Debossed felt glyphs

/// Recycle arrow debossed into the exhausted stock's felt well.
private struct SolitaireRecycleGlyph: View {
    let width: CGFloat

    var body: some View {
        let size = min(width * 0.42, 17)
        return ZStack {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.10))
                .offset(y: 1)
            Image(systemName: "arrow.clockwise")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.34))
        }
        .accessibilityLabel("Recycle waste into stock")
    }
}

/// Empty foundation: its suit embossed straight into the felt.
private struct SolitaireFoundationGlyph: View {
    let suit: Suit
    let width: CGFloat

    var body: some View {
        let size = min(width * 0.5, 22)
        return ZStack {
            Text(suit.symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.10))
                .offset(y: 1)
            Text(suit.symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.34))
        }
        .accessibilityLabel("Empty \(suit.rawValue) foundation")
    }
}
