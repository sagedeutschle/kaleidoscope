// PRISM: RELEASE Agent-Design(chess) 2026-07-03 - v10 design pass
import SwiftUI

/// iOS Chess — solo uses Stockfish for Black, while local mode lets both sides
/// share the same phone.
///
/// v10 "Study Table" chrome: the whole screen is one table — a felt ground
/// derived from the selected board theme's dark square, the board framed in
/// wood, and player plaques above/below the board carrying the turn indicator,
/// captured-piece trays (wK..bP assets at mini size), and the material score.
/// Settings collapse into a compact table rail (theme swatch chips + a 2D/3D
/// flip chip) and an Opponent card. All session, online, persistence, and
/// haptic wiring is unchanged; both board renderers receive identical props.
struct ChessView: View {
    private let accountID: UUID?
    private let playMode: GamePlayMode
    private let isOnline: Bool
    @ObservedObject private var online: OnlineMatchSession
    @State private var appliedMoveCount = -1
    @StateObject private var persistence = PersistedGameSession<ChessSnapshot>(gameID: .chess)
    @State private var position = Position.initial
    @State private var selected: Square?
    @State private var targets: Set<Int> = []
    @State private var status: GameStatus = .ongoing
    @State private var thinking = false

    // Last move highlight (soft accent tint on from + to squares).
    @State private var lastFrom: Int?
    @State private var lastTo: Int?

    // Sensory feedback triggers (flip/bump when the event happens).
    @State private var moveTick = 0       // light impact on a normal move/tap
    @State private var captureTick = 0    // medium impact on a capture
    @State private var didWin = false     // .success on your checkmate
    @State private var didLose = false    // .error on losing / being checkmated
    @State private var checkTick = 0      // subtle warning when a side is in check

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ai: StockfishAI = { let a = StockfishAI(); a.level = 3; return a }()

    // AI strength as ELO, persisted per device. Drives Stockfish on appear
    // and whenever the slider changes.
    @AppStorage("chess.aiELO") private var aiELO: Double = 1200

    // Board rendering: 3D SceneKit board or a flat 2D grid. Persisted so
    // the player's choice sticks. Toggled live via the 2D/3D flip chip.
    @AppStorage("chess.is3D") private var is3D: Bool = false  // default to the 2D board
    @State private var dimensionTick = 0   // selection haptic when flipping 2D/3D

    // Board theme (chess.com-style palettes), persisted per device. Stored as the
    // theme id; `theme` resolves it back, defaulting to chess.com green. Mirrors
    // the macOS app's board themes so both look the same.
    @AppStorage("chess.boardThemeID") private var boardThemeID: String = ChessBoardTheme.green.id
    private var theme: ChessBoardTheme { ChessBoardTheme.resolve(boardThemeID) }
    @State private var themeTick = 0       // selection haptic when changing theme

    /// Study-table chrome palette, derived live from the selected board theme
    /// so the table retints with the board.
    private var study: ChessStudyTheme { ChessStudyTheme(theme) }

