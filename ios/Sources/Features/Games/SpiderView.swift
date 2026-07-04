// PRISM: RELEASE Agent-Design(spider) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Spider — "The Two-Deck Table"
//
// Shares the Solitaire card language: ivory stock, corner indices, pip grids,
// geometric court medallions, kaleidoscope-rosette backs, deep-green felt.
// Signature: the completed-run sweep — a King card lifts off the table, flashes
// gold, and dives into the run tray on the felt rail.
//
// VISUAL LAYER ONLY. SpiderGame model calls, SpiderSnapshot shape, persistence
// configure/save wiring, and tap semantics are unchanged from the Codex build.

// Game-local theme tokens (per design direction: no additions to KaleidoDesign).
private enum SpiderTheme {
    // Felt table
    static let feltHi   = Color(red: 0.157, green: 0.416, blue: 0.267)
    static let felt     = Color(red: 0.098, green: 0.325, blue: 0.208)
    static let feltLo   = Color(red: 0.047, green: 0.216, blue: 0.129)
    static let feltRail = Color(red: 0.075, green: 0.267, blue: 0.169)
    static let goldLine = Kaleido.gold.opacity(0.55)
    // Card stock
    static let ivory    = Color(red: 0.978, green: 0.966, blue: 0.925)
    static let ivoryLo  = Color(red: 0.936, green: 0.915, blue: 0.856)
    static let cardEdge = Color(red: 0.22, green: 0.20, blue: 0.16).opacity(0.55)
    static let inkBlack = Color(red: 0.12, green: 0.13, blue: 0.17)
    static let inkRed   = Color(red: 0.71, green: 0.16, blue: 0.18)
    // Rosette back
    static let backGround = Color(red: 0.082, green: 0.239, blue: 0.157)
}

struct SpiderView: View {
    private static let accent = Color(red: 0.24, green: 0.52, blue: 0.36)
    private let accountID: UUID?

    @StateObject private var persistence = PersistedGameSession<SpiderSnapshot>(gameID: .spider)
    @State private var seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    @State private var game = SpiderGame.newGame(seed: 41)
    @State private var selected: (column: Int, index: Int)?

