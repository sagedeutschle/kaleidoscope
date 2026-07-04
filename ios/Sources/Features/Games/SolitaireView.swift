// PRISM: RELEASE Agent-Design(solitaire) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Klondike Solitaire — "The Green Baize Table"

/// Felt table skins. Persisted via @AppStorage("solitaire.felt").
private enum SolitaireFelt: String, CaseIterable, Identifiable {
    case emerald = "Emerald Felt"
    case midnight = "Midnight Felt"
    case crimson = "Crimson Felt"
    var id: String { rawValue }
}

/// Card-back motifs. Persisted via @AppStorage("solitaire.cardBack").
private enum SolitaireCardBackStyle: String, CaseIterable, Identifiable {
    case rosette = "Rosette"
    case lattice = "Gold Lattice"
    var id: String { rawValue }
}

/// Game-local theme tokens for the baize table + card stock. Visual only —
/// no Kaleido tokens are added; everything lives inside this file.
private struct SolitaireTheme {
    let accent: Color      // header/celebration tint, follows the felt
    let felt: Color        // main baize surface
    let feltDeep: Color    // vignette edge + controls rail
    let well: Color        // recessed card wells pressed into the felt
    let backField: Color   // field color inside the card-back margin
    let stitch: Color      // thin gold border line around the table

    // Card stock — shared across all felts.
    static let ivory = Color(red: 0.976, green: 0.957, blue: 0.906)
    static let ivoryEdge = Color(red: 0.72, green: 0.67, blue: 0.55)
    static let cardRed = Color(red: 0.72, green: 0.14, blue: 0.18)
    static let cardInk = Color(red: 0.12, green: 0.12, blue: 0.15)

    static func theme(for felt: SolitaireFelt) -> SolitaireTheme {
        switch felt {
        case .emerald:
            return SolitaireTheme(
                accent: Color(red: 0.20, green: 0.45, blue: 0.30),
                felt: Color(red: 0.114, green: 0.353, blue: 0.224),
                feltDeep: Color(red: 0.075, green: 0.255, blue: 0.157),
                well: Color(red: 0.088, green: 0.290, blue: 0.180),
                backField: Color(red: 0.078, green: 0.224, blue: 0.161),
                stitch: Kaleido.gold.opacity(0.55))
        case .midnight:
            return SolitaireTheme(
                accent: Color(red: 0.22, green: 0.34, blue: 0.55),
                felt: Color(red: 0.102, green: 0.157, blue: 0.298),
                feltDeep: Color(red: 0.067, green: 0.110, blue: 0.220),
                well: Color(red: 0.082, green: 0.130, blue: 0.251),
                backField: Color(red: 0.071, green: 0.102, blue: 0.204),
                stitch: Kaleido.gold.opacity(0.55))
        case .crimson:
            return SolitaireTheme(
                accent: Color(red: 0.55, green: 0.20, blue: 0.22),
                felt: Color(red: 0.369, green: 0.114, blue: 0.133),
                feltDeep: Color(red: 0.271, green: 0.078, blue: 0.094),
                well: Color(red: 0.302, green: 0.090, blue: 0.110),
                backField: Color(red: 0.243, green: 0.071, blue: 0.086),
                stitch: Kaleido.gold.opacity(0.55))
        }
    }
}

struct SolitaireView: View {
    private let accountID: UUID?

    @StateObject private var persistence = PersistedGameSession<SolitaireSnapshot>(gameID: .solitaire)
    @State private var game = SolitaireGame.newGame(seed: UInt64.random(in: 0...UInt64.max), drawCount: 1)
    @State private var seed: UInt64 = UInt64.random(in: 0...UInt64.max)

