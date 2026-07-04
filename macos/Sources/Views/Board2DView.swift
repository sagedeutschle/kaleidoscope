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
