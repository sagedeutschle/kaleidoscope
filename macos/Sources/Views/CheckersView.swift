// PRISM: RELEASE Agent-Mac 2026-07-04 — mirrored iOS v10/v11 "club Checkers board" chrome to
// macOS: board-style skins (Classic/Walnut/Tournament), captured-piece rail trays in the header,
// and wood/quiet chip button controls (replacing the generic capsule pills). Visual layer only;
// CheckersSession/CheckersGame model untouched, all existing functionality preserved. Build green.
import SwiftUI

// MARK: - Skins & Theme ("The Club Board")

private enum CheckersSkin: String, CaseIterable, Identifiable {
    case classic = "Classic Red & Black"
    case clubWalnut = "Club Walnut"
    case tournament = "Tournament Green"
    var id: String { rawValue }
}

/// Game-local material palette mirrored from the iOS v10/v11 `CheckersTheme`. The
/// classic red-and-black board ships by default; the walnut and green-tournament
/// skins are optional swaps via the board-style menu.
private struct CheckersTheme {
    var accent: Color
    var lightSquare: Color
    var darkSquare: Color
    var frame: Color
    var frameEdge: Color
    var darkBase: Color, darkRim: Color, darkGroove: Color
    var lightBase: Color, lightRim: Color, lightGroove: Color

    /// Classic American set: bright red squares with deep charcoal playing
    /// squares, glossy vermilion discs vs ebony discs. Charcoal (not pure
    /// black) so the ebony discs keep an edge; graphite grooves catch light.
    static let classic = CheckersTheme(
        accent: Color(red: 0.80, green: 0.18, blue: 0.14),
        lightSquare: Color(red: 0.72, green: 0.22, blue: 0.17),
        darkSquare: Color(red: 0.205, green: 0.185, blue: 0.185),
        frame: Color(red: 0.115, green: 0.10, blue: 0.10),
        frameEdge: Color(red: 0.05, green: 0.044, blue: 0.044),
        darkBase: Color(red: 0.135, green: 0.125, blue: 0.13),
        darkRim: Color(red: 0.035, green: 0.03, blue: 0.035),
        darkGroove: Color(red: 0.44, green: 0.43, blue: 0.44),
        lightBase: Color(red: 0.80, green: 0.16, blue: 0.13),
        lightRim: Color(red: 0.46, green: 0.075, blue: 0.06),
        lightGroove: Color(red: 0.96, green: 0.47, blue: 0.39)
    )

    static let clubWalnut = CheckersTheme(
        accent: Color(red: 0.70, green: 0.30, blue: 0.25),
        lightSquare: Color(red: 0.89, green: 0.83, blue: 0.70),
        darkSquare: Color(red: 0.33, green: 0.23, blue: 0.155),
        frame: Color(red: 0.29, green: 0.19, blue: 0.12),
        frameEdge: Color(red: 0.19, green: 0.125, blue: 0.08),
        darkBase: Color(red: 0.145, green: 0.115, blue: 0.10),
        darkRim: Color(red: 0.06, green: 0.05, blue: 0.045),
        darkGroove: Color(red: 0.38, green: 0.32, blue: 0.27),
        lightBase: Color(red: 0.91, green: 0.86, blue: 0.74),
        lightRim: Color(red: 0.66, green: 0.58, blue: 0.44),
        lightGroove: Color(red: 0.60, green: 0.52, blue: 0.38)
    )

    static let tournament = CheckersTheme(
        accent: Color(red: 0.72, green: 0.18, blue: 0.15),
        lightSquare: Color(red: 0.88, green: 0.85, blue: 0.74),
        darkSquare: Color(red: 0.16, green: 0.32, blue: 0.22),
        frame: Color(red: 0.14, green: 0.13, blue: 0.12),
        frameEdge: Color(red: 0.07, green: 0.065, blue: 0.06),
        darkBase: Color(red: 0.12, green: 0.115, blue: 0.125),
        darkRim: Color(red: 0.03, green: 0.03, blue: 0.035),
        darkGroove: Color(red: 0.37, green: 0.36, blue: 0.37),
        lightBase: Color(red: 0.62, green: 0.16, blue: 0.14),
        lightRim: Color(red: 0.38, green: 0.085, blue: 0.075),
        lightGroove: Color(red: 0.85, green: 0.46, blue: 0.39)
    )

