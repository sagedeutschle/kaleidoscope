import SwiftUI

/// A flat, 2D chess board rendered from White's perspective: rank 1 at the
/// bottom, rank 8 at the top, file a on the left, file h on the right.
///
/// Pure SwiftUI; every model type referenced here lives in the same app target.
/// Tapping any square forwards to `GameState.tap(_:)`, which arbitrates whether
/// the tap selects, moves, captures, or is ignored.
struct Board2DView: View {
    @ObservedObject var game: GameState
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 8
            let corner = side * 0.018

            // Read derived state once per render instead of per-cell. The
            // legal/check accessors are computed, so this avoids 64x recompute.
            let position = game.position
            let selected = game.selectedSquare
            let legal = game.legalDestinations
            let lastMove = game.lastMove
            let checkedKing = game.checkedKingSquare
            // En passant lands on an EMPTY square, so the plain "piece != nil"
            // capture test misses it. A pawn's only legal move to the en-passant
            // square is the capture itself, so gating on a selected pawn is exact
            // (no false ring on another piece quietly moving onto that square).
            let enPassantSquare = position.enPassant
            let selectedIsPawn = selected.flatMap { position.piece(at: $0)?.type } == .pawn

            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { displayRow in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { displayCol in
                            // Top display row shows rank 7, bottom shows rank 0.
                            let rank = 7 - displayRow
                            let file = displayCol
                            let sq = Square(file: file, rank: rank)

                            BoardCell(
                                file: file,
                                rank: rank,
                                cell: cell,
                                piece: position.piece(at: sq),
                                isDark: (file + rank) % 2 == 0,
                                isSelected: selected == sq,
                                isLastMove: lastMove?.from == sq || lastMove?.to == sq,
                                isCheck: checkedKing == sq,
                                isLegalTarget: legal.contains(sq),
                                isEnPassantCapture: selectedIsPawn && enPassantSquare == sq,
                                showFileLabel: displayRow == 7,
                                showRankLabel: displayCol == 0,
                                theme: theme,
                                onTap: { game.tap(sq) }
                            )
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(theme.boardEdge.color, lineWidth: max(1.5, side * 0.005))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeInOut(duration: 0.18), value: position)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - A single square

private struct BoardCell: View {
    let file: Int
    let rank: Int
    let cell: CGFloat
    let piece: Piece?
    let isDark: Bool
    let isSelected: Bool
    let isLastMove: Bool
    let isCheck: Bool
    let isLegalTarget: Bool
    let isEnPassantCapture: Bool
    let showFileLabel: Bool
    let showRankLabel: Bool
    let theme: Theme
    let onTap: () -> Void

    private static let fileLetters = ["a", "b", "c", "d", "e", "f", "g", "h"]

    private var baseColor: Color { isDark ? theme.darkSquare.color : theme.lightSquare.color }
    // Tint coordinate labels with the *opposite* square color for contrast.
    private var labelColor: Color { isDark ? theme.lightSquare.color : theme.darkSquare.color }

    var body: some View {
        ZStack {
            Rectangle().fill(baseColor)

            // Highlight fills, layered under the piece.
            if isLastMove { Rectangle().fill(theme.lastMove.color) }
            if isSelected { Rectangle().fill(theme.selection.color) }
            if isCheck { Rectangle().fill(theme.check.color) }

            // Coordinate labels along the bottom / left edges.
            if showRankLabel || showFileLabel {
                coordinateLabels
            }

            // The piece, rendered from the bundled cburnett vector art.
            if let piece {
                PieceGlyph(piece: piece, size: cell * 0.84, theme: theme)
            }

            // Legal-move marker on top, so capture rings frame the piece.
            if isLegalTarget {
                LegalMoveMarker(isCapture: piece != nil || isEnPassantCapture, cell: cell, color: theme.legalDot.color)
            }
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var coordinateLabels: some View {
        ZStack {
            if showRankLabel {
                Text("\(rank + 1)")
                    .font(.system(size: cell * 0.17, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .padding(cell * 0.05)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if showFileLabel {
                Text(Self.fileLetters[file])
                    .font(.system(size: cell * 0.17, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .padding(cell * 0.05)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Piece rendered from cburnett vector art

/// Renders a piece using the bundled cburnett SVG-derived vector PDF, named by
/// color + type letter, e.g. white knight = "wN", black king = "bK".
///
/// A contrasting contour is drawn behind the art so pieces never melt into the
/// square they sit on — the near-white pieces in particular were hard to read on
/// the light (chess.com cream) squares. The outline is a set of offset template
/// silhouettes: dark behind white pieces, light behind black pieces.
private struct PieceGlyph: View {
    let piece: Piece
    let size: CGFloat
    let theme: Theme

    private var assetName: String {
        (piece.color == .white ? "w" : "b") + piece.type.letter
    }

    private var isWhite: Bool { piece.color == .white }
    private var outlineColor: Color {
        isWhite ? theme.pieceOutline.color : Color(white: 0.97)
    }

    /// 8-way offsets (N, S, E, W + diagonals) give an even ring.
    private static let offsets: [(CGFloat, CGFloat)] =
        [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]

    var body: some View {
        let w = size * 0.03   // contour thickness
        ZStack {
            ForEach(Array(Self.offsets.enumerated()), id: \.offset) { _, o in
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundStyle(outlineColor)
                    .offset(x: o.0 * w, y: o.1 * w)
            }
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
        .shadow(color: .black.opacity(0.28), radius: size * 0.02, x: 0, y: size * 0.02)
        .allowsHitTesting(false)
    }
}

// MARK: - Legal-move marker (dot for a quiet move, ring for a capture)

private struct LegalMoveMarker: View {
    let isCapture: Bool
    let cell: CGFloat
    let color: Color

    var body: some View {
        Group {
            if isCapture {
                Circle()
                    .strokeBorder(color, lineWidth: cell * 0.08)
                    .frame(width: cell * 0.9, height: cell * 0.9)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: cell * 0.28, height: cell * 0.28)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Study Table chrome (mirrored from iOS v10 ChessStudyTheme)

// PRISM: RELEASE Agent-Mac 2026-07-03 — Chess "study table" felt ground + wood board frame (visual chrome only; renderers/model untouched). Build green.

/// Study-table tones derived from the active board `Theme`, exactly like the iOS
/// `ChessStudyTheme`: felt is the dark square darkened + lifted; the wood frame is
/// the board edge lifted. Retints automatically when the board theme changes.
extension Theme {
    private func studyTone(_ c: ThemeColor, scale: Double, lift: Double) -> Color {
        Color(.sRGB,
              red: min(1, c.r * scale + lift),
              green: min(1, c.g * scale + lift),
              blue: min(1, c.b * scale + lift),
              opacity: 1)
    }

    /// Table ground under the board.
    var studyFelt: Color { studyTone(darkSquare, scale: 0.40, lift: 0.030) }
    /// Vignette toward the screen edges.
    var studyFeltEdge: Color { studyTone(darkSquare, scale: 0.26, lift: 0.015) }
    /// Wood board-frame gradient top.
    var studyFrameHi: Color { studyTone(boardEdge, scale: 1.0, lift: 0.10) }
    /// Wood board-frame gradient bottom.
    var studyFrameLo: Color { studyTone(boardEdge, scale: 0.80, lift: 0.0) }

    /// Player-plaque panel fill (mirrors iOS `ChessStudyTheme.rail`).
    var studyRail: Color { studyTone(darkSquare, scale: 0.40, lift: 0.085) }
    /// Ivory engraving ink — a fixed "room fitting", not theme-derived.
    var studyIvory: Color { Color(red: 0.94, green: 0.92, blue: 0.85) }
    /// Dimmed ivory for secondary plaque text.
    var studyIvoryDim: Color { Color(red: 0.94, green: 0.92, blue: 0.85).opacity(0.62) }
    /// Brass fitting — turn dot, active-plaque stroke, material advantage.
    var studyBrass: Color { Color(red: 0.83, green: 0.68, blue: 0.38) }
}

/// The felt table ground: a soft radial pool of felt fading to a darker edge,
/// mirroring the iOS study table.
struct ChessStudyGround: View {
    let theme: Theme
    var body: some View {
        ZStack {
            theme.studyFeltEdge
            RadialGradient(colors: [theme.studyFelt, theme.studyFeltEdge],
                           center: UnitPoint(x: 0.5, y: 0.40),
                           startRadius: 60, endRadius: 640)
        }
    }
}

/// Wraps the flat board in a turned-wood frame that sits on the felt table.
struct ChessStudyFrame<Content: View>: View {
    let theme: Theme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [theme.studyFrameHi, theme.studyFrameLo],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .inset(by: 1.5)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.40), radius: 18, y: 10)
    }
}

// MARK: - Engraved player plaque (mirrored from iOS v10/v11 ChessView.plaque)

/// An engraved player plaque — the signature of the iOS "study table". Renders
/// the seat's king, name, captured-piece tray, material advantage, a turn
/// indicator, and the seat's live state, all read from the shared `GameState`
/// so both seats stay in lockstep with the board.
///
/// Designed to sit ON the felt above/below the wood-framed board (i.e. OUTSIDE
/// `ChessStudyFrame`), exactly like iOS. The composing view (ContentView's
/// `boardArea`) stacks a top plaque, the framed board, and a bottom plaque.
struct ChessPlaque: View {
    @ObservedObject var game: GameState
    let theme: Theme
    let side: PieceColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var position: Position { game.position }
    private var status: GameStatus { game.status }

    /// This seat is to move (and the game is live).
    private var active: Bool { position.sideToMove == side && !status.isTerminal }
    /// The engine occupies the side opposite the human in a vs-computer game.
    private var botPlaysThisSide: Bool { game.vsComputer && side == game.humanColor.opposite }
    private var isThinkingHere: Bool { game.isThinking && botPlaysThisSide }
    /// Drives "Your move" vs "To move" phrasing (local two-player: both shared).
    private var isUserSide: Bool { game.vsComputer ? side == game.humanColor : false }

    var body: some View {
        HStack(spacing: 12) {
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
                Text(plaqueName)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.studyIvory)
                    .lineLimit(1)
                capturedRow
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if active { turnDot }
                    Text(side == .white ? "WHITE" : "BLACK")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(theme.studyIvoryDim)
                }
                let state = stateText
                if !state.isEmpty {
                    Text(state)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stateColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(theme.studyRail)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            active ? theme.studyBrass.opacity(0.55) : Color.white.opacity(0.08),
                            lineWidth: active ? 1.5 : 1
                        )
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Captured-piece tray + material advantage, using the same wK..bP art as
    /// the board at mini size. Fixed height so an empty tray doesn't jiggle.
    private var capturedRow: some View {
        let captured = capturedPieces
        let adv = advantage
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
                    .foregroundStyle(theme.studyBrass)
            }
        }
        .frame(height: 16, alignment: .leading)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var turnDot: some View {
        let dot = Circle()
            .fill(theme.studyBrass)
            .frame(width: 7, height: 7)
            .shadow(color: theme.studyBrass.opacity(0.8), radius: 3)
        if isThinkingHere && !reduceMotion {
            dot.phaseAnimator([1.0, 0.3]) { view, phase in
                view.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
        } else {
            dot
        }
    }

    private var plaqueName: String {
        if game.vsComputer { return side == game.humanColor ? "You" : "Computer" }
        return side == .white ? "White" : "Black"
    }

    private var stateText: String {
        if case .checkmate(let winner) = status { return winner == side ? "Winner" : "" }
        if status.isTerminal { return "Draw" }
        if case .check(let checked) = status, checked == side { return "Check!" }
        if isThinkingHere { return "Thinking…" }
        if position.sideToMove == side { return isUserSide ? "Your move" : "To move" }
        return ""
    }

    private var stateColor: Color {
        if case .checkmate(let winner) = status, winner == side { return theme.studyBrass }
        if case .check(let checked) = status, checked == side {
            return Color(red: 0.95, green: 0.47, blue: 0.40)
        }
        if isThinkingHere { return theme.studyIvoryDim }
        if position.sideToMove == side, !status.isTerminal { return theme.studyBrass }
        return theme.studyIvoryDim
    }

    // MARK: Captured / material (mirrors iOS)

    private static let fullSideCounts: [PieceType: Int] = [
        .pawn: 8, .knight: 2, .bishop: 2, .rook: 2, .queen: 1
    ]

    /// Opponent pieces missing from the board, queen-first. Promotion overshoot
    /// is clamped so the tray never goes negative.
    private var capturedPieces: [PieceType] {
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

    private var materialScore: Int {
        position.board.compactMap { $0 }.reduce(0) { total, piece in
            total + (piece.color == .white ? piece.type.value : -piece.type.value)
        }
    }

    /// Material advantage in pawns for this side (0 when behind or level).
    private var advantage: Int {
        let pawns = materialScore / 100
        return side == .white ? max(0, pawns) : max(0, -pawns)
    }

    private var accessibilityText: String {
        var parts = ["\(plaqueName), \(side == .white ? "White" : "Black")"]
        let captured = capturedPieces
        if !captured.isEmpty {
            parts.append("captured \(captured.count) piece\(captured.count == 1 ? "" : "s")")
        }
        if advantage > 0 { parts.append("up \(advantage) point\(advantage == 1 ? "" : "s") of material") }
        let state = stateText
        if !state.isEmpty { parts.append(state) }
        return parts.joined(separator: ", ")
    }
}

#Preview("Study Table + plaques") {
    let game = GameState()
    return ChessStudyGround(theme: .green)
        .overlay(
            VStack(spacing: 12) {
                ChessPlaque(game: game, theme: .green, side: .black)
                ChessStudyFrame(theme: .green) {
                    Board2DView(game: game, theme: .green)
                }
                ChessPlaque(game: game, theme: .green, side: .white)
            }
            .padding(24)
        )
        .frame(width: 520, height: 660)
}