    init(accountID: UUID? = nil, playMode: GamePlayMode = .soloBot, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.playMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    /// Host plays white (white moves first).
    private var mySide: PieceColor { online.isHost ? .white : .black }

    private var canMoveNow: Bool {
        guard !status.isTerminal, !thinking else { return false }
        guard isOnline else { return true }
        return position.sideToMove == mySide && online.isMyTurn
    }

    var body: some View {
        VStack(spacing: 13) {
            plaque(for: topSide)
            board
            plaque(for: bottomSide)
            tableRail
            if usesBot {
                opponentCard
            }
            controlRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 640)   // iPad: the table setting stays a centered column
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tableBackground)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Chess")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy(duration: 0.16), value: thinking)
        .gameFeedback(.pieceMove, trigger: moveTick)
        .gameFeedback(.pieceCapture, trigger: captureTick)
        .gameFeedback(.select, trigger: checkTick)
        .gameFeedback(.win, trigger: didWin)
        .gameFeedback(.lose, trigger: didLose)
        .gameFeedback(.select, trigger: dimensionTick)
        .gameFeedback(.select, trigger: themeTick)
        .onAppear {
            if isOnline {
                applyRemoteIfNeeded()
            } else {
                ai.configure(elo: Int(aiELO))
                persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
                if usesBot, position.sideToMove == .black, !status.isTerminal {
                    aiMove()
                }
            }
        }
        .onChange(of: online.match?.moveCount) { _, _ in applyRemoteIfNeeded() }
        .onDisappear {
            if !isOnline { save(forceCloud: true) }
        }
        .onChange(of: aiELO) { _, newValue in
            ai.configure(elo: Int(newValue))
        }
        .alert(
            "Connection hiccup",
            isPresented: Binding(
                get: { online.lastError != nil },
                set: { if !$0 { online.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(online.lastError ?? "")
        }
    }

    private var usesBot: Bool {
        playMode == .soloBot
    }

    // MARK: - Table geography

    /// The near (bottom) seat: your side online; White otherwise.
    private var bottomSide: PieceColor { isOnline ? mySide : .white }
    private var topSide: PieceColor { bottomSide.opposite }

    /// Stockfish sits across the table only in solo-bot games.
    private func botPlays(_ side: PieceColor) -> Bool {
        !isOnline && usesBot && side == .black
    }

    /// Whether this seat is the local user (drives "Your move" phrasing).
    private func isUserSide(_ side: PieceColor) -> Bool {
        if isOnline { return side == mySide }
        if usesBot { return side == .white }
        return false   // local: both seats are shared
    }

    // MARK: - Felt table ground

    private var tableBackground: some View {
        ZStack {
            study.feltEdge
            RadialGradient(
                colors: [study.felt, study.feltEdge],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 60,
                endRadius: 640
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Player plaques (the signature)

    private func plaque(for side: PieceColor) -> some View {
        let active = position.sideToMove == side && !status.isTerminal
        let isThinking = thinking && botPlays(side)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                Image((side == .white ? "w" : "b") + "K")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(plaqueName(for: side))
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(study.ivory)
                    .lineLimit(1)
                capturedRow(for: side)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if active { turnDot(pulsing: isThinking) }
                    Text(side == .white ? "WHITE" : "BLACK")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(study.ivoryDim)
                }
                let state = stateText(for: side)
                if !state.isEmpty {
                    Text(state)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stateColor(for: side))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(study.rail)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            active ? study.brass.opacity(0.55) : Color.white.opacity(0.08),
                            lineWidth: active ? 1.5 : 1
                        )
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plaqueAccessibility(for: side))
    }

    /// Captured-piece tray + material advantage, using the same wK..bP assets
    /// as the board at mini size. Fixed height so an empty tray doesn't jiggle.
    private func capturedRow(for side: PieceColor) -> some View {
        let captured = capturedPieces(by: side)
        let adv = advantage(for: side)
        let prefix = side == .white ? "b" : "w"   // you capture the other color
        return HStack(spacing: 5) {
            HStack(spacing: -7) {
                ForEach(Array(captured.enumerated()), id: \.offset) { _, type in
                    Image(prefix + type.letter)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .shadow(
                            color: prefix == "b" ? Color.white.opacity(0.35) : Color.black.opacity(0.45),
                            radius: 1,
                            y: prefix == "b" ? 0 : 0.6
                        )
                }
            }
            if adv > 0 {
                Text("+\(adv)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(study.brass)
            }
        }
        .frame(height: 16, alignment: .leading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func turnDot(pulsing: Bool) -> some View {
        let dot = Circle()
            .fill(study.brass)
            .frame(width: 7, height: 7)
            .shadow(color: study.brass.opacity(0.8), radius: 3)
        if pulsing && !reduceMotion {
            dot.phaseAnimator([1.0, 0.3]) { view, phase in
                view.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
        } else {
            dot
        }
    }

    private func plaqueName(for side: PieceColor) -> String {
        if isOnline { return side == mySide ? "You" : (online.opponentName ?? "Friend") }
        if usesBot { return side == .white ? "You" : "Stockfish" }
        return side == .white ? "White" : "Black"
    }

    private func stateText(for side: PieceColor) -> String {
        if case .checkmate(let winner) = status { return winner == side ? "Winner" : "" }
        if status.isTerminal { return "Draw" }
        if case .check(let checked) = status, checked == side { return "Check!" }
        if thinking, botPlays(side) { return "Thinking…" }
        if position.sideToMove == side { return isUserSide(side) ? "Your move" : "To move" }
        return ""
    }

    private func stateColor(for side: PieceColor) -> Color {
        if case .checkmate(let winner) = status, winner == side { return study.brass }
        if case .check(let checked) = status, checked == side {
            return Color(red: 0.95, green: 0.47, blue: 0.40)
        }
        if thinking, botPlays(side) { return study.ivoryDim }
        if position.sideToMove == side, !status.isTerminal { return study.brass }
        return study.ivoryDim
    }

    private func plaqueAccessibility(for side: PieceColor) -> String {
        var parts = ["\(plaqueName(for: side)), \(side == .white ? "White" : "Black")"]
        let captured = capturedPieces(by: side)
        if !captured.isEmpty {
            parts.append("captured \(captured.count) piece\(captured.count == 1 ? "" : "s")")
        }
        let adv = advantage(for: side)
        if adv > 0 { parts.append("up \(adv) point\(adv == 1 ? "" : "s") of material") }
        let state = stateText(for: side)
        if !state.isEmpty { parts.append(state) }
        return parts.joined(separator: ", ")
    }

    /// Opponent pieces missing from the board, queen-first. Promotion overshoot
    /// is clamped so the tray never goes negative.
    private func capturedPieces(by side: PieceColor) -> [PieceType] {
        var missing = Self.fullSideCounts
        for piece in position.board.compactMap({ $0 }) where piece.color == side.opposite {
            if let left = missing[piece.type] { missing[piece.type] = left - 1 }
        }
        let order: [PieceType] = [.queen, .rook, .bishop, .knight, .pawn]
        var result: [PieceType] = []
        for type in order {
            let count = max(0, missing[type] ?? 0)
            if count > 0 { result.append(contentsOf: Array(repeating: type, count: count)) }
        }
        return result
    }

    private static let fullSideCounts: [PieceType: Int] = [
        .pawn: 8, .knight: 2, .bishop: 2, .rook: 2, .queen: 1
    ]

    /// Material advantage in pawns for this side (0 when behind or level).
    private func advantage(for side: PieceColor) -> Int {
        let pawns = materialScore / 100
        return side == .white ? max(0, pawns) : max(0, -pawns)
    }

    // MARK: - Table rail (theme swatches + 2D/3D flip chip)

    private var tableRail: some View {
        HStack(spacing: 9) {
            ForEach(ChessBoardTheme.all) { themeChip($0) }
            Spacer(minLength: 8)
            dimensionChip
        }
    }

    /// Mini two-square swatch chip built from the theme's own palette data.
    private func themeChip(_ candidate: ChessBoardTheme) -> some View {
        let isSelected = candidate.id == boardThemeID
        return Button {
            guard boardThemeID != candidate.id else { return }
            boardThemeID = candidate.id
            themeTick &+= 1
        } label: {
            HStack(spacing: 0) {
                Rectangle().fill(candidate.lightSquare.color)
                Rectangle().fill(candidate.darkSquare.color)
            }
            .frame(width: 42, height: 27)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isSelected ? study.brass : Color.white.opacity(0.16),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(0.30), radius: 2, y: 1.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.name) board theme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var dimensionChip: some View {
        Button {
            is3D.toggle()
            dimensionTick &+= 1
        } label: {
            HStack(spacing: 2) {
                dimensionSegment("2D", active: !is3D)
                dimensionSegment("3D", active: is3D)
            }
            .padding(2)
            .background(Capsule().fill(Color.black.opacity(0.25)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Board view")
        .accessibilityValue(is3D ? "3D" : "2D")
        .accessibilityHint("Switches between the flat and three-dimensional board")
    }

    private func dimensionSegment(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(active ? Color.black.opacity(0.75) : study.ivoryDim)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(active ? study.brass : Color.clear))
    }

    // MARK: - Opponent card (ELO slider lives here, binding unchanged)

    private var opponentCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("OPPONENT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(study.ivoryDim)
                Spacer()
                Text("ELO \(Int(aiELO))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(study.brass)
            }
            Text(tierName(forELO: Int(aiELO)))
                .font(Kaleido.title(20))
                .foregroundStyle(study.ivory)
            Slider(value: $aiELO, in: 600...2400, step: 100) {
                Text("AI strength")
            }
            .tint(study.brass)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(study.rail)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI difficulty")
        .accessibilityValue("ELO \(Int(aiELO)), \(tierName(forELO: Int(aiELO)))")
    }

    /// Human-readable strength tier for a given ELO.
    private func tierName(forELO elo: Int) -> String {
        switch elo {
        case ..<900:      return "Beginner"
        case 900..<1300:  return "Casual"
        case 1300..<1700: return "Intermediate"
        case 1700..<2100: return "Advanced"
        default:          return "Expert"
        }
    }

    // MARK: - Controls

    @ViewBuilder private var controlRow: some View {
        if isOnline {
            if online.phase == .finished || status.isTerminal {
                Text("Head back for a rematch — host a fresh code.")
                    .font(.caption)
                    .foregroundStyle(study.ivoryDim)
            } else {
                Button(role: .destructive) {
                    Task { await online.resign() }
                } label: {
                    Text("Resign")
                }
                .buttonStyle(StudyChipButtonStyle(
                    fill: Color(red: 0.38, green: 0.13, blue: 0.11),
                    stroke: Color(red: 0.72, green: 0.32, blue: 0.26).opacity(0.5),
                    ink: study.ivory
                ))
            }
        } else {
            Button { newGame() } label: {
                Text("New Game")
            }
            .buttonStyle(StudyChipButtonStyle(
                fill: study.rail,
                stroke: study.brass.opacity(0.45),
                ink: study.ivory
            ))
        }
    }

    // MARK: - Board (renderers unchanged; frame + ceremony are chrome)

    @ViewBuilder private var boardContent: some View {
        if is3D {
            ChessSceneKitBoardView(
                position: position,
                selectedSquare: selected,
                targets: targets,
                lastFrom: lastFrom,
                lastTo: lastTo,
                theme: theme,
                onSquareTap: tap
            )
        } else {
            flatBoard
        }
    }

    private var board: some View {
        boardContent
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(study.brass.opacity(0.30), lineWidth: 1)
            )
            .overlay(endgameOverlay)
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [study.frameHi, study.frameLo],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.30), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8),
                value: status.isTerminal
            )
    }

    /// Endgame ceremony: dim the board and drop a banner with the winning
    /// side's king. Non-interactive so 3D orbiting keeps working; the existing
    /// win/lose haptics are the cue.
    @ViewBuilder private var endgameOverlay: some View {
        if status.isTerminal {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                endBanner
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
            .allowsHitTesting(false)
        }
    }

    private var endBanner: some View {
        VStack(spacing: 8) {
            if case .checkmate(let winner) = status {
                ChessPieceGlyph(piece: Piece(color: winner, type: .king), size: 54, theme: theme)
                Text("Checkmate")
                    .font(Kaleido.title(25))
                    .foregroundStyle(study.ivory)
            } else {
                HStack(spacing: -6) {
                    ChessPieceGlyph(piece: Piece(color: .white, type: .king), size: 40, theme: theme)
                    ChessPieceGlyph(piece: Piece(color: .black, type: .king), size: 40, theme: theme)
                }
                Text(status == .stalemate ? "Stalemate" : "Draw")
                    .font(Kaleido.title(25))
                    .foregroundStyle(study.ivory)
            }
            Text(endSubtitle)
                .font(.subheadline)
                .foregroundStyle(study.ivoryDim)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(study.rail)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(study.brass.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        )
        .accessibilityElement(children: .combine)
    }

    private var endSubtitle: String {
        switch status {
        case .checkmate(let winner):
            if isOnline {
                return winner == mySide ? "You win!" : "\(online.opponentName ?? "Friend") wins."
            }
            if usesBot { return winner == .white ? "You win!" : "Stockfish wins." }
            return winner == .white ? "White wins." : "Black wins."
        case .stalemate:
            return "No legal moves — the game is drawn."
        case .draw:
            return "The game is drawn."
        default:
            return ""
        }
    }

    /// Flat 2D board: an 8×8 grid drawn top-down (rank 8 at the top, a-file on the
    /// left) using the same `squareView` cells, selection/last-move/target overlays,
    /// and tap handling as the 3D board.
    private var flatBoard: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let sq = side / 8
            VStack(spacing: 0) {
                ForEach(Array((0..<8).reversed()), id: \.self) { rank in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { file in
                            squareView(file: file, rank: rank, size: sq)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func squareView(file: Int, rank: Int, size: CGFloat) -> some View {
        let sq = Square(file: file, rank: rank)
        let isLight = (file + rank) % 2 == 1
        let base = (isLight ? theme.lightSquare : theme.darkSquare).color
        let isSelected = selected?.index == sq.index
        let isLastMove = sq.index == lastFrom || sq.index == lastTo
        return ZStack {
            Rectangle().fill(base)
            // Theme tint on the last move's from+to squares so it's easy to read.
            if isLastMove {
                Rectangle().fill(theme.lastMove.color)
            }
            if isSelected {
                Rectangle().fill(theme.selection.color)
            }
            if targets.contains(sq.index) {
                Circle().fill(theme.legalDot.color.opacity(0.9)).frame(width: size * 0.32, height: size * 0.32)
                    .transition(.scale.combined(with: .opacity))
            }
            if let piece = position.piece(at: sq) {
                ChessPieceGlyph(piece: piece, size: size * 0.84, theme: theme)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { tap(sq) }
    }

    private struct ChessPieceGlyph: View {
        let piece: Piece
        let size: CGFloat
        let theme: ChessBoardTheme

        private var assetName: String {
            (piece.color == .white ? "w" : "b") + piece.type.letter
        }

        private var outlineColor: Color {
            piece.color == .white ? Color.black.opacity(0.84) : Color.white.opacity(0.90)
        }

        private static let outlineOffsets: [(CGFloat, CGFloat)] = [
            (-1, 0), (1, 0), (0, -1), (0, 1),
            (-1, -1), (1, -1), (-1, 1), (1, 1)
        ]

        var body: some View {
            let contour = size * 0.03
            ZStack {
                ForEach(Array(Self.outlineOffsets.enumerated()), id: \.offset) { _, offset in
                    Image(assetName)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .foregroundStyle(outlineColor)
                        .offset(x: offset.0 * contour, y: offset.1 * contour)
                }
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
            .shadow(color: .black.opacity(0.24), radius: max(size * 0.018, 0.7), y: max(size * 0.018, 0.7))
            .allowsHitTesting(false)
        }
    }

    private func tap(_ sq: Square) {
        guard !thinking, !status.isTerminal else { return }
        guard !usesBot || position.sideToMove == .white else { return }
        if isOnline { guard canMoveNow else { return } }
        if selected != nil, targets.contains(sq.index) {
            let moves = MoveGenerator.legalMoves(from: selected!, in: position).filter { $0.to.index == sq.index }
            let move = moves.first(where: { $0.promotion == .queen }) ?? moves.first
            if let move {
                let isCapture = position.piece(at: move.to) != nil
                applyPlayerMove(move, isCapture: isCapture)
                if usesBot, !status.isTerminal { aiMove() }
            }
            return
        }
        if let piece = position.piece(at: sq),
           piece.color == position.sideToMove,
           (!isOnline || piece.color == mySide),
           (!usesBot || piece.color == .white) {
            withAnimation(.snappy(duration: 0.16)) {
                selected = sq
                targets = Set(MoveGenerator.legalMoves(from: sq, in: position).map { $0.to.index })
            }
        } else {
            withAnimation(.snappy(duration: 0.16)) {
                selected = nil; targets = []
            }
        }
    }

    private func applyPlayerMove(_ move: Move, isCapture: Bool) {
        let movingColor = position.piece(at: move.from)?.color
        withAnimation(.snappy(duration: 0.16)) {
            position = MoveGenerator.makeMove(move, in: position)
            selected = nil; targets = []
            lastFrom = move.from.index; lastTo = move.to.index
        }
        status = MoveGenerator.status(of: position)
        // Haptics: medium thump on a capture, otherwise a light tap.
        if isCapture { captureTick &+= 1 } else { moveTick &+= 1 }
        emitStatusFeedback(playerIsWhite: movingColor == .white)
        if isOnline {
            sendMyMove()
        } else {
            save(forceCloud: status.isTerminal)
        }
    }

    /// Ship my move to the online match: the whole post-move snapshot plus outcome.
    private func sendMyMove() {
        let snap = ChessSnapshot(
            position: position,
            selected: nil,
            targets: [],
            status: status,
            lastFrom: lastFrom,
            lastTo: lastTo
        )
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(snap) else { return }
        appliedMoveCount = (online.match?.moveCount ?? appliedMoveCount) + 1
        let finished = status.isTerminal
        var winnerIsMe: Bool? = nil
        if case .checkmate(let winner) = status {
            winnerIsMe = winner == mySide
        }
        // Chess always alternates turns.
        let nextTurnIsMine = position.sideToMove == mySide
        Task {
            await online.sendMove(
                stateJSON: stateJSON,
                nextTurnIsMine: nextTurnIsMine,
                finished: finished,
                winnerIsMe: winnerIsMe
            )
        }
    }

    private func applyRemoteIfNeeded() {
        guard isOnline, let match = online.match, match.moveCount > appliedMoveCount else { return }
        guard let snap = try? GameSaveCodec.decodeSnapshot(ChessSnapshot.self, from: match.stateJSON) else { return }
        let hadFewerPieces = snap.position.board.compactMap({ $0 }).count < position.board.compactMap({ $0 }).count
        withAnimation(.snappy(duration: 0.16)) {
            position = snap.position
            selected = nil; targets = []
            lastFrom = snap.lastFrom; lastTo = snap.lastTo
        }
        status = snap.status
        appliedMoveCount = match.moveCount
        if hadFewerPieces { captureTick &+= 1 } else { moveTick &+= 1 }
        if isOnline {
            switch status {
            case .checkmate(let winner):
                if winner == mySide { didWin.toggle() } else { didLose.toggle() }
            case .check:
                checkTick &+= 1
            default:
                break
            }
        }
    }

    private func aiMove() {
        thinking = true
        Task { @MainActor in
            let snapshot = position
            let move = await ai.bestMove(for: snapshot)
            if let move {
                let isCapture = snapshot.piece(at: move.to) != nil
                withAnimation(.snappy(duration: 0.16)) {
                    position = MoveGenerator.makeMove(move, in: snapshot)
                    lastFrom = move.from.index; lastTo = move.to.index
                }
                status = MoveGenerator.status(of: position)
                if isCapture { captureTick &+= 1 } else { moveTick &+= 1 }
                emitStatusFeedback(playerIsWhite: true)
            }
            thinking = false
            save(forceCloud: status.isTerminal)
        }
    }

    /// Translate the resulting status into success/error/warning haptics.
    private func emitStatusFeedback(playerIsWhite: Bool) {
        switch status {
        case .checkmate(let winner):
            if isOnline {
                if winner == mySide { didWin.toggle() } else { didLose.toggle() }
            } else if !usesBot {
                didWin.toggle()
            } else if (winner == .white) == playerIsWhite {
                didWin.toggle()
            } else {
                didLose.toggle()
            }
        case .check:
            checkTick &+= 1
        default:
            break
        }
    }

    private func newGame() {
        withAnimation(.snappy(duration: 0.16)) {
            position = .initial; selected = nil; targets = []
            lastFrom = nil; lastTo = nil
        }
        status = .ongoing; thinking = false
        save(forceCloud: true)
    }

    private func snapshot() -> ChessSnapshot {
        ChessSnapshot(
            position: position,
            selected: selected,
            targets: targets,
            status: status,
            lastFrom: lastFrom,
            lastTo: lastTo
        )
    }

    private func restore(_ snapshot: ChessSnapshot) {
        position = snapshot.position
        selected = snapshot.selected
        targets = snapshot.targets
        status = snapshot.status
        lastFrom = snapshot.lastFrom
        lastTo = snapshot.lastTo
        thinking = false
    }

    private func save(forceCloud: Bool = false) {
        guard !isOnline else { return }
        persistence.save(snapshot: snapshot(), score: materialScore, forceCloud: forceCloud)
    }

    private var materialScore: Int {
        position.board.compactMap { $0 }.reduce(0) { total, piece in
            total + (piece.color == .white ? piece.type.value : -piece.type.value)
        }
    }
}

// MARK: - Study Table theme (game-local tokens)

/// Chrome palette for the "Study Table" — every tone is derived from the
/// selected `ChessBoardTheme` so the felt, plaques, and wood frame retint with
/// the board. Constants (ivory ink, brass) are the room's fixed fittings.
private struct ChessStudyTheme {
    let felt: Color        // table ground under the board
    let feltEdge: Color    // vignette toward the screen edges
    let rail: Color        // plaque / card panel fill
    let frameHi: Color     // wood board-frame gradient top
    let frameLo: Color     // wood board-frame gradient bottom
    let ivory = Color(red: 0.94, green: 0.92, blue: 0.85)
    let ivoryDim = Color(red: 0.94, green: 0.92, blue: 0.85).opacity(0.62)
    let brass = Color(red: 0.83, green: 0.68, blue: 0.38)

    init(_ board: ChessBoardTheme) {
        felt = Self.tone(board.darkSquare, scale: 0.40, lift: 0.030)
        feltEdge = Self.tone(board.darkSquare, scale: 0.26, lift: 0.015)
        rail = Self.tone(board.darkSquare, scale: 0.40, lift: 0.085)
        frameHi = Self.tone(board.boardEdge, scale: 1.0, lift: 0.10)
        frameLo = Self.tone(board.boardEdge, scale: 0.80, lift: 0.0)
    }

    /// Darken (scale) then lift a theme color so even near-black palettes
    /// (Midnight Neon) keep felt/rail separation.
    private static func tone(_ color: ChessThemeColor, scale: Double, lift: Double) -> Color {
        Color(
            .sRGB,
            red: min(1, color.r * scale + lift),
            green: min(1, color.g * scale + lift),
            blue: min(1, color.b * scale + lift),
            opacity: 1
        )
    }
}

/// Compact in-world chip button for table controls (New Game / Resign) —
/// never stretches edge-to-edge.
private struct StudyChipButtonStyle: ButtonStyle {
    var fill: Color
    var stroke: Color
    var ink: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .serif))
            .foregroundStyle(ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(stroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 3, y: 2)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