    static func theme(for skin: CheckersSkin) -> CheckersTheme {
        switch skin {
        case .classic: return .classic
        case .clubWalnut: return .clubWalnut
        case .tournament: return .tournament
        }
    }
}

/// User-facing side names: `.dark` reads as "Black", `.light` reads as "Red"
/// (matches the iOS labels — not the model's internal "Dark"/"Light").
private extension CheckersPlayer {
    var displayName: String { self == .dark ? "Black" : "Red" }
}

private enum CheckersModal: Identifiable {
    case result(GameResult)
    case leaderboard

    var id: String {
        switch self {
        case .result(let result): return "result-\(result.id.uuidString)"
        case .leaderboard: return "leaderboard"
        }
    }
}

struct CheckersView: View {
    @ObservedObject private var session: CheckersSession
    @State private var selectedPoint: CheckersPoint?
    @State private var modal: CheckersModal?
    @State private var hasSubmittedTerminalResult = false
    @AppStorage("checkers.skin") private var skinRaw = CheckersSkin.classic.rawValue

    private var theme: CheckersTheme {
        CheckersTheme.theme(for: CheckersSkin(rawValue: skinRaw) ?? .classic)
    }
    private var accent: Color { theme.accent }
    private let leaderboardService = PrismetLeaderboardService.shared
    private let cellSide: CGFloat = 54

    init(session: CheckersSession = CheckersSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Checkers",
                       systemImage: "crown.fill",
                       accent: accent,
                       subtitle: statusText) {
                HStack(spacing: 14) {
                    capturedTray(label: CheckersPlayer.dark.displayName, victim: .light)
                    capturedTray(label: CheckersPlayer.light.displayName, victim: .dark)
                }
            }
            .frame(maxWidth: 640)