    // Transient presentation state — never persisted.
    @State private var sweepVisible = false     // completed-run card is on screen
    @State private var sweepFly = false         // …and diving toward the tray
    @State private var trayPulse = false        // newest tray slot glows gold
    @State private var showWin = false          // win banner (delayed past the last sweep)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(
                title: "Spider",
                systemImage: "suit.spade.fill",
                accent: Self.accent,
                subtitle: game.isWon ? "All suits cleared" : "Build King to Ace runs"
            ) {
                StatBadge(label: "Moves", value: "\(game.moves)", accent: Self.accent)
            }

            board

            feltRail
        }
        .padding(20)
        .frame(maxWidth: 680)                       // iPad: the table breathes, never stretches
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(Self.accent)
        .overlay {
            if showWin {
                SpiderWinBanner(moves: game.moves) { newGame() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .navigationTitle("Spider")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: game.moves)
        .sensoryFeedback(.success, trigger: game.completedSets)
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
            if game.isWon { showWin = true }
        }
        .onChange(of: game.completedSets) { old, new in
            if new > old { runCompletedSweep() }
        }
        .onChange(of: game.isWon) { _, won in
            if won {
                Task { @MainActor in
                    if !reduceMotion {
                        try? await Task.sleep(nanoseconds: 950_000_000)   // let the last sweep land
                    }
                    guard game.isWon else { return }
                    withAnimation(.easeOut(duration: 0.25)) { showWin = true }
                }
            } else {
                showWin = false
            }
        }
        .onDisappear { save(forceCloud: true) }
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let hPad: CGFloat = 8
            let cardWidth = max(24, (geo.size.width - hPad * 2 - spacing * 9) / 10)
            let cardHeight = cardWidth * 1.42
            // Face-down cards fan tight (real spider table); face-up runs fan open so
            // the corner indices stay readable. Fans squeeze when a pile grows tall.
            let baseUp = cardHeight * 0.30
            let baseDown = cardHeight * 0.14
            let maxFanSum = game.tableau.map { fanSum($0, up: baseUp, down: baseDown) }.max() ?? 0
            let availableFan = geo.size.height - hPad * 2 - cardHeight
            let squeeze = maxFanSum > 0 ? min(1, max(0.30, availableFan / maxFanSum)) : 1

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<SpiderGame.columnCount, id: \.self) { column in
                    pile(column,
                         cardWidth: cardWidth,
                         cardHeight: cardHeight,
                         upFan: baseUp * squeeze,
                         downFan: baseDown * squeeze)
                }
            }
            .padding(hPad)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .aspectRatio(0.86, contentMode: .fit)
        .background(feltPanel)
        .overlay(alignment: .center) { sweepOverlay }
    }

    private var feltPanel: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [SpiderTheme.feltHi, SpiderTheme.felt, SpiderTheme.feltLo],
                    center: .center, startRadius: 40, endRadius: 460
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SpiderTheme.goldLine, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 14, y: 8)
    }

    private func pile(_ column: Int, cardWidth: CGFloat, cardHeight: CGFloat,
                      upFan: CGFloat, downFan: CGFloat) -> some View {
        let cards = game.tableau[column]
        let ys = fanOffsets(cards, up: upFan, down: downFan)
        return ZStack(alignment: .top) {
            if cards.isEmpty {
                emptySlot(width: cardWidth, height: cardHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { moveSelection(to: column) }
                    .accessibilityLabel("Empty column")
                    .accessibilityAddTraits(.isButton)
            } else {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, spiderCard in
                    let inRun: Bool = {
                        guard let sel = selected, sel.column == column else { return false }
                        return index >= sel.index
                    }()
                    let isTop = index == cards.count - 1
                    cardView(spiderCard, width: cardWidth, height: cardHeight,
                             inSelectedRun: inRun, isTop: isTop)
                        .offset(y: ys[index] + (inRun ? -3 : 0))
                        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8),
                                   value: inRun)
                        .onTapGesture { tap(column: column, index: index) }
                        .accessibilityLabel(spiderCard.isFaceUp
                            ? "\(spiderCard.card.rank.shortLabel) of \(spiderCard.card.suit.rawValue)"
                            : "Face down card")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .frame(width: cardWidth,
               height: max(cardHeight, (ys.last ?? 0) + cardHeight),
               alignment: .top)
    }

    /// Gap above each card: tight for face-down, open for face-up runs.
    private func fanOffsets(_ cards: [SpiderCard], up: CGFloat, down: CGFloat) -> [CGFloat] {
        var ys: [CGFloat] = []
        var y: CGFloat = 0
        for i in cards.indices {
            if i > 0 { y += cards[i - 1].isFaceUp ? up : down }
            ys.append(y)
        }
        return ys
    }

    private func fanSum(_ cards: [SpiderCard], up: CGFloat, down: CGFloat) -> CGFloat {
        guard cards.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 0..<(cards.count - 1) {
            total += cards[i].isFaceUp ? up : down
        }
        return total
    }

    @ViewBuilder
    private func cardView(_ spiderCard: SpiderCard, width: CGFloat, height: CGFloat,
                          inSelectedRun: Bool, isTop: Bool) -> some View {
        Group {
            if spiderCard.isFaceUp {
                SpiderCardFaceView(card: spiderCard.card, width: width, height: height,
                                   selected: inSelectedRun)
            } else {
                // Rosette only on the exposed back — covered backs show a sliver, keep them cheap.
                SpiderCardBackView(width: width, height: height, ornate: isTop)
            }
        }
        // Shadow only on the top card / lifted run (piles run deep — keep layers cheap).
        .shadow(color: Color.black.opacity(isTop || inSelectedRun ? 0.25 : 0),
                radius: inSelectedRun ? 5 : 1.5,
                y: inSelectedRun ? 3 : 1)
    }

    /// A slot debossed into the felt with a faint spade watermark.
    private func emptySlot(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(SpiderTheme.feltLo.opacity(0.55))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
            Image(systemName: "suit.spade")
                .font(.system(size: min(width * 0.42, 18)))
                .foregroundStyle(Color.white.opacity(0.12))
        }
        .frame(width: width, height: height)
    }

    // MARK: Completed-run sweep (the signature moment)

    @ViewBuilder
    private var sweepOverlay: some View {
        if sweepVisible {
            SpiderCardFaceView(card: Card(rank: .king, suit: .spades), width: 58, height: 82)
                .shadow(color: Kaleido.gold.opacity(0.65), radius: 14)
                .scaleEffect(sweepFly ? 0.28 : 1.08)
                .offset(y: sweepFly ? 260 : 0)
                .opacity(sweepFly ? 0 : 1)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func runCompletedSweep() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { trayPulse = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(.easeOut(duration: 0.3)) { trayPulse = false }
        }
        guard !reduceMotion else { return }
        sweepFly = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { sweepVisible = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.easeIn(duration: 0.45)) { sweepFly = true }
            try? await Task.sleep(nanoseconds: 500_000_000)
            sweepVisible = false
            sweepFly = false
        }
    }

    // MARK: Felt rail (stock, run tray, new deal)

    private var dealDisabled: Bool {
        game.stockRows.isEmpty || game.tableau.contains(where: \.isEmpty)
    }

    private var feltRail: some View {
        HStack(spacing: 12) {
            dealControl
            Spacer(minLength: 8)
            setsTray
            Spacer(minLength: 8)
            newDealChip
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpiderTheme.feltRail)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(SpiderTheme.goldLine, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
        )
    }

    /// The stock: remaining deal rows drawn as a fanned stack of rosette backs.
    private var dealControl: some View {
        Button {
            if game.dealRow() {
                selected = nil
                save()
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if game.stockRows.isEmpty {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                            .frame(width: 24, height: 34)
                    } else {
                        ForEach(0..<game.stockRows.count, id: \.self) { i in
                            SpiderCardBackView(width: 24, height: 34,
                                               ornate: i == game.stockRows.count - 1)
                                .offset(x: CGFloat(i) * 2.5, y: CGFloat(i) * -1.5)
                        }
                    }
                }
                .frame(width: 36, height: 42, alignment: .bottomLeading)

                Text("DEAL · \(game.stockRows.count)")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .monospacedDigit()
                    .foregroundStyle(SpiderTheme.ivory.opacity(0.9))
            }
            .opacity(dealDisabled ? 0.35 : 1)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(dealDisabled)
        .accessibilityLabel("Deal a row")
        .accessibilityValue("\(game.stockRows.count) deals remaining")
    }

    /// Eight tray slots — each completed run fills one with a mini King of spades.
    private var setsTray: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { i in
                traySlot(i)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completed runs")
        .accessibilityValue("\(game.completedSets) of 8")
    }

    private func traySlot(_ i: Int) -> some View {
        let filled = i < game.completedSets
        let isNewest = filled && i == game.completedSets - 1
        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(filled
                      ? AnyShapeStyle(LinearGradient(colors: [SpiderTheme.ivory, SpiderTheme.ivoryLo],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(SpiderTheme.feltLo.opacity(0.6)))
            if filled {
                VStack(spacing: -2) {
                    Text("K")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                    Text("♠")
                        .font(.system(size: 8))
                }
                .foregroundStyle(SpiderTheme.inkBlack)
            }
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(filled ? Kaleido.gold.opacity(0.55) : Color.black.opacity(0.3),
                              lineWidth: 1)
        }
        .frame(width: 16, height: 23)
        .scaleEffect(isNewest && trayPulse ? 1.3 : 1)
        .shadow(color: isNewest && trayPulse ? Kaleido.gold.opacity(0.8) : .clear, radius: 6)
    }

    private var newDealChip: some View {
        Button {
            newGame()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("NEW")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
            }
            .foregroundStyle(SpiderTheme.ivory.opacity(0.9))
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New deal")
    }

    // MARK: Interaction (unchanged semantics)

    private func tap(column: Int, index: Int) {
        if let selected {
            if selected.column == column && selected.index == index {
                self.selected = nil
            } else if game.moveRun(from: selected.column, cardIndex: selected.index, to: column) {
                self.selected = nil
                save(forceCloud: game.isWon)
            } else if game.tableau[column][index].isFaceUp {
                self.selected = (column, index)
            }
        } else if game.tableau[column][index].isFaceUp {
            selected = (column, index)
        }
    }

    private func moveSelection(to column: Int) {
        guard let selected, game.moveRun(from: selected.column, cardIndex: selected.index, to: column) else { return }
        self.selected = nil
        save(forceCloud: game.isWon)
    }

    // MARK: Persistence (unchanged)

    private func snapshot() -> SpiderSnapshot {
        SpiderSnapshot(game: game, seed: seed)
    }

    private func restore(_ snapshot: SpiderSnapshot) {
        game = snapshot.game
        seed = snapshot.seed
        selected = nil
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: game.completedSets, forceCloud: forceCloud)
    }

    private func newGame() {
        showWin = false
        seed = UInt64.random(in: 1...UInt64.max)
        game = SpiderGame.newGame(seed: seed)
        selected = nil
        save(forceCloud: true)
    }
}

