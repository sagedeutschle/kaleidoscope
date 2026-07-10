import SwiftUI

struct RubiksCubeView: View {
    private let accountID: UUID?
    @StateObject private var persistence = PersistedGameSession<RubiksSnapshot>(gameID: .rubiks)
    @State private var game = RubiksCube()
    @State private var rng = SeededGenerator(seed: 11)
    @State private var moveCount = 0
    @State private var moveHistory: [RubiksMove] = []

    // Haptic triggers (iOS 17 .sensoryFeedback).
    @State private var moveTick = 0          // flips on every turn -> light impact
    @State private var didSolve = false      // flips true when isSolved becomes true -> success

    // "How to play" help sheet.
    @State private var showHelp = false
    @State private var showFullscreenCube = false

    private let accent = Color(red: 0.46, green: 0.34, blue: 0.62)

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GameHeader(
                    title: "Rubik's",
                    systemImage: "cube.transparent.fill",
                    accent: accent,
                    subtitle: game.isSolved ? "Solved!" : "Turn the faces to solve"
                ) {
                    HStack(spacing: 12) {
                        StatBadge(label: "Moves", value: "\(moveCount)", accent: accent)
                        fullscreenButton
                        helpButton
                    }
                }

                cube3D

                dragHint

                movePad

                actionBar
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Rubik's Cube")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelp) {
            RubiksHelpSheet(accent: accent)
        }
        .fullScreenCover(isPresented: $showFullscreenCube) {
            fullscreenCube
        }
        // Light impact on every turn; success when the cube becomes solved.
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: didSolve) { _, now in now }
        .onChange(of: game.isSolved) { _, solved in
            if solved { LeaderboardCoordinator.shared.submit(.rubiks, score: moveCount) }
        }
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
        }
        .onDisappear { save(forceCloud: true) }
    }

    // MARK: - 3D corner cube

    private var cube3D: some View {
        RubiksSceneKitCubeView(cube: game, onDragTurn: { perform($0) })
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(PrismetDesign.outline, lineWidth: 1)
            )
            .prismetCard()
    }

    /// The cube now works like the leading cube apps: swipe a sticker to turn
    /// its layer; drag empty space to orbit. Buttons remain for precision.
    private var dragHint: some View {
        Label("Swipe a sticker to turn its layer. Drag the background to spin your view.",
              systemImage: "hand.draw")
            .font(.footnote)
            .foregroundStyle(PrismetDesign.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var helpButton: some View {
        Button { showHelp = true } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityLabel("How to play")
        }
        .buttonStyle(.plain)
    }

    private var fullscreenButton: some View {
        Button { showFullscreenCube = true } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityLabel("Fullscreen cube")
        }
        .buttonStyle(.plain)
    }

    private var fullscreenCube: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.060, green: 0.055, blue: 0.075),
                    Color(red: 0.150, green: 0.105, blue: 0.195)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RubiksSceneKitCubeView(cube: game, onDragTurn: { perform($0) })
                .padding(.top, 70)
                .padding(.bottom, 86)
                .padding(.horizontal, 10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        showFullscreenCube = false
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    .buttonStyle(GlassButtonStyle())

                    Spacer(minLength: 8)

                    StatBadge(label: "Moves", value: "\(moveCount)", accent: accent)

                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .accessibilityLabel("How to play")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                HStack(spacing: 10) {
                    Button { undo() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                            .frame(width: 46, height: 44)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(moveHistory.isEmpty)
                    .accessibilityLabel("Undo")

                    Button { scramble() } label: {
                        Label("Scramble", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(accent: accent))

                    Button { reset() } label: {
                        Label("Reset", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .frame(width: 46, height: 44)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .accessibilityLabel("Reset")
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button { undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(moveHistory.isEmpty)

            Button { scramble() } label: {
                Label("Scramble", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

            Button { reset() } label: {
                Label("Reset", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
        }
    }

    // MARK: - Face-turn move pad

    private var movePad: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Turn a face")
                    .font(PrismetDesign.rounded(15, .bold))
                    .foregroundStyle(PrismetDesign.ink)
                Spacer()
                Text("' = counter-clockwise")
                    .font(.caption2)
                    .foregroundStyle(PrismetDesign.ink3)
            }

            // Column captions so the two buttons in each row read clearly.
            HStack(spacing: 8) {
                Text("FACE")
                    .frame(width: 96, alignment: .leading)
                Text("CW")
                    .frame(maxWidth: .infinity)
                Text("CCW")
                    .frame(maxWidth: .infinity)
            }
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(PrismetDesign.ink3)

            ForEach(RubiksMove.mobileControlRows) { row in
                HStack(spacing: 8) {
                    faceTag(row.face)
                    moveButton(row.turn, label: row.turn.rawValue)
                    moveButton(row.inverse, label: row.inverse.rawValue)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PrismetDesign.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PrismetDesign.outline, lineWidth: 1)
                )
        )
    }

    /// The face identity for a row: big letter plus its plain name so U/D/L/R/F/B
    /// are self-explanatory without opening the help sheet.
    private func faceTag(_ face: CubeFace) -> some View {
        HStack(spacing: 8) {
            Text(face.rawValue)
                .font(PrismetDesign.rounded(18, .bold))
                .foregroundStyle(PrismetDesign.ink)
                .frame(width: 30, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PrismetDesign.panelHi)
                )
            Text(face.plainName)
                .font(.caption)
                .foregroundStyle(PrismetDesign.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 58, alignment: .leading)
        }
        .frame(width: 96, alignment: .leading)
    }

    private func moveButton(_ move: RubiksMove, label: String) -> some View {
        Button {
            perform(move)
        } label: {
            Text(label)
                .font(PrismetDesign.rounded(20, .semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(GlassButtonStyle())
        .accessibilityLabel(move.spokenDescription)
    }

    // MARK: - Actions

    /// Apply a single turn with a short snappy animation so the face glides,
    /// fire a light haptic, and raise the success haptic if it just solved.
    private func perform(_ move: RubiksMove) {
        let wasSolved = game.isSolved
        withAnimation(.snappy(duration: 0.18)) {
            game.apply(move)
            moveCount += 1
        }
        moveHistory.append(move)
        moveTick &+= 1
        if !wasSolved && game.isSolved {
            didSolve.toggle()
        }
        save(forceCloud: game.isSolved)
    }

    private func undo() {
        guard let last = moveHistory.popLast() else { return }
        withAnimation(.snappy(duration: 0.18)) {
            game.apply(last.inverse)
            moveCount = max(0, moveCount - 1)
        }
        moveTick &+= 1
        save(forceCloud: true)
    }

    private func scramble() {
        withAnimation(.snappy(duration: 0.2)) {
            let seed = UInt64.random(in: 1...UInt64.max)
            rng = SeededGenerator(seed: seed)
            _ = game.scramble(seed: seed, moveCount: 25)
            moveCount = 0
            moveHistory.removeAll()
        }
        moveTick &+= 1
        save(forceCloud: true)
    }

    private func reset() {
        withAnimation(.snappy(duration: 0.2)) {
            game = RubiksCube()
            moveCount = 0
            moveHistory.removeAll()
        }
        moveTick &+= 1
        save(forceCloud: true)
    }

    private func snapshot() -> RubiksSnapshot {
        RubiksSnapshot(game: game, rng: rng, moveCount: moveCount, tiltX: 0, tiltY: 0)
    }

    private func restore(_ snapshot: RubiksSnapshot) {
        game = snapshot.game
        rng = snapshot.rng
        moveCount = snapshot.moveCount
        moveHistory.removeAll()
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: moveCount, forceCloud: forceCloud)
    }

}

// MARK: - How to play

/// A short, scrollable legend explaining the face letters, the ' convention,
/// and that dragging orbits the view (distinct from turning a face).
private struct RubiksHelpSheet: View {
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(
                        title: "The six faces",
                        systemImage: "square.grid.3x3.fill"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(CubeFace.allCases, id: \.self) { face in
                                HStack(spacing: 12) {
                                    Text(face.rawValue)
                                        .font(PrismetDesign.rounded(17, .bold))
                                        .foregroundStyle(PrismetDesign.ink)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(PrismetDesign.panelHi)
                                        )
                                    Text(face.plainName)
                                        .font(.subheadline)
                                        .foregroundStyle(PrismetDesign.ink2)
                                    Spacer()
                                }
                            }
                        }
                    }

                    section(
                        title: "Clockwise vs counter-clockwise",
                        systemImage: "arrow.clockwise"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            bullet("A plain letter (e.g. R) turns that face clockwise, looking straight at it.")
                            bullet("A letter with an apostrophe (e.g. R') turns it counter-clockwise.")
                            bullet("In the pad, the CW column is the plain turn, CCW is the ' turn.")
                        }
                    }

                    section(
                        title: "Turning and looking around",
                        systemImage: "hand.draw"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            bullet("Swipe ON a sticker to turn that layer in the swipe direction — like flicking a real cube.")
                            bullet("Drag the empty background to orbit your view and see the other faces.")
                            bullet("The labelled buttons below turn faces too, if you prefer precision.")
                        }
                    }

                    section(
                        title: "Buttons",
                        systemImage: "slider.horizontal.3"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            bullet("Scramble mixes the cube up so you can start solving.")
                            bullet("Undo reverses your last face turn.")
                            bullet("Reset returns the cube to solved.")
                        }
                    }
                }
                .padding(20)
            }
            .facetBackground(accent)
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(PrismetDesign.rounded(16, .bold))
                .foregroundStyle(accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PrismetDesign.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PrismetDesign.outline, lineWidth: 1)
                )
        )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PrismetDesign.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