            board
            controls
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .onChange(of: session.game) { _, _ in
            submitTerminalResultIfNeeded()
        }
        .sheet(item: $modal) { modal in
            switch modal {
            case .result(let result):
                ResultSlipView(result: result,
                               accent: accent,
                               onPlayAgain: {
                                   self.modal = nil
                                   newGame()
                               },
                               onLeaderboard: {
                                   self.modal = .leaderboard
                               },
                               onDismiss: {
                                   self.modal = nil
                               })
            case .leaderboard:
                LocalLeaderboardPanel(service: leaderboardService,
                                      facetID: "checkers",
                                      mode: "standard",
                                      accent: accent)
            }
        }
    }

    // MARK: - Captured-piece trays (header)

    /// Score told in the game's own vocabulary: the discs each side has taken,
    /// stacked and overlapping like a rail on a club table. Mirrors the iOS
    /// `capturedTray`; uses only the existing `CheckersGame.count(for:)` API.
    private func capturedTray(label: String, victim: CheckersPlayer) -> some View {
        let captured = max(0, 12 - session.game.count(for: victim))
        return VStack(alignment: .trailing, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold)).tracking(0.7)
                .foregroundStyle(PrismetDesign.ink3)
            HStack(spacing: 5) {
                if captured == 0 {
                    Circle()
                        .strokeBorder(PrismetDesign.ink3.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                        .frame(width: 18, height: 18)
                } else {
                    HStack(spacing: -11) {
                        ForEach(0..<min(captured, 6), id: \.self) { _ in
                            CheckersDisc(player: victim, isKing: false, size: 18, theme: theme)
                        }
                    }
                    Text("\(captured)")
                        .font(PrismetDesign.rounded(15, .bold)).monospacedDigit()
                        .foregroundStyle(PrismetDesign.ink2)
                }
            }
            .frame(height: 20)
        }
        .frame(minWidth: 60, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) captured \(captured) pieces")
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: 0) {
            ForEach(0..<CheckersGame.size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<CheckersGame.size, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.black.opacity(0.30), lineWidth: 1)
        )
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(colors: [theme.frame, theme.frameEdge],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .inset(by: 1.5)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 8)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                newGame()
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(ClubChipStyle(theme: theme, kind: .wood))

            Button {
                session.undo()
                selectedPoint = nil
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(ClubChipStyle(theme: theme, kind: .quiet))
            .disabled(!session.canUndo || session.game.isGameOver)

            Menu {
                Button("Save") { session.saveNow() }
                Button("Load") {
                    session.reloadSavedState()
                    selectedPoint = nil
                }
            } label: {
                Label("State", systemImage: "externaldrive")
            }
            .buttonStyle(ClubChipStyle(theme: theme, kind: .quiet))

            Button {
                modal = .leaderboard
            } label: {
                Label("Scores", systemImage: "trophy")
            }
            .buttonStyle(ClubChipStyle(theme: theme, kind: .quiet))

            Spacer(minLength: 8)

            Menu {
                Picker("Board style", selection: $skinRaw) {
                    ForEach(CheckersSkin.allCases) { skin in
                        Text(skin.rawValue).tag(skin.rawValue)
                    }
                }
            } label: {
                Image(systemName: "paintbrush")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PrismetDesign.ink2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PrismetDesign.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(PrismetDesign.outline, lineWidth: 1)
                            )
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Board style")
        }
        .frame(maxWidth: 640)
    }

    private var statusText: String {
        if let winner = session.game.winner {
            return "\(winner.displayName) wins."
        }
        if session.game.activeJumpOrigin != nil {
            return "\(session.game.currentPlayer.displayName) must continue the jump."
        }
        return "\(session.game.currentPlayer.displayName) to move."
    }

    private func cell(row: Int, col: Int) -> some View {
        let point = CheckersPoint(row: row, col: col)
        let playable = CheckersGame.isPlayable(row: row, col: col)
        let piece = session.game.piece(at: point)
        let selected = selectedPoint == point
        let destination = selectedMoves.contains { $0.to == point }
        let selectable = piece?.player == session.game.currentPlayer && session.game.legalMoves().contains { $0.from == point }

        return Button {
            handleTap(point)
        } label: {
            ZStack {
                Rectangle()
                    .fill(playable ? theme.darkSquare : theme.lightSquare)

                if playable {
                    // Faint top shading so the playing squares read carved-in.
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [Color.black.opacity(0.16), .clear],
                                           startPoint: .top,
                                           endPoint: .center)
                        )
                }

                if selected {
                    Rectangle().fill(PrismetDesign.gold.opacity(0.26))
                    Rectangle()
                        .strokeBorder(PrismetDesign.gold.opacity(0.9), lineWidth: max(2, cellSide * 0.05))
                }

                if let piece {
                    CheckersDisc(player: piece.player,
                                 isKing: piece.kind == .king,
                                 size: cellSide * 0.78,
                                 theme: theme)
                    if selectable && !selected {
                        // Faint gold ring hints which discs can move (no iOS equivalent
                        // because iOS surfaces this on tap; kept for pointer play).
                        Circle()
                            .strokeBorder(PrismetDesign.gold.opacity(0.55),
                                          style: StrokeStyle(lineWidth: max(1.5, cellSide * 0.04), dash: [3, 3]))
                            .frame(width: cellSide * 0.82, height: cellSide * 0.82)
                    }
                } else if destination {
                    Circle()
                        .strokeBorder(PrismetDesign.gold.opacity(0.85), lineWidth: max(1.5, cellSide * 0.045))
                        .frame(width: cellSide * 0.46, height: cellSide * 0.46)
                }
            }
            .frame(width: cellSide, height: cellSide)
        }
        .buttonStyle(.plain)
        .disabled(!playable || session.game.isGameOver)
    }

    private var selectedMoves: [CheckersMove] {
        guard let selectedPoint else { return [] }
        return session.game.legalMoves().filter { $0.from == selectedPoint }
    }

    private func handleTap(_ point: CheckersPoint) {
        if let move = selectedMoves.first(where: { $0.to == point }) {
            withAnimation(.easeOut(duration: 0.16)) {
                _ = session.applyMove(move)
            }
            if session.game.activeJumpOrigin != nil {
                selectedPoint = session.game.activeJumpOrigin
            } else {
                selectedPoint = nil
            }
            return
        }

        if session.game.legalMoves().contains(where: { $0.from == point }) {
            selectedPoint = point
        } else {
            selectedPoint = nil
        }
    }

    private func newGame() {
        withAnimation(.easeOut(duration: 0.16)) {
            session.newGame()
        }
        selectedPoint = nil
        hasSubmittedTerminalResult = false
    }

    private func submitTerminalResultIfNeeded() {
        guard !hasSubmittedTerminalResult,
              let result = GameResultExtractor.result(for: session.game) else { return }
        hasSubmittedTerminalResult = true
        modal = .result(result)

        Task {
            try? await leaderboardService.submit(result)
        }
    }
}