    // Table customization — felt color + card-back motif, behind the paintbrush chip.
    @AppStorage("solitaire.felt") private var feltRaw = SolitaireFelt.emerald.rawValue
    @AppStorage("solitaire.cardBack") private var cardBackRaw = SolitaireCardBackStyle.rosette.rawValue
    private var feltChoice: SolitaireFelt { SolitaireFelt(rawValue: feltRaw) ?? .emerald }
    private var backChoice: SolitaireCardBackStyle { SolitaireCardBackStyle(rawValue: cardBackRaw) ?? .rosette }
    private var theme: SolitaireTheme { SolitaireTheme.theme(for: feltChoice) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Selection is a source the user tapped. nil = nothing chosen.
    // .waste, or .tableau(pile, cardIndex)
    private enum Selection: Equatable {
        case waste
        case tableau(pile: Int, cardIndex: Int)
    }
    @State private var selection: Selection? = nil

    // True while the board is auto-completing to the foundations (all cards face-up).
    @State private var autoFinishing = false

    // True once the board is fully cleared — drives the celebratory win overlay
    // (confetti burst + "You Won!" banner). Transient UI state, never persisted.
    @State private var showCelebration = false

    private let suitsOrder: [Suit] = [.spades, .hearts, .diamonds, .clubs]

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(
                title: "Solitaire",
                systemImage: "suit.spade.fill",
                accent: theme.accent,
                subtitle: game.isWon ? "You won!" : "Build the foundations"
            ) {
                StatBadge(label: "Moves", value: "\(game.moves)", accent: theme.accent)
            }

            board
                .allowsHitTesting(!autoFinishing)

            controls
        }
        .padding(20)
        .frame(maxWidth: 680)                                  // iPad: table breathes, never wall-to-wall
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(theme.accent)
        // Celebratory win overlay — confetti burst + styled "You Won!" banner. Sits
        // above everything and swallows taps until dismissed (tester bug #2).
        .overlay {
            if showCelebration {
                SolitaireCelebrationOverlay(accent: theme.accent, moves: game.moves) {
                    newGame()
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .navigationTitle("Solitaire")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: game.moves)
        .sensoryFeedback(.success, trigger: game.isWon)
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
            // Restored game already fully exposed → finish it off.
            if game.canAutoFinish { startAutoFinish() }
        }
        // The moment the last face-down card is flipped, auto-complete to the
        // foundations (tester feedback: "once all cards are uncovered, auto-complete").
        .onChange(of: game.canAutoFinish) { _, ready in
            if ready { startAutoFinish() }
        }
        // Manual play can also reach a win (e.g. the last card tapped home). Celebrate
        // whenever the board becomes fully solved, cascade or not.
        .onChange(of: game.isWon) { _, won in
            if won && !autoFinishing {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                    showCelebration = true
                }
            }
        }
        .onDisappear { save(forceCloud: true) }
    }

    /// Animated cascade that empties the board into the foundations one card at a
    /// time, drawing/cycling the stock when nothing is immediately playable. Runs on
    /// the main actor; `Task.sleep` paces it without blocking the UI.
    private func startAutoFinish() {
        guard !autoFinishing, game.canAutoFinish else { return }
        autoFinishing = true
        selection = nil
        showCelebration = false
        Task { @MainActor in
            var idleDraws = 0
            while !game.isWon {
                // A gentle spring gives each card a visible "fly + settle" as it snaps
                // to its foundation, so the cascade reads as motion rather than a jump.
                let moved = withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                    game.autoStepToFoundation()
                }
                if moved {
                    idleDraws = 0
                } else {
                    let cyclable = game.stockPlusWasteCount
                    guard cyclable > 0 else { break }
                    _ = withAnimation(.easeInOut(duration: 0.10)) { game.drawFromStock() }
                    idleDraws += 1
                    if idleDraws > cyclable + 1 { break }   // cycled everything, nothing playable
                }
                save()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            autoFinishing = false
            save(forceCloud: true)
            // Board cleared → fire the celebratory overlay.
            if game.isWon {
                try? await Task.sleep(nanoseconds: 180_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                    showCelebration = true
                }
            }
        }
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            let cols = 7
            let spacing: CGFloat = 6
            let cardW = max(24, (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols))
            let cardH = cardW * 1.4
            let fan = cardH * 0.28

            VStack(spacing: 14) {
                topRow(cardW: cardW, cardH: cardH, spacing: spacing)
                tableauRow(cardW: cardW, cardH: cardH, spacing: spacing, fan: fan)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
        .background(feltSurface)
    }

    /// The green baize: deep felt with a soft radial vignette and a thin gold
    /// border line — replaces the generic panel card so the table reads as a table.
    private var feltSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.felt)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.055), Color.clear, Color.black.opacity(0.24)],
                        center: .center, startRadius: 20, endRadius: 430
                    )
                )
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(theme.stitch, lineWidth: 1)
                .padding(6)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
    }

    private func topRow(cardW: CGFloat, cardH: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            // Stock
            slot(width: cardW, height: cardH) {
                if game.stock.isEmpty {
                    recycleGlyph(width: cardW)
                } else {
                    cardBack(width: cardW, height: cardH)
                }
            }
            .onTapGesture {
                selection = nil
                if game.drawFromStock() { save() }
            }

            // Waste
            slot(width: cardW, height: cardH) {
                if let top = game.wasteTop {
                    cardFace(top, width: cardW, height: cardH,
                             selected: selection == .waste)
                } else {
                    EmptyView()
                }
            }
            .onTapGesture { tapWaste() }

            Spacer(minLength: 0)

            // Foundations
            ForEach(suitsOrder, id: \.self) { suit in
                slot(width: cardW, height: cardH) {
                    if let top = game.foundationTop(suit) {
                        cardFace(top, width: cardW, height: cardH, selected: false)
                    } else {
                        foundationGlyph(suit, width: cardW)
                    }
                }
                .onTapGesture { tapFoundation(suit) }
            }
        }
    }

    private func tableauRow(cardW: CGFloat, cardH: CGFloat, spacing: CGFloat, fan: CGFloat) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<7, id: \.self) { pile in
                tableauPile(pile, cardW: cardW, cardH: cardH, fan: fan)
            }
        }
    }

    private func tableauPile(_ pile: Int, cardW: CGFloat, cardH: CGFloat, fan: CGFloat) -> some View {
        let cards = game.tableau[pile]
        let pileHeight = cardH + fan * CGFloat(max(0, cards.count - 1))
        return ZStack(alignment: .top) {
            if cards.isEmpty {
                slot(width: cardW, height: cardH) { EmptyView() }
                    .onTapGesture { tapTableau(pile: pile, cardIndex: 0) }
            } else {
                ForEach(Array(cards.enumerated()), id: \.offset) { idx, pileCard in
                    Group {
                        if pileCard.isFaceUp {
                            cardFace(pileCard.card, width: cardW, height: cardH,
                                     selected: selection == .tableau(pile: pile, cardIndex: idx),
                                     covered: idx < cards.count - 1)
                        } else {
                            cardBack(width: cardW, height: cardH)
                        }
                    }
                    .offset(y: fan * CGFloat(idx))
                    .onTapGesture { tapTableau(pile: pile, cardIndex: idx) }
                }
            }
        }
        .frame(width: cardW, height: max(cardH, pileHeight), alignment: .top)
    }

    // MARK: Card rendering

    /// A card well recessed into the felt — a slightly darker patch with a pressed
    /// edge, so empties read as table markings rather than floating panels.
    private func slot<Content: View>(width: CGFloat, height: CGFloat,
                                     @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.well)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.26), lineWidth: 1)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                .padding(1)
            content()
        }
        .frame(width: width, height: height)
    }

    /// `covered` = another card sits on top of this one in a tableau pile, so only
    /// its top sliver shows. When covered we draw JUST the top-left index (rank+suit)
    /// on a solid suit-colored chip so it stays legible in the sliver (tester bug #1);
    /// when fully exposed we draw a real card face: ivory stock, thin inner frame,
    /// corner indices (top-left + rotated bottom-right), pip grids for 2–10 and
    /// geometric court medallions for J/Q/K. Below cardW≈40 the pips degrade to a
    /// single center pip + indices. Selection lifts the card (scale + shadow).
    private func cardFace(_ card: Card, width: CGFloat, height: CGFloat,
                          selected: Bool, covered: Bool = false) -> some View {
        let suitColor: Color = card.isRed ? SolitaireTheme.cardRed : SolitaireTheme.cardInk
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SolitaireTheme.ivory)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? Kaleido.gold : Color.black.opacity(0.25),
                              lineWidth: selected ? 2 : 1)

            if covered {
                // Only the top sliver of this card shows (the next card overlaps the
                // rest), so the rank+suit index must stay legible on its own. We seat
                // it on a solid, suit-colored backing chip pinned to the top edge so it
                // reads clearly even against a busy pile underneath (tester bug #1).
                HStack(spacing: 2) {
                    Text(card.rank.shortLabel)
                        .font(Kaleido.rounded(min(width * 0.40, 17), .black))
                    Text(card.suit.symbol)
                        .font(.system(size: min(width * 0.34, 15), weight: .heavy))
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
            } else {
                // Thin inner frame — printed border of the card stock.
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .strokeBorder(SolitaireTheme.ivoryEdge.opacity(0.55), lineWidth: 0.8)
                    .padding(2.5)

                cornerIndex(card, width: width, color: suitColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(max(2.5, width * 0.06))
                cornerIndex(card, width: width, color: suitColor)
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(max(2.5, width * 0.06))

                centerArt(card, width: width, height: height, color: suitColor)
            }
        }
        .frame(width: width, height: height)
        // Shadow only on exposed/lifted cards — covered fan cards stay cheap.
        .shadow(color: Color.black.opacity(selected ? 0.35 : (covered ? 0 : 0.16)),
                radius: selected ? 6 : 1.5, y: selected ? 4 : 1)
        .scaleEffect(selected ? 1.04 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                   value: selected)
    }

    /// Small rank-over-suit index printed in a card corner.
    private func cornerIndex(_ card: Card, width: CGFloat, color: Color) -> some View {
        let size = max(6, min(width * 0.20, 11))
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

    /// Center of an exposed face: pip grid for 2–10, geometric medallion for courts,
    /// a single large pip for aces. Degrades to one center pip below cardW≈40.
    @ViewBuilder
    private func centerArt(_ card: Card, width: CGFloat, height: CGFloat, color: Color) -> some View {
        if width < 40 {
            // Too small for pip grids — center pip + corner indices carry the card.
            Text(card.suit.symbol)
                .font(.system(size: max(10, width * 0.34)))
                .foregroundStyle(color)
        } else {
            switch card.rank {
            case .ace:
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.40))
                    .foregroundStyle(color)
            case .jack, .queen, .king:
                courtMedallion(card, width: width, color: color)
            default:
                pipGrid(card, width: width, height: height, color: color)
            }
        }
    }

    /// Real pip arrangements for 2–10, mirrored bottom-half pips rotated like a
    /// printed deck. Positions are unit coordinates inside the pip field.
    private func pipGrid(_ card: Card, width: CGFloat, height: CGFloat, color: Color) -> some View {
        let positions = Self.pipPositions(card.rank)
        let fieldW = width * 0.58
        let fieldH = height * 0.60
        let dense = card.rank.rawValue >= 9
        let pip = min(width * (dense ? 0.15 : 0.17), dense ? 11 : 12)
        return ZStack {
            ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                Text(card.suit.symbol)
                    .font(.system(size: pip))
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

    /// Geometric court medallion — a rotated-square frame around a serif letter,
    /// crowned with 1/2/3 points for J/Q/K, suit pip beneath. No figure art needed.
    private func courtMedallion(_ card: Card, width: CGFloat, color: Color) -> some View {
        let d = width * 0.44
        let points: Int = {
            switch card.rank {
            case .king: return 3
            case .queen: return 2
            default: return 1
            }
        }()
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
                    .strokeBorder(color, lineWidth: max(1, width * 0.028))
                    .frame(width: d * 0.72, height: d * 0.72)
                    .rotationEffect(.degrees(45))
                Text(card.rank.shortLabel)
                    .font(.system(size: d * 0.5, weight: .bold, design: .serif))
                    .foregroundStyle(color)
            }
            .frame(width: d, height: d)
            Text(card.suit.symbol)
                .font(.system(size: width * 0.15))
                .foregroundStyle(color)
        }
    }

    /// Card back: ivory margin frame around a deep field carrying the kaleidoscope
    /// motif — a 12-fold rosette built from the Kaleido.wheel colors (the one place
    /// the brand mark belongs), or a gold lattice. Drawn in a single static Canvas
    /// per back so a full face-down tableau stays cheap.
    private func cardBack(width: CGFloat, height: CGFloat) -> some View {
        let margin = max(1.5, width * 0.07)
        let inner = RoundedRectangle(cornerRadius: 5, style: .continuous)
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SolitaireTheme.ivory)
            ZStack {
                inner.fill(theme.backField)
                Canvas { context, size in
                    switch backChoice {
                    case .rosette:
                        Self.drawRosette(context: context, size: size)
                    case .lattice:
                        Self.drawLattice(context: context, size: size)
                    }
                }
                inner.strokeBorder(Kaleido.gold.opacity(0.4), lineWidth: 0.8)
            }
            .clipShape(inner)
            .padding(margin)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
        }
        .frame(width: width, height: height)
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

    /// Diagonal gold lattice, quiet alternative back.
    private static func drawLattice(context: GraphicsContext, size: CGSize) {
        let step = max(6, size.width / 4)
        var lines = Path()
        var x = -size.height
        while x < size.width + size.height {
            lines.move(to: CGPoint(x: x, y: 0))
            lines.addLine(to: CGPoint(x: x + size.height, y: size.height))
            lines.move(to: CGPoint(x: x + size.height, y: 0))
            lines.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        context.stroke(lines, with: .color(Kaleido.gold.opacity(0.45)), lineWidth: 0.8)
    }

    /// Recycle arrow debossed into the exhausted stock's felt well.
    private func recycleGlyph(width: CGFloat) -> some View {
        let size = min(width * 0.42, 18)
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

    /// Empty foundation: its suit embossed straight into the felt.
    private func foundationGlyph(_ suit: Suit, width: CGFloat) -> some View {
        let size = min(width * 0.5, 24)
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

    // MARK: Interaction

    private func tapWaste() {
        guard game.wasteTop != nil else { selection = nil; return }
        // Auto-try foundation first.
        if game.moveWasteToFoundation() {
            selection = nil
            save(forceCloud: game.isWon)
            return
        }
        // Else select waste as a move source.
        selection = (selection == .waste) ? nil : .waste
    }

    private func tapFoundation(_ suit: Suit) {
        switch selection {
        case .waste:
            if game.moveWasteToFoundation() {
                selection = nil
                save(forceCloud: game.isWon)
            }
        case .tableau(let pile, _):
            if game.moveTableauToFoundation(pile: pile) {
                selection = nil
                save(forceCloud: game.isWon)
            }
        case .none:
            break
        }
    }

    private func tapTableau(pile: Int, cardIndex: Int) {
        switch selection {
        case .none:
            // Try auto-foundation from this pile's top first.
            let cards = game.tableau[pile]
            if !cards.isEmpty, cardIndex == cards.count - 1, cards[cardIndex].isFaceUp {
                if game.moveTableauToFoundation(pile: pile) {
                    save(forceCloud: game.isWon)
                    return
                }
            }
            // Otherwise select this face-up card as a move source.
            if !cards.isEmpty, cards[cardIndex].isFaceUp {
                selection = .tableau(pile: pile, cardIndex: cardIndex)
            }
        case .waste:
            if game.moveWasteToTableau(pile: pile) {
                selection = nil
                save()
            }
            else { selection = nil }
        case .tableau(let from, let cardIdx):
            if from == pile {
                selection = nil
            } else if game.moveTableau(from: from, cardIndex: cardIdx, to: pile) {
                selection = nil
                save(forceCloud: game.isWon)
            } else {
                selection = nil
            }
        }
    }

    // MARK: Controls

    /// Compact chips on a felt rail — table furniture instead of stacked
    /// full-width buttons. The paintbrush opens felt + card-back skins.
    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                selection = nil
                if game.drawFromStock() { save() }
            } label: {
                Text("Draw")
            }
            .buttonStyle(FeltChipStyle())
            .accessibilityLabel("Draw from stock")

            Button {
                selection = nil
                if game.autoCollectToFoundations() { save(forceCloud: game.isWon) }
            } label: {
                Text("Collect")
            }
            .buttonStyle(FeltChipStyle())
            .accessibilityLabel("Auto-collect to foundations")

            Button {
                newGame()
            } label: {
                Text("New Game")
            }
            .buttonStyle(FeltChipStyle())
            .accessibilityLabel("Start a new game")

            Menu {
                Picker("Felt", selection: $feltRaw) {
                    ForEach(SolitaireFelt.allCases) { option in
                        Text(option.rawValue).tag(option.rawValue)
                    }
                }
                Picker("Card Back", selection: $cardBackRaw) {
                    ForEach(SolitaireCardBackStyle.allCases) { option in
                        Text(option.rawValue).tag(option.rawValue)
                    }
                }
            } label: {
                Image(systemName: "paintbrush")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SolitaireTheme.ivory)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.09))
                            .overlay(Capsule(style: .continuous)
                                .strokeBorder(Kaleido.gold.opacity(0.35), lineWidth: 1))
                    )
            }
            .accessibilityLabel("Table style")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(theme.feltDeep)
                .overlay(Capsule(style: .continuous)
                    .strokeBorder(theme.stitch, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
        )
    }

    private func newGame() {
        withAnimation(.easeOut(duration: 0.25)) { showCelebration = false }
        autoFinishing = false
        seed = UInt64.random(in: 0...UInt64.max)
        game = SolitaireGame.newGame(seed: seed, drawCount: 1)
        selection = nil
        save(forceCloud: true)
    }

    private func snapshot() -> SolitaireSnapshot {
        SolitaireSnapshot(game: game, seed: seed)
    }

    private func restore(_ snapshot: SolitaireSnapshot) {
        game = snapshot.game
        seed = snapshot.seed
        selection = nil
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: game.moves, forceCloud: forceCloud)
    }
}

