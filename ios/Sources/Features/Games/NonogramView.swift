import SwiftUI

/// iOS Nonogram (Picross) — tap a cell to cycle empty → filled → crossed.
/// Uses the ported pure-Swift `NonogramGame` model, driven by a bundled bank of
/// puzzles (`NonogramLevelBank`). The player picks a level or advances to the next
/// one on solve; the current level and the set of completed levels persist locally.
struct NonogramView: View {
    private let accountID: UUID?
    @StateObject private var persistence = PersistedGameSession<NonogramSnapshot>(gameID: .nonogram)

    // Persisted, owned by this view. `levelIndex` is the puzzle the player is on;
    // `completedRaw` is a comma-separated list of completed level indices (AppStorage
    // can't store a Set directly, so we (de)serialize a compact string).
    @AppStorage("nonogram.levelIndex") private var levelIndex = 0
    @AppStorage("nonogram.completed") private var completedRaw = ""

    @State private var game = NonogramLevelBank.level(at: 0).makeGame()
    @State private var moveTick = 0
    @State private var justSolved = false
    private let accent = Color(red: 0.55, green: 0.35, blue: 0.55)

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    private var levels: [NonogramLevel] { NonogramLevelBank.levels }
    private var currentLevel: NonogramLevel { NonogramLevelBank.level(at: levelIndex) }

    private var completedSet: Set<Int> {
        Set(completedRaw.split(separator: ",").compactMap { Int($0) })
    }
    private var completedCount: Int { completedSet.intersection(0..<levels.count).count }

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Nonogram", systemImage: "square.grid.3x3.fill", accent: accent,
                       subtitle: game.isSolved ? "Solved \(currentLevel.name)!" : "Fill the picture from the clues") {
                StatBadge(label: "Solved", value: "\(completedCount)/\(levels.count)", accent: accent)
                StatBadge(label: "Grid", value: "\(game.size)×\(game.size)", accent: accent)
            }
            levelBar
            board
            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Nonogram")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: game.isSolved)
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
        }
        .onDisappear { save(forceCloud: true) }
    }

    // Level picker + previous/next stepper, plus a "Next Level" nudge on solve.
    private var levelBar: some View {
        HStack(spacing: 10) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(levelIndex <= 0)

            Menu {
                ForEach(Array(levels.enumerated()), id: \.offset) { idx, level in
                    Button {
                        load(index: idx)
                    } label: {
                        Label("\(idx + 1). \(level.name) · \(level.size)×\(level.size)",
                              systemImage: completedSet.contains(idx) ? "checkmark.circle.fill" : "circle")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Level \(levelIndex + 1) · \(currentLevel.name)")
                        .font(Kaleido.rounded(15))
                        .foregroundStyle(Kaleido.ink)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Kaleido.ink3)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(Kaleido.panelHi).overlay(Capsule().strokeBorder(Kaleido.outline, lineWidth: 1)))
            }
            .frame(maxWidth: .infinity)

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(levelIndex >= levels.count - 1)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if game.isSolved && levelIndex < levels.count - 1 {
                Button { step(1) } label: { Label("Next Level", systemImage: "arrow.right.circle.fill") }
                    .buttonStyle(AccentButtonStyle(accent: accent))
            } else {
                Button { newGame() } label: { Label("New Game", systemImage: "shuffle") }
                    .buttonStyle(AccentButtonStyle(accent: accent))
            }
            Button {
                withAnimation(.snappy(duration: 0.15)) { game.reset() }
                save(forceCloud: true)
            } label: {
                Label("Reset", systemImage: "eraser")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private var board: some View {
        GeometryReader { geo in
            let n = game.size
            let maxRowClues = max(1, game.rowClues.map(\.count).max() ?? 1)
            let maxColClues = max(1, game.columnClues.map(\.count).max() ?? 1)
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(n + maxRowClues)
            let cluePad = cell * CGFloat(maxRowClues)
            let clueTop = cell * CGFloat(maxColClues)

            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Color.clear.frame(width: cluePad, height: clueTop)
                    ForEach(0..<n, id: \.self) { c in
                        colCluesView(c, width: cell, height: clueTop)
                    }
                }
                ForEach(0..<n, id: \.self) { r in
                    HStack(spacing: 2) {
                        rowCluesView(r, width: cluePad, height: cell)
                        ForEach(0..<n, id: \.self) { c in
                            cellView(r, c, size: cell)
                        }
                    }
                }
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .kaleidoCard()
    }

    private func cellView(_ r: Int, _ c: Int, size: CGFloat) -> some View {
        let m = game.mark(row: r, col: c)
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(m == .filled ? accent : Kaleido.panel)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Kaleido.outline, lineWidth: 1))
            .overlay {
                if m == .crossed {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(Kaleido.ink3)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.14)) { game.cycle(row: r, col: c) }
                moveTick += 1
                handleSolveIfNeeded()
                save(forceCloud: game.isSolved)
            }
    }

    private func rowCluesView(_ r: Int, width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            ForEach(Array(game.rowClues[r].enumerated()), id: \.offset) { _, clue in
                Text("\(clue)")
                    .font(Kaleido.rounded(min(height * 0.5, 15)))
                    .foregroundStyle(Kaleido.ink2)
            }
        }
        .frame(width: width, height: height)
    }

    private func colCluesView(_ c: Int, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            ForEach(Array(game.columnClues[c].enumerated()), id: \.offset) { _, clue in
                Text("\(clue)")
                    .font(Kaleido.rounded(min(width * 0.5, 15)))
                    .foregroundStyle(Kaleido.ink2)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Level flow

    /// Record a solve (mark the level completed) exactly once per fresh solve.
    private func handleSolveIfNeeded() {
        if game.isSolved {
            if !justSolved {
                justSolved = true
                markCompleted(levelIndex)
            }
        } else {
            justSolved = false
        }
    }

    private func step(_ delta: Int) {
        let next = min(max(levelIndex + delta, 0), levels.count - 1)
        guard next != levelIndex else { return }
        load(index: next)
    }

    private func load(index: Int) {
        levelIndex = min(max(index, 0), levels.count - 1)
        justSolved = false
        withAnimation(.snappy(duration: 0.15)) { game = NonogramLevelBank.level(at: levelIndex).makeGame() }
        save(forceCloud: true)
    }

    private func markCompleted(_ index: Int) {
        var set = completedSet
        guard !set.contains(index) else { return }
        set.insert(index)
        completedRaw = set.sorted().map(String.init).joined(separator: ",")
    }

    private func newGame() {
        justSolved = false
        withAnimation(.snappy(duration: 0.15)) { game = currentLevel.makeGame() }
        save(forceCloud: true)
    }

    // MARK: - Persistence

    private func snapshot() -> NonogramSnapshot {
        NonogramSnapshot(game: game)
    }

    private func restore(_ snapshot: NonogramSnapshot) {
        // Prefer the restored board when it matches the puzzle the player is on;
        // otherwise fall back to a clean copy of the current level so a stale save
        // from the old single-puzzle build can't strand the player on a mismatch.
        if snapshot.game.solution == currentLevel.solution {
            game = snapshot.game
        } else {
            game = currentLevel.makeGame()
        }
        justSolved = game.isSolved
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: game.isSolved ? 1 : 0, forceCloud: forceCloud)
    }
}