// MARK: - The drafts piece (mirrored from iOS v10/v11)

/// A lacquered club-hall checker: stacked disc thickness, an outer rim,
/// concentric grooves with radial ticks, a sheen highlight, and an embossed
/// crown stamp for kings. `.dark` renders ebony (Black), `.light` renders
/// glossy vermilion (Red). Reused at cell size and 18pt captured-tray size.
private struct CheckersDisc: View {
    let player: CheckersPlayer
    let isKing: Bool
    let size: CGFloat
    let theme: CheckersTheme

    var body: some View {
        let base = player == .dark ? theme.darkBase : theme.lightBase
        let rim = player == .dark ? theme.darkRim : theme.lightRim
        let groove = player == .dark ? theme.darkGroove : theme.lightGroove

        ZStack {
            // Disc thickness peeking out below the face.
            Circle()
                .fill(rim)
                .offset(y: size * 0.045)

            // Lacquered face.
            Circle()
                .fill(base)
                .overlay(
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(player == .dark ? 0.14 : 0.28),
                                .clear,
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(rim, lineWidth: max(1, size * 0.05))
                )

            // Radial groove ticks between rim and inner ring.
            if size >= 30 {
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(groove)
                        .frame(width: max(1, size * 0.02), height: size * 0.085)
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }

            // Concentric grooves.
            Circle()
                .strokeBorder(groove, lineWidth: max(0.8, size * 0.028))
                .padding(size * 0.15)
            if size >= 44 {
                Circle()
                    .strokeBorder(groove.opacity(0.55), lineWidth: max(0.6, size * 0.02))
                    .padding(size * 0.24)
            }

            // Lacquer sheen.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(player == .dark ? 0.22 : 0.38), .clear],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 1,
                        endRadius: size * 0.55
                    )
                )

            if isKing {
                if size >= 26 {
                    CheckersCrownStamp()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.96, green: 0.82, blue: 0.40), PrismetDesign.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            CheckersCrownStamp().stroke(Color.black.opacity(0.30), lineWidth: max(0.5, size * 0.012))
                        )
                        .frame(width: size * 0.40, height: size * 0.28)
                        .shadow(color: Color.black.opacity(0.35), radius: max(0.5, size * 0.012), y: max(0.5, size * 0.015))
                } else {
                    Circle()
                        .fill(PrismetDesign.gold)
                        .frame(width: size * 0.26, height: size * 0.26)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.32), radius: size * 0.05, y: size * 0.035)
        .accessibilityHidden(true)
    }
}

/// A simple three-point crown, stamped into king pieces.
private struct CheckersCrownStamp: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.60))
        p.addLine(to: CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.60))
        p.addLine(to: CGPoint(x: w, y: h * 0.35))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Chips

/// Compact in-world buttons mirrored from iOS's `ClubChipStyle`: wood for the
/// primary action, quiet panel for secondary controls.
private struct ClubChipStyle: ButtonStyle {
    enum Kind {
        case wood, quiet
    }

    var theme: CheckersTheme
    var kind: Kind = .quiet
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(border, lineWidth: 1)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .wood: return Color(red: 0.97, green: 0.93, blue: 0.85)
        case .quiet: return PrismetDesign.ink
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .wood:
            return AnyShapeStyle(
                LinearGradient(colors: [theme.frame, theme.frameEdge], startPoint: .top, endPoint: .bottom)
            )
        case .quiet:
            return AnyShapeStyle(PrismetDesign.panel)
        }
    }

    private var border: Color {
        switch kind {
        case .wood: return Color.white.opacity(0.12)
        case .quiet: return PrismetDesign.outline
        }
    }
}