/// Small in-world chip for the felt rail: ivory text on a translucent pill with a
/// gold hairline, pressed state sinks slightly.
private struct FeltChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(SolitaireTheme.ivory)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09))
                    .overlay(Capsule(style: .continuous)
                        .strokeBorder(Kaleido.gold.opacity(0.35), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - Celebration

/// Full-facet win celebration: a confetti burst behind a spring-scaled "You Won!"
/// banner with a Play Again button. Purely presentational; the parent owns the
/// `showCelebration` flag and passes a dismiss/replay closure.
private struct SolitaireCelebrationOverlay: View {
    let accent: Color
    let moves: Int
    let onPlayAgain: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dim the board so the banner pops; still shows the cleared table beneath.
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            ConfettiBurst(active: appeared)
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Kaleido.gold)
                    .shadow(color: Kaleido.gold.opacity(0.6), radius: 10)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -20))

                Text("You Won!")
                    .font(Kaleido.title(40))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)

                Text("Cleared in \(moves) moves")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Button(action: onPlayAgain) {
                    Label("Play Again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(AccentButtonStyle(accent: accent))
                .padding(.top, 6)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 34)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(accent.gradient)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: irisColors(Kaleido.gold)),
                                            center: .center),
                            lineWidth: 3))
                    .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            )
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

