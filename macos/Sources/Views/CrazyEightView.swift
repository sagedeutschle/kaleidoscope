import SwiftUI

// MARK: - Table theme

private enum C8Theme {
    static let feltTop = Color(red: 0.55, green: 0.79, blue: 0.72)
    static let feltBottom = Color(red: 0.38, green: 0.65, blue: 0.58)
    static let feltRim = Color(red: 0.20, green: 0.40, blue: 0.36)
    static let feltLine = Color.white.opacity(0.30)
    static let inkOnFelt = Color(red: 0.07, green: 0.24, blue: 0.21)
    static let cardIvory = Color(red: 0.995, green: 0.985, blue: 0.955)
    static let cardEdge = Color.black.opacity(0.12)
    static let cardFrame = Color.black.opacity(0.07)
    static let backTeal = Color(red: 0.15, green: 0.42, blue: 0.45)
    static let backTealDeep = Color(red: 0.10, green: 0.32, blue: 0.36)
    static let backLattice = Color.white.opacity(0.18)
    static let redInk = Color(red: 0.77, green: 0.15, blue: 0.17)
    static let blackInk = Color(red: 0.13, green: 0.15, blue: 0.17)
    static let glow = Color(red: 1.00, green: 0.87, blue: 0.45)
}

private struct C8CardFace: View {
    let card: Card?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
            .fill(C8Theme.cardIvory)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                    .padding(3)
            )
            .overlay(alignment: .topLeading) { cornerIndex }
            .overlay(alignment: .bottomTrailing) { cornerIndex.rotationEffect(.degrees(180)) }
            .overlay(centerGlyph)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
                    .strokeBorder(C8Theme.cardEdge, lineWidth: 1)
            )
            .frame(width: width, height: height)
    }

    @ViewBuilder
    private var cornerIndex: some View {
        if let card {
            VStack(spacing: -2) {
                Text(card.rank.shortLabel)
                    .font(.system(size: min(width * 0.30, 18), weight: .heavy, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: min(width * 0.19, 12), weight: .bold))
            }
            .foregroundStyle(ink(for: card))
            .padding(4)
        }
    }

    @ViewBuilder
    private var centerGlyph: some View {
        if let card {
            VStack(spacing: -height * 0.02) {
                Text(card.rank.shortLabel)
                    .font(.system(size: width * 0.40, weight: .heavy, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.26, weight: .bold))
            }
            .foregroundStyle(ink(for: card))
        } else {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: width * 0.28, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.24))
        }
    }

    private func ink(for card: Card) -> Color {
        card.suit.isRed ? C8Theme.redInk : C8Theme.blackInk
    }
}

private struct C8CardBack: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
            .fill(C8Theme.cardIvory)
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                        .fill(LinearGradient(colors: [C8Theme.backTeal, C8Theme.backTealDeep],
                                             startPoint: .top, endPoint: .bottom))
                    Canvas { context, size in
                        var lines = Path()
                        var x = -size.height
                        while x < size.width {
                            lines.move(to: CGPoint(x: x, y: 0))
                            lines.addLine(to: CGPoint(x: x + size.height, y: size.height))
                            lines.move(to: CGPoint(x: x + size.height, y: 0))
                            lines.addLine(to: CGPoint(x: x, y: size.height))
                            x += 8
                        }
                        context.stroke(lines, with: .color(C8Theme.backLattice), lineWidth: 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: width * 0.09, style: .continuous))
                .padding(width * 0.07)
            )
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
                    .strokeBorder(C8Theme.cardEdge, lineWidth: 1)
            )
            .frame(width: width, height: height)
    }
}

private enum CrazyEightResultSheet: Identifiable {
    case aiLevel
    var id: String { "aiLevel" }
}

struct CrazyEightView: View {
    @ObservedObject private var session: CrazyEightSession
    @State private var pendingEight: Card?
    @State private var hoveredCardID: String?
    @State private var hoveredDeck = false
    @State private var botThinking = false
    @State private var showResultSheet: CrazyEightResultSheet?

    private let accent = FacetRegistry.accent(for: "crazyEight")
    private let botLevels = [600, 800, 1000, 1200, 1500, 1800, 2100, 2400]

    init(session: CrazyEightSession = CrazyEightSession()) {
        self.session = session
    }

