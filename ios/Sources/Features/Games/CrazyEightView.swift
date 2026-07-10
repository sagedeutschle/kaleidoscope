// PRISM: RELEASE Agent-Design(crazy8) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Table theme (game-local tokens; GamePigeon-energy teal card table)

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
    static let gold = Color(red: 1.00, green: 0.83, blue: 0.38)
    static let goldInk = Color(red: 0.28, green: 0.19, blue: 0.02)
}

// MARK: - Card faces (shared Solitaire face language, sized for a fanned hand)

private struct C8CardFace: View {
    let card: Card?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
            .fill(C8Theme.cardIvory)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                    .strokeBorder(C8Theme.cardFrame, lineWidth: 1)
                    .padding(3)
            )
            .overlay { centerGlyph }
            .overlay(alignment: .topLeading) { cornerIndex }
            .overlay(alignment: .bottomTrailing) { cornerIndex.rotationEffect(.degrees(180)) }
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
                    .strokeBorder(C8Theme.cardEdge, lineWidth: 1)
            )
            .frame(width: width, height: height)
    }

    @ViewBuilder private var centerGlyph: some View {
        if let card {
            VStack(spacing: -height * 0.02) {
                Text(card.rank.shortLabel)
                    .font(.system(size: width * 0.40, weight: .heavy, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.26, weight: .bold))
            }
            .foregroundStyle(ink(card))
        } else {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: width * 0.28, weight: .semibold))
                .foregroundStyle(C8Theme.blackInk.opacity(0.3))
        }
    }

    @ViewBuilder private var cornerIndex: some View {
        if let card {
            VStack(spacing: -2) {
                Text(card.rank.shortLabel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(ink(card))
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
    }

    private func ink(_ card: Card) -> Color {
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

private struct C8ChipStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(prominent ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(PrismetDesign.panelHi))
                    .overlay(Capsule().strokeBorder(
                        prominent ? Color.white.opacity(0.28) : PrismetDesign.outline, lineWidth: 1))
            )
            .foregroundStyle(prominent ? Color.white : PrismetDesign.ink)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - View

struct CrazyEightView: View {
    private static let accent = Color(red: 0.24, green: 0.52, blue: 0.47)
    private let accountID: UUID?
    private let playMode: GamePlayMode
    private let isOnline: Bool
    @ObservedObject private var online: OnlineMatchSession
    @StateObject private var persistence = PersistedGameSession<CrazyEightSnapshot>(gameID: .crazyEight)
    @AppStorage("crazyeight.aiELO") private var aiELO: Double = 1200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var seed: UInt64 = 51
    @State private var game = CrazyEightGame.newGame(seed: 51)
    @State private var isBotThinking = false
    @State private var appliedMoveCount = -1
    @State private var pendingEight: Card?
    @State private var showOpponentSheet = false

    init(accountID: UUID? = nil, playMode: GamePlayMode = .soloBot, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.playMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    private var mySide: CrazyEightPlayer { online.isHost ? .host : .guest }
    private var botPlayer: CrazyEightPlayer { .guest }
    private var humanPlayer: CrazyEightPlayer { .host }
    private var usesBot: Bool { playMode == .soloBot && !isOnline }
    private var visiblePlayer: CrazyEightPlayer {
        if isOnline { return mySide }
        if usesBot { return humanPlayer }
        return game.currentPlayer
    }
    private var opponent: CrazyEightPlayer { visiblePlayer.opponent }
    private var isBotTurn: Bool {
        usesBot && game.currentPlayer == botPlayer && !game.isGameOver
    }
    private var canAct: Bool {
        guard !game.isGameOver else { return false }
        guard !isBotTurn, !isBotThinking else { return false }
        guard !usesBot else { return game.currentPlayer == humanPlayer }
        guard isOnline else { return true }
        return game.currentPlayer == mySide && online.isMyTurn
    }

    private var subtitle: String {
        if let winner = game.winner {
            if isOnline { return winner == mySide ? "You win!" : "\(online.opponentName ?? "Friend") wins" }
            if usesBot { return winner == humanPlayer ? "You win!" : "Bot wins" }
            return "\(displayName(winner)) wins!"
        }
        if isOnline {
            return game.currentPlayer == mySide ? "Your turn" : "\(online.opponentName ?? "Friend")'s turn"
        }
        if isBotThinking {
            return "Bot is thinking…"
        }
        if usesBot {
            return game.currentPlayer == humanPlayer ? "Your turn" : "Bot to play"
        }
        return "\(displayName(game.currentPlayer)) to play"
    }

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(
                title: "Crazy 8",
                systemImage: "8.circle.fill",
                accent: Self.accent
            )

            tableSurface
                .frame(maxWidth: 680)

            controlRail
                .frame(maxWidth: 680)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(Self.accent)
        .navigationTitle("Crazy 8")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOpponentSheet) { opponentSheet }
        .onAppear {
            if isOnline {
                applyRemoteIfNeeded()
            } else {
                persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
                scheduleBotMoveIfNeeded()
            }
        }
        .onChange(of: aiELO) { _, _ in scheduleBotMoveIfNeeded() }
        .onChange(of: online.match?.moveCount) { _, _ in applyRemoteIfNeeded() }
        .onDisappear { if !isOnline { save(forceCloud: true) } }
    }

    // MARK: Table

    private var tableAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)
    }

    private var tableSurface: some View {
        GeometryReader { geo in
            ZStack {
                felt
                VStack(spacing: 6) {
                    opponentFan(width: geo.size.width)
                        .padding(.top, 16)
                    Spacer(minLength: 6)
                    HStack(spacing: 36) {
                        drawPileView
                        discardArea
                    }
                    Spacer(minLength: 6)
                    turnBanner
                    handFan(width: geo.size.width)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 12)
                suitPickerOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(C8Theme.feltRim, lineWidth: 3)
            )
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.32), radius: 14, y: 8)
            .animation(tableAnimation, value: game)
            .animation(tableAnimation, value: pendingEight)
        }
        .frame(minHeight: 430)
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

    // MARK: Opponent fan (face-down arc)

    private func opponentFan(width: CGFloat) -> some View {
        let n = game.hand(for: opponent).count
        let shown = min(n, 12)
        let cardW: CGFloat = 42
        let cardH: CGFloat = 60
        let usable = min(width - 90, 300)
        let step: CGFloat = shown > 1 ? min(24, (usable - cardW) / CGFloat(shown - 1)) : 0
        let fanW = cardW + step * CGFloat(max(0, shown - 1))
        let maxTilt = min(9.0, Double(shown) * 1.4)
        return ZStack {
            ForEach(0..<shown, id: \.self) { i in
                let t = shown > 1 ? Double(i) / Double(shown - 1) : 0.5
                let d = (t - 0.5) * 2
                C8CardBack(width: cardW, height: cardH)
                    .shadow(color: Color.black.opacity(0.12), radius: 1.5, y: 1)
                    .rotationEffect(.degrees((0.5 - t) * 2 * maxTilt), anchor: .top)
                    .offset(x: -fanW / 2 + cardW / 2 + step * CGFloat(i),
                            y: -8 * d * d)
            }
        }
        .frame(height: cardH + 14)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Text("\(displayName(opponent)) · \(game.hand(for: opponent).count)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(C8Theme.cardIvory)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(C8Theme.inkOnFelt.opacity(0.55)))
                .padding(.trailing, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName(opponent)) holds \(n) cards")
    }

    // MARK: Center piles

    private var drawPileCaption: String {
        if !game.drawPile.isEmpty { return "DRAW · \(game.drawPile.count)" }
        return game.discardPile.count > 1 ? "RESHUFFLE" : "EMPTY"
    }

    private var drawPileView: some View {
        Button {
            draw()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if game.drawPile.isEmpty {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(C8Theme.feltLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .frame(width: 58, height: 82)
                            .overlay(
                                Image(systemName: "arrow.2.circlepath")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(C8Theme.feltLine)
                            )
                    } else {
                        C8CardBack(width: 58, height: 82)
                            .offset(x: 3, y: 3)
                            .opacity(0.85)
                        C8CardBack(width: 58, height: 82)
                            .shadow(color: Color.black.opacity(0.16), radius: 2, y: 1)
                    }
                }
                Text(drawPileCaption)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .monospacedDigit()
                    .foregroundStyle(C8Theme.inkOnFelt.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canAct)
        .opacity(canAct ? 1 : 0.6)
        .accessibilityLabel("Draw pile")
        .accessibilityValue("\(game.drawPile.count) cards")
        .accessibilityHint("Draws a card and ends your turn")
    }

    private var discardTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .scale(scale: 1.16).combined(with: .opacity), removal: .opacity)
    }

    private var discardArea: some View {
        VStack(spacing: 6) {
            C8CardFace(card: game.discardTop, width: 76, height: 108)
                .shadow(color: game.isGameOver ? C8Theme.glow.opacity(0.9) : Color.black.opacity(0.18),
                        radius: game.isGameOver ? 12 : 3, y: game.isGameOver ? 0 : 2)
                .id(game.discardTop?.id ?? "empty")
                .transition(discardTransition)
            HStack(spacing: 5) {
                Text("SUIT")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(C8Theme.inkOnFelt.opacity(0.75))
                Text(game.currentSuit.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(suitColor(game.currentSuit))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(C8Theme.cardIvory))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Discard pile")
        .accessibilityValue("\(game.discardTop.map { "\($0.rank.shortLabel) of \($0.suit.rawValue)" } ?? "empty"), current suit \(game.currentSuit.rawValue)")
    }

    // MARK: Turn banner

    private var bannerBackground: Color {
        if game.isGameOver { return C8Theme.gold }
        return canAct ? C8Theme.inkOnFelt : Color.white.opacity(0.34)
    }

    private var bannerForeground: Color {
        if game.isGameOver { return C8Theme.goldInk }
        return canAct ? Color.white : C8Theme.inkOnFelt
    }

    private var turnBanner: some View {
        Text(subtitle)
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(bannerForeground)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(Capsule().fill(bannerBackground))
            .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: Hand fan (signature)

    private func handFan(width: CGFloat) -> some View {
        let hand = game.hand(for: visiblePlayer)
        let n = hand.count
        let cardW: CGFloat = 62
        let cardH: CGFloat = 88
        let usable = width - 36
        let step: CGFloat = n > 1 ? min(cardW * 0.60, (usable - cardW) / CGFloat(n - 1)) : 0
        let fanW = cardW + step * CGFloat(max(0, n - 1))
        let maxTilt = min(10.0, Double(n) * 1.5)
        let myTurnNow = canAct && game.currentPlayer == visiblePlayer
        return ZStack {
            ForEach(Array(hand.enumerated()), id: \.element.id) { i, card in
                let t = n > 1 ? Double(i) / Double(n - 1) : 0.5
                let d = (t - 0.5) * 2
                let playable = myTurnNow && game.canPlay(card)
                Button {
                    tapCard(card)
                } label: {
                    C8CardFace(card: card, width: cardW, height: cardH)
                        .shadow(color: playable ? C8Theme.glow.opacity(0.75) : Color.black.opacity(0.14),
                                radius: playable ? 8 : 2, y: playable ? 0 : 1)
                }
                .buttonStyle(.plain)
                .disabled(!playable)
                .opacity(playable ? 1 : (myTurnNow ? 0.55 : 0.8))
                .rotationEffect(.degrees(d * maxTilt), anchor: .bottom)
                .offset(x: -fanW / 2 + cardW / 2 + step * CGFloat(i),
                        y: 16 * d * d + (playable ? -13 : 0))
                .accessibilityLabel("\(card.rank.shortLabel) of \(card.suit.rawValue)")
                .accessibilityValue(playable ? "Playable" : "Not playable")
            }
        }
        .frame(height: cardH + 42)
        .frame(maxWidth: .infinity)
    }

    // MARK: Suit picker overlay (wild eight)

    @ViewBuilder
    private var suitPickerOverlay: some View {
        if pendingEight != nil {
            ZStack {
                Color.black.opacity(0.38)
                    .onTapGesture { pendingEight = nil }
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text("Wild eight!")
                        .font(PrismetDesign.title(21))
                        .foregroundStyle(C8Theme.blackInk)
                    Text("Choose the next suit")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(C8Theme.blackInk.opacity(0.6))
                    HStack(spacing: 10) {
                        ForEach(Suit.allCases) { suit in
                            Button {
                                if let eight = pendingEight {
                                    commitPlay(eight, declaredSuit: suit)
                                }
                            } label: {
                                Text(suit.symbol)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(suitColor(suit))
                                    .frame(width: 58, height: 58)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(C8Theme.cardIvory)
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(C8Theme.cardEdge, lineWidth: 1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(suit.rawValue.capitalized)
                        }
                    }
                    .padding(.top, 8)
                    Button {
                        pendingEight = nil
                    } label: {
                        Text("Never mind")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(C8Theme.blackInk.opacity(0.55))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.96, blue: 0.93))
                        .shadow(color: Color.black.opacity(0.30), radius: 18, y: 8)
                )
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
        }
    }

    // MARK: Control rail (quiet shell chips, off the felt)

    private var controlRail: some View {
        HStack(spacing: 10) {
            if isOnline {
                Button {
                    Task { await online.resign() }
                } label: {
                    Label("Resign", systemImage: "flag.fill")
                }
                .buttonStyle(C8ChipStyle(tint: Color(red: 0.72, green: 0.20, blue: 0.22), prominent: true))
                .accessibilityLabel("Resign the match")
            } else {
                Button {
                    newGame()
                } label: {
                    Label("New Game", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(C8ChipStyle(tint: Self.accent, prominent: game.isGameOver))
            }
            Spacer()
            if usesBot {
                Button {
                    showOpponentSheet = true
                } label: {
                    Label("\(tierName(forELO: Int(aiELO))) · \(Int(aiELO))", systemImage: "gearshape.fill")
                        .monospacedDigit()
                }
                .buttonStyle(C8ChipStyle(tint: Self.accent))
                .accessibilityLabel("Opponent difficulty")
                .accessibilityValue("ELO \(Int(aiELO)), \(tierName(forELO: Int(aiELO)))")
            }
        }
    }

    // MARK: Opponent sheet (difficulty behind the gear)

    private var opponentSheet: some View {
        VStack(spacing: 8) {
            Text("Opponent")
                .font(PrismetDesign.title(22))
                .foregroundStyle(PrismetDesign.ink)
            Text(tierName(forELO: Int(aiELO)))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Self.accent)
            Text("ELO \(Int(aiELO))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(PrismetDesign.ink2)
            Slider(value: $aiELO, in: 600...2400, step: 100) {
                Text("AI strength")
            }
            .tint(Self.accent)
            .padding(.top, 6)
            .accessibilityLabel("AI difficulty")
            .accessibilityValue("ELO \(Int(aiELO)), \(tierName(forELO: Int(aiELO)))")
            HStack {
                Text("600")
                Spacer()
                Text("2400")
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(PrismetDesign.ink3)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private func tierName(forELO elo: Int) -> String {
        switch elo {
        case ..<900: return "Beginner"
        case 900..<1300: return "Casual"
        case 1300..<1700: return "Intermediate"
        case 1700..<2100: return "Advanced"
        default: return "Expert"
        }
    }

    // MARK: Moves (model + online wiring — unchanged semantics)

    private func tapCard(_ card: Card) {
        guard canAct, game.currentPlayer == visiblePlayer, game.canPlay(card) else { return }
        if card.rank == .eight {
            pendingEight = card
        } else {
            commitPlay(card, declaredSuit: nil)
        }
    }

    private func commitPlay(_ card: Card, declaredSuit: Suit?) {
        guard canAct, game.playCard(card, declaredSuit: declaredSuit) else {
            pendingEight = nil
            return
        }
        pendingEight = nil
        if isOnline {
            sendMove()
        } else {
            save(forceCloud: game.isGameOver)
            scheduleBotMoveIfNeeded()
        }
    }

    private func draw() {
        guard canAct, game.drawCard() else { return }
        if isOnline {
            sendMove()
        } else {
            save(forceCloud: game.isGameOver)
            scheduleBotMoveIfNeeded()
        }
    }

    private func sendMove() {
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(snapshot()) else { return }
        appliedMoveCount = (online.match?.moveCount ?? appliedMoveCount) + 1
        let winnerIsMe = game.winner.map { $0 == mySide }
        Task {
            await online.sendMove(
                stateJSON: stateJSON,
                nextTurnIsMine: game.currentPlayer == mySide,
                finished: game.isGameOver,
                winnerIsMe: winnerIsMe
            )
        }
    }

    private func applyRemoteIfNeeded() {
        guard isOnline, let match = online.match, match.moveCount > appliedMoveCount else { return }
        guard let snapshot = try? GameSaveCodec.decodeSnapshot(CrazyEightSnapshot.self, from: match.stateJSON) else { return }
        restore(snapshot)
        appliedMoveCount = match.moveCount
    }

    private func snapshot() -> CrazyEightSnapshot {
        CrazyEightSnapshot(game: game, seed: seed)
    }

    private func restore(_ snapshot: CrazyEightSnapshot) {
        game = snapshot.game
        seed = snapshot.seed
        isBotThinking = false
        pendingEight = nil
        scheduleBotMoveIfNeeded()
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: game.winner == .host ? 1 : 0, forceCloud: forceCloud)
    }

    private func newGame() {
        seed = UInt64.random(in: 1...UInt64.max)
        game = CrazyEightGame.newGame(seed: seed)
        isBotThinking = false
        pendingEight = nil
        save(forceCloud: true)
        scheduleBotMoveIfNeeded()
    }

    private func scheduleBotMoveIfNeeded() {
        guard isBotTurn, !isBotThinking else { return }
        isBotThinking = true
        let snapshot = game
        let elo = Int(aiELO)
        let bot = botPlayer
        Task {
            try? await Task.sleep(nanoseconds: 340_000_000)
            let move = await Task.detached(priority: .userInitiated) {
                CrazyEightAI(player: bot, targetELO: elo).move(in: snapshot)
            }.value
            await MainActor.run {
                applyBotMove(move, expectedGame: snapshot, bot: bot)
            }
        }
    }

    @MainActor
    private func applyBotMove(_ move: CrazyEightMove?, expectedGame: CrazyEightGame, bot: CrazyEightPlayer) {
        guard usesBot, game == expectedGame, game.currentPlayer == bot, !game.isGameOver else {
            isBotThinking = false
            return
        }
        guard let move else {
            isBotThinking = false
            save(forceCloud: true)
            return
        }

        switch move {
        case .play(let card, let declaredSuit):
            _ = game.playCard(card, declaredSuit: declaredSuit)
        case .draw:
            _ = game.drawCard()
        }
        isBotThinking = false
        save(forceCloud: game.isGameOver)
    }

    private func displayName(_ player: CrazyEightPlayer) -> String {
        if isOnline { return player == mySide ? "You" : (online.opponentName ?? "Friend") }
        if usesBot { return player == humanPlayer ? "You" : "Bot" }
        return player == .host ? "Player 1" : "Player 2"
    }

    private func suitColor(_ suit: Suit) -> Color {
        suit.isRed ? C8Theme.redInk : C8Theme.blackInk
    }
}

#Preview {
    NavigationStack { CrazyEightView() }
}