// MARK: - Card face (shared Solitaire language)

/// Ivory card face. Full treatment (corner indices, pip grid, court medallions)
/// above ~44pt width; compact treatment (sliver-safe corner index + center pip)
/// below — ten columns on an iPhone land around 30pt.
private struct SpiderCardFaceView: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    var selected: Bool = false

    private var pipColor: Color { card.isRed ? SpiderTheme.inkRed : SpiderTheme.inkBlack }
    private var corner: CGFloat { min(8, max(3.5, width * 0.13)) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(colors: [SpiderTheme.ivory, SpiderTheme.ivoryLo],
                                   startPoint: .top, endPoint: .bottom)
                )
            if width >= 44 {
                fullFace
            } else {
                compactFace
            }
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(selected ? Kaleido.gold : SpiderTheme.cardEdge,
                              lineWidth: selected ? 2 : 1)
        }
        .frame(width: width, height: height)
    }

    // Compact: the corner index must survive alone in a fanned sliver.
    private var compactFace: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0.5) {
                Text(card.rank.shortLabel)
                Text(card.suit.symbol)
            }
            .font(.system(size: max(7.5, width * 0.30), weight: .heavy, design: .rounded))
            .foregroundStyle(pipColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.leading, max(2, width * 0.09))
            .padding(.top, max(1.5, width * 0.05))

            VStack(spacing: 0) {
                Text(card.rank.shortLabel)
                    .font(.system(size: min(width * 0.42, 18), weight: .heavy, design: .serif))
                Text(card.suit.symbol)
                    .font(.system(size: min(width * 0.38, 16)))
            }
            .foregroundStyle(pipColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var fullFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(2, corner * 0.6), style: .continuous)
                .strokeBorder(SpiderTheme.cardEdge.opacity(0.35), lineWidth: 0.8)
                .padding(3)

            cornerIndex
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(width * 0.08)
            cornerIndex
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(width * 0.08)

            centerContent
                .padding(.horizontal, width * 0.22)
                .padding(.vertical, height * 0.18)
        }
    }

    private var cornerIndex: some View {
        VStack(spacing: -1) {
            Text(card.rank.shortLabel)
                .font(.system(size: width * 0.17, weight: .bold, design: .serif))
            Text(card.suit.symbol)
                .font(.system(size: width * 0.15))
        }
        .foregroundStyle(pipColor)
    }

    @ViewBuilder
    private var centerContent: some View {
        switch card.rank {
        case .ace:
            Text(card.suit.symbol)
                .font(.system(size: width * 0.42))
                .foregroundStyle(pipColor)
        case .jack, .queen, .king:
            courtMedallion
        default:
            pipGrid
        }
    }

    // Geometric court medallion — double ring, serif letter, suit stamp.
    private var courtMedallion: some View {
        ZStack {
            Circle()
                .strokeBorder(Kaleido.gold.opacity(0.75), lineWidth: 1.2)
            Circle()
                .strokeBorder(pipColor.opacity(0.25), lineWidth: 0.8)
                .padding(3)
            VStack(spacing: -2) {
                Text(card.rank.shortLabel)
                    .font(.system(size: width * 0.26, weight: .bold, design: .serif))
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.14))
            }
            .foregroundStyle(pipColor)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Classic pip grid for 2–10; bottom-half pips flip, as on a real card.
    private var pipGrid: some View {
        GeometryReader { g in
            let pts = Self.pipLayout[card.rank.rawValue] ?? []
            ForEach(0..<pts.count, id: \.self) { i in
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.17))
                    .foregroundStyle(pipColor)
                    .rotationEffect(.degrees(pts[i].y > 0.5 ? 180 : 0))
                    .position(x: g.size.width * pts[i].x, y: g.size.height * pts[i].y)
            }
        }
    }

    private static let pipLayout: [Int: [CGPoint]] = [
        2: [CGPoint(x: 0.5, y: 0.12), CGPoint(x: 0.5, y: 0.88)],
        3: [CGPoint(x: 0.5, y: 0.12), CGPoint(x: 0.5, y: 0.50), CGPoint(x: 0.5, y: 0.88)],
        4: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        5: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.50),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        6: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12),
            CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.74, y: 0.50),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        7: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.31),
            CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.74, y: 0.50),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        8: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.31),
            CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.74, y: 0.50), CGPoint(x: 0.5, y: 0.69),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        9: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12),
            CGPoint(x: 0.26, y: 0.375), CGPoint(x: 0.74, y: 0.375), CGPoint(x: 0.5, y: 0.50),
            CGPoint(x: 0.26, y: 0.625), CGPoint(x: 0.74, y: 0.625),
            CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)],
        10: [CGPoint(x: 0.26, y: 0.12), CGPoint(x: 0.74, y: 0.12), CGPoint(x: 0.5, y: 0.245),
             CGPoint(x: 0.26, y: 0.375), CGPoint(x: 0.74, y: 0.375),
             CGPoint(x: 0.26, y: 0.625), CGPoint(x: 0.74, y: 0.625), CGPoint(x: 0.5, y: 0.755),
             CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.74, y: 0.88)]
    ]
}