    private var visiblePlayer: CrazyEightPlayer {
        session.visiblePlayer
    }

    private var canInteract: Bool {
        !session.game.isGameOver
        && !botThinking
        && (session.mode == .passAndPlay || session.game.currentPlayer == .host)
    }

    private var statusText: String {
        if let winner = session.game.winner {
            if session.mode == .passAndPlay {
                return "\(winner == .host ? "Host" : "Guest") won."
            }
            return winner == .host ? "You win." : "Bot wins."
        }

        if botThinking {
            return "Bot is thinking…"
        }

        if session.mode == .passAndPlay {
            return "\(session.game.currentPlayer == .host ? "Host" : "Guest") to play."
        }

        if session.game.currentPlayer == .host {
            return "Your turn."
        }
        return "Bot is deciding."
    }

    private var currentSuitText: String {
        "\(session.game.currentSuit.symbol) \(session.game.currentSuit.rawValue.capitalized)"
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            table
            controls
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .sheet(item: $showResultSheet) { _ in difficultySheet }
        .onAppear { scheduleBotMoveIfNeeded() }
        .onChange(of: session.game.currentPlayer) { _, _ in scheduleBotMoveIfNeeded() }
        .onChange(of: session.game) { _, _ in scheduleBotMoveIfNeeded() }
        .onChange(of: session.mode) { _, _ in scheduleBotMoveIfNeeded() }
    }

    private var header: some View {
        GameHeader(title: "Crazy 8", systemImage: "8.circle.fill", accent: accent, subtitle: statusText) {
            HStack(spacing: 8) {
                StatBadge(label: "Deck", value: "\(session.game.drawPile.count)", accent: accent)
                StatBadge(label: "Discard", value: "\(session.game.discardPile.count)", accent: accent)
            }
        }
        .frame(maxWidth: 760)
    }

    private var table: some View {
        GeometryReader { geo in
            ZStack {
                felt
                VStack(spacing: 16) {
                    opponentRow
                        .padding(.top, 14)

                    Spacer(minLength: 6)

                    HStack(spacing: 38) {
                        drawPile
                        discardArea
                    }
                    .frame(maxWidth: .infinity)

                    Text("Current suit \(currentSuitText)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(C8Theme.inkOnFelt.opacity(0.82))

                    handRow
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)

                }
                .padding(.horizontal, 14)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
            .frame(minHeight: 390)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(C8Theme.feltRim, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(10)
                    .padding(.top, 8)
                    .padding(.trailing, 10)
            }
            .overlay(suitPickerOverlay)
            .shadow(color: Color.black.opacity(0.32), radius: 14, y: 8)
        }
    }

    private var felt: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(colors: [C8Theme.feltTop, C8Theme.feltBottom],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RadialGradient(colors: [Color.white.opacity(0.15), .clear],
                               center: .center, startRadius: 10, endRadius: 340)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(C8Theme.feltLine, lineWidth: 1.5)
                    .padding(7)
            )
    }