/// A one-shot confetti spray: a fixed set of colored shards that fall + spin outward
/// once `active` flips true. Deterministic per-piece seed keeps it cheap and jitter-free.
private struct ConfettiBurst: View {
    var active: Bool
    private let pieces = 44

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieces, id: \.self) { i in
                    ConfettiPiece(index: i, size: geo.size, active: active)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let size: CGSize
    let active: Bool

    // Deterministic pseudo-random spread derived from the piece index.
    private var rand: (CGFloat, CGFloat, CGFloat) {
        let a = (sin(Double(index) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let b = (sin(Double(index) * 78.233) * 12543.987).truncatingRemainder(dividingBy: 1)
        let c = (sin(Double(index) * 3.1415) * 9999.777).truncatingRemainder(dividingBy: 1)
        return (CGFloat(a.magnitude), CGFloat(b.magnitude), CGFloat(c.magnitude))
    }

    var body: some View {
        let (rx, ry, rr) = rand
        let color = Kaleido.wheel[index % Kaleido.wheel.count]
        let startX = size.width * rx
        let drift = (rx - 0.5) * size.width * 0.6
        let fall = size.height * (0.55 + ry * 0.45)
        let side = index.isMultiple(of: 3)

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: side ? 7 : 5, height: side ? 10 : 8)
            .rotationEffect(.degrees(active ? Double(rr) * 720 - 360 : 0))
            .position(x: startX + (active ? drift : 0),
                      y: active ? fall : -20)
            .opacity(active ? 0 : 1)
            .animation(
                .easeIn(duration: 1.1 + Double(ry) * 0.7).delay(Double(rx) * 0.25),
                value: active)
    }
}

#Preview {
    NavigationStack {
        SolitaireView()
    }
}