// MARK: - Card back (kaleidoscope rosette in an ivory margin frame)

private struct SpiderCardBackView: View {
    let width: CGFloat
    let height: CGFloat
    var ornate: Bool = true

    private var corner: CGFloat { min(8, max(3.5, width * 0.13)) }
    private var inset: CGFloat { max(1.5, width * 0.07) }
    private var rosetteSize: CGFloat { min(width, height) * 0.72 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(SpiderTheme.ivory)
            RoundedRectangle(cornerRadius: max(2, corner - 2), style: .continuous)
                .fill(SpiderTheme.backGround)
                .padding(inset)
            if ornate {
                rosette
            }
            RoundedRectangle(cornerRadius: max(2, corner - 2), style: .continuous)
                .strokeBorder(Kaleido.gold.opacity(0.35), lineWidth: 0.8)
                .padding(inset)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(SpiderTheme.cardEdge, lineWidth: 1)
        }
        .frame(width: width, height: height)
    }

    // 12-fold rosette built from the Kaleido wheel — the one place the brand mark lives.
    private var rosette: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Ellipse()
                    .fill(Kaleido.wheel[i % Kaleido.wheel.count].opacity(0.85))
                    .frame(width: rosetteSize * 0.18, height: rosetteSize * 0.52)
                    .offset(y: -rosetteSize * 0.26)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Circle()
                .fill(Kaleido.gold)
                .frame(width: rosetteSize * 0.16, height: rosetteSize * 0.16)
        }
        .frame(width: rosetteSize, height: rosetteSize)
    }
}

// MARK: - Win banner

private struct SpiderWinBanner: View {
    let moves: Int
    let onNewDeal: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                SpiderCardFaceView(card: Card(rank: .king, suit: .spades), width: 64, height: 90)
                    .shadow(color: Kaleido.gold.opacity(0.6), radius: 12)

                Text("Table Cleared")
                    .font(Kaleido.title(30))
                    .foregroundStyle(.white)

                Text("All eight runs in \(moves) moves")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))

                Button(action: onNewDeal) {
                    Text("New Deal")
                        .font(.headline)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Kaleido.gold.gradient))
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.04))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel("New deal")
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(colors: [SpiderTheme.felt, SpiderTheme.feltLo],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Kaleido.gold.opacity(0.7), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 22, y: 10)
            )
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { appeared = true }
            }
        }
    }
}

#Preview {
    NavigationStack { SpiderView() }
}