    private var opponentRow: some View {
        let opponent = visiblePlayer.opponent
        let count = session.game.hand(for: opponent).count
        let shown = min(count, 12)
        let fanCardW: CGFloat = 36
        let fanCardH: CGFloat = 50
        let step = shown > 1 ? 17.0 : 0.0
        let fanW = fanCardW + CGFloat(max(0, shown - 1)) * step

        return ZStack(alignment: .center) {
            ForEach(0..<shown, id: \.self) { index in
                let t = shown > 1 ? Double(index) / Double(shown - 1) : 0.5
                let d = (t - 0.5) * 2
                C8CardBack(width: fanCardW, height: fanCardH)
                    .rotationEffect(.degrees((0.5 - t) * 4), anchor: .top)
                    .offset(x: -fanW / 2 + fanCardW / 2 + CGFloat(index) * step,
                            y: -8 * d * d)
            }
            Text("\(visiblePlayer == .host ? "Host" : "Guest") holds \(count)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(C8Theme.cardIvory)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(C8Theme.inkOnFelt.opacity(0.55)))
                .padding(.leading, fanW - 20)
        }
        .frame(height: fanCardH + 16)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(opponent == .host ? "Host" : "Guest") hand of \(count) cards")
    }

    private var drawPile: some View {
        VStack(spacing: 8) {
            Button {
                draw()
            } label: {
                ZStack {
                    if session.game.drawPile.isEmpty {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .frame(width: 62, height: 86)
                            .overlay(
                                Image(systemName: "arrow.2.circlepath")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            )
                    } else {
                        C8CardBack(width: 62, height: 86)
                            .offset(x: 3, y: 3)
                            .opacity(0.85)
                        C8CardBack(width: 62, height: 86)
                            .shadow(color: Color.black.opacity(0.16), radius: 2, y: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canInteract || !session.canDraw(as: visiblePlayer))
            .scaleEffect(hoveredDeck ? 1.03 : 1)
            .onHover { isHovered in
                withAnimation(.easeOut(duration: 0.14)) {
                    hoveredDeck = isHovered && canInteract && session.canDraw(as: visiblePlayer)
                }
            }
            Text(session.game.drawPile.isEmpty ? (session.game.discardPile.count > 1 ? "RESHUFFLE" : "EMPTY") : "DRAW · \(session.game.drawPile.count)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.7)
                .monospacedDigit()
                .foregroundStyle(C8Theme.inkOnFelt.opacity(0.75))
        }
        .accessibilityLabel("Draw pile")
    }

    private var discardArea: some View {
        VStack(spacing: 7) {
            C8CardFace(card: session.game.discardTop, width: 78, height: 110)
                .shadow(color: session.game.isGameOver ? C8Theme.glow.opacity(0.9) : Color.black.opacity(0.18),
                        radius: session.game.isGameOver ? 12 : 3, y: session.game.isGameOver ? 0 : 2)
                .id(session.game.discardTop?.id ?? "empty")
            Text("SUIT")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(C8Theme.inkOnFelt.opacity(0.75))
            Text(session.game.currentSuit.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(session.game.currentSuit.isRed ? C8Theme.redInk : C8Theme.blackInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(C8Theme.cardIvory))
        }
    }

    private var handRow: some View {
        let hand = session.game.hand(for: visiblePlayer)
        let handCount = hand.count
        let width: CGFloat = 66
        let height: CGFloat = 95
        let spacing = CGFloat(max(1, handCount))
        let step = handCount > 1 ? min(width * 0.58, CGFloat(220) / spacing) : 0
        let fanW = width + CGFloat(max(0, handCount - 1)) * step
        let maxTilt = min(10.0, Double(handCount) * 1.5)

        return HStack(spacing: 0) {
            ForEach(Array(hand.enumerated()), id: \.element.id) { item in
                let index = item.offset
                let card = item.element
                let t = handCount > 1 ? Double(index) / Double(handCount - 1) : 0.5
                let d = (t - 0.5) * 2

                let cardPlayable = canInteract && visiblePlayer == session.game.currentPlayer && session.canPlay(card, as: visiblePlayer)
                let isHovered = hoveredCardID == card.id
                let yOffset = CGFloat(6 * d * d)
                Button {
                    tapCard(card)
                } label: {
                    C8CardFace(card: card, width: width, height: height)
                        .overlay {
                            if cardPlayable {
                                RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
                                    .strokeBorder(C8Theme.glow, lineWidth: 1.8)
                            }
                        }
                        .shadow(color: cardPlayable ? C8Theme.glow.opacity(0.8) : Color.black.opacity(0.16),
                                radius: 8, y: 2)
                        .offset(y: isHovered ? -14 : 6 * d * d)
                        .scaleEffect(isHovered ? 1.07 : 1.0)
                        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: hoveredCardID)
                }
                .buttonStyle(.plain)
                .disabled(!cardPlayable)
                .opacity(cardPlayable || !canInteract ? 0.9 : 0.45)
                .rotationEffect(.degrees(d * maxTilt), anchor: .bottom)
                .offset(x: -fanW / 2 + width / 2 + CGFloat(index) * step)
                .onHover { isHovered in
                    hoveredCardID = isHovered ? card.id : nil
                }
            }
        }
        .frame(height: height + 20, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
    }

    @ViewBuilder
    private var suitPickerOverlay: some View {
        if let pending = pendingEight {
            ZStack {
                Color.black.opacity(0.35)
                    .onTapGesture { pendingEight = nil }
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Wild eight!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Choose a suit for \(pending.suit.rawValue.capitalized)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        ForEach(Suit.allCases) { suit in
                            Button {
                                commitPlay(card: pending, declaredSuit: suit)
                            } label: {
                                Text(suit.symbol)
                                    .font(.system(size: 32, weight: .bold))
                                    .frame(width: 58, height: 58)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(C8Theme.cardIvory)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(C8Theme.cardEdge, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Play eight as \(suit.rawValue.capitalized)")
                        }
                    }
                    .padding(.top, 4)
                    Button {
                        pendingEight = nil
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.96, blue: 0.93))
                        .shadow(color: Color.black.opacity(0.28), radius: 14, y: 8)
                )
            }
            .padding(40)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                newGame()
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

            Button {
                session.setMode(session.mode == .soloBot ? .passAndPlay : .soloBot)
            } label: {
                Label(session.mode == .soloBot ? "Play Friend" : "AI Opponent",
                      systemImage: session.mode == .soloBot ? "person.2.fill" : "brain.fill")
            }
            .buttonStyle(GlassButtonStyle())

            Button {
                showResultSheet = .aiLevel
            } label: {
                Label("AI \(session.aiELO)", systemImage: "speedometer")
            }
            .buttonStyle(GlassButtonStyle())

            Spacer()

            Menu {
                Button("Save") { session.saveNow() }
                Button("Load") { session.reloadSavedState() }
            } label: {
                Label("State", systemImage: "externaldrive")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private var difficultySheet: some View {
        VStack(spacing: 14) {
            Text("AI Difficulty")
                .font(Kaleido.title(24))
            Text("ELO")
                .font(.title2.weight(.bold))
            Text("\(session.aiELO)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
            ForEach(botLevels, id: \.self) { level in
                Button {
                    session.aiELO = level
                } label: {
                    HStack {
                        Text("ELO \(level)")
                        Spacer()
                        Text(level == session.aiELO ? "Active" : "Use")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(level == session.aiELO ? accent : .secondary)
            }
            Button("Done") { showResultSheet = nil }
                .buttonStyle(AccentButtonStyle(accent: accent))
        }
        .padding(24)
        .frame(minWidth: 280)
    }

    private func tapCard(_ card: Card) {
        guard canInteract else { return }
        guard visiblePlayer == session.game.currentPlayer else { return }
        guard session.canPlay(card, as: visiblePlayer) else { return }

        if card.rank == .eight {
            pendingEight = card
        } else {
            commitPlay(card: card, declaredSuit: nil)
        }
    }

    private func commitPlay(card: Card, declaredSuit: Suit?) {
        guard canInteract else {
            pendingEight = nil
            return
        }
        guard session.playCard(card, declaredSuit: declaredSuit) else {
            pendingEight = nil
            return
        }
        pendingEight = nil
        scheduleBotMoveIfNeeded()
    }

    private func draw() {
        guard canInteract else { return }
        guard visiblePlayer == session.game.currentPlayer else { return }
        guard session.drawCard() else { return }
        scheduleBotMoveIfNeeded()
    }

    private func newGame() {
        pendingEight = nil
        hoveredCardID = nil
        botThinking = false
        session.newGame()
        if session.mode == .soloBot {
            scheduleBotMoveIfNeeded()
        }
    }

    private func scheduleBotMoveIfNeeded() {
        guard session.isBotTurn, !botThinking else { return }
        botThinking = true
        let snapshot = session.snapshot()
        let elo = session.aiELO
        let current = session.game

        Task {
            try? await Task.sleep(nanoseconds: 240_000_000)
            let move = await Task.detached(priority: .userInitiated) {
                CrazyEightAI(player: .guest, targetELO: elo).move(in: current)
            }.value

            await MainActor.run {
                applyBotMove(move, expectedGame: snapshot.game)
            }
        }
    }

    @MainActor
    private func applyBotMove(_ move: CrazyEightMove?, expectedGame: CrazyEightGame) {
        guard session.game == expectedGame else {
            botThinking = false
            return
        }
        guard session.mode == .soloBot, session.isBotTurn, let move else {
            botThinking = false
            return
        }

        let _ = session.apply(move)
        botThinking = false
    }
}
