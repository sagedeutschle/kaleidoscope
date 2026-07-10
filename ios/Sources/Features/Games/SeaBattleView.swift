// PRISM: RELEASE Agent-Design(seabattle) 2026-07-03 - v10 design pass
import SwiftUI
import Foundation

// MARK: - Sea Battle theme (game-local tokens; do not move to PrismetDesign)

private enum SeaTheme {
    // Sunlit tropical water, not a midnight navy — the point is "playful", not "sad".
    static let deep = Color(red: 0.075, green: 0.285, blue: 0.455)
    static let deep2 = Color(red: 0.043, green: 0.180, blue: 0.330)
    static let water = Color(red: 0.160, green: 0.545, blue: 0.800)
    static let waterAlt = Color(red: 0.130, green: 0.495, blue: 0.755)
    static let gridLine = Color.white.opacity(0.18)
    static let hullHi = Color(red: 0.760, green: 0.800, blue: 0.835)
    static let hull = Color(red: 0.560, green: 0.605, blue: 0.650)
    static let hullShadow = Color(red: 0.300, green: 0.340, blue: 0.385)
    static let hullDeck = Color(red: 0.820, green: 0.850, blue: 0.875)
    static let hullSunkHi = Color(red: 0.250, green: 0.280, blue: 0.320)
    static let hullSunk = Color(red: 0.150, green: 0.175, blue: 0.210)
    static let hitRed = Color(red: 0.905, green: 0.255, blue: 0.195)
    static let hitGlow = Color(red: 1.00, green: 0.780, blue: 0.360)
    static let emberHi = Color(red: 0.640, green: 0.190, blue: 0.130)
    static let ember = Color(red: 0.420, green: 0.110, blue: 0.080)
    static let splash = Color(red: 0.930, green: 0.975, blue: 1.000)
    static let sonar = Color(red: 0.360, green: 0.700, blue: 0.820)
    static let sunkStamp = Color(red: 1.00, green: 0.820, blue: 0.360)
}

struct SeaBattleView: View {
    private static let accent = Color(red: 0.16, green: 0.42, blue: 0.68)
    private let accountID: UUID?
    private let playMode: GamePlayMode
    private let isOnline: Bool
    @ObservedObject private var online: OnlineMatchSession
    @StateObject private var persistence = PersistedGameSession<SeaBattleSnapshot>(gameID: .seaBattle)
    @AppStorage("seabattle.aiDifficulty") private var difficultyRaw = SeaBattleAIDifficulty.normal.rawValue
    @State private var game = SeaBattleGame.deploymentGame
    @State private var setup = SeaBattleSetupState.empty
    @State private var deployment = SeaBattleFleetDeployment()
    @State private var placementOrientation: SeaBattleOrientation = .horizontal
    @State private var deploymentDrag: DeploymentDragPreview?
    @State private var deploymentDragStart: SeaBattlePoint?
    @State private var appliedMoveCount = -1
    @State private var isAIThinking = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var aim: SeaBattlePoint?
    @State private var lastShot: ShotMark?
    @State private var burstShot: ShotMark?
    @State private var shotTick = 0
    @State private var hitShake: CGFloat = 0
    @State private var sunkFlash: SunkFlash?

    init(accountID: UUID? = nil, playMode: GamePlayMode = .soloBot, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.playMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    private var aiDifficulty: SeaBattleAIDifficulty {
        SeaBattleAIDifficulty(rawValue: difficultyRaw) ?? .normal
    }
    private var usesBot: Bool { playMode == .soloBot && !isOnline }
    private var mySide: SeaBattlePlayer {
        isOnline ? (online.isHost ? .host : .guest) : .host
    }
    private var targetPlayer: SeaBattlePlayer {
        if isOnline { return mySide.opponent }
        if usesBot { return .guest }
        return game.currentPlayer.opponent
    }
    private var ownPlayer: SeaBattlePlayer {
        if isOnline { return mySide }
        if usesBot { return .host }
        return game.currentPlayer
    }
    private var canFire: Bool {
        guard !setup.isDeploymentPhase else { return false }
        guard !game.isGameOver else { return false }
        if isOnline { return game.currentPlayer == mySide && online.isMyTurn }
        if usesBot { return game.currentPlayer == .host && !isAIThinking }
        return true
    }

    private var subtitle: String {
        if setup.isDeploymentPhase {
            if setup.isReady(mySide) {
                return isOnline ? "Waiting for \(online.opponentName ?? "friend") to deploy" : "Fleet ready"
            }
            if let nextLength = deployment.nextLength {
                return "Place your \(Self.shipName(forLength: nextLength))"
            }
            return "Ready your fleet"
        }
        if let winner = game.winner {
            if isOnline { return winner == mySide ? "You win!" : "\(online.opponentName ?? "Friend") wins" }
            return "\(name(winner)) wins"
        }
        if isOnline {
            return game.currentPlayer == mySide ? "Your salvo" : "\(online.opponentName ?? "Friend") aiming"
        }
        if usesBot {
            return game.currentPlayer == .host ? "Your salvo" : "\(aiDifficulty.title) AI plotting"
        }
        return "\(name(game.currentPlayer)) targeting"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                GameHeader(
                    title: "Sea Battle",
                    systemImage: "scope",
                    accent: Self.accent,
                    subtitle: subtitle
                ) {
                    if setup.isDeploymentPhase {
                        StatBadge(label: "Fleet", value: "\(deployment.placements.count)/\(SeaBattleGame.fleet.count)", accent: Self.accent)
                        StatBadge(label: "Ready", value: setup.isReady(mySide) ? "Yes" : "No", accent: Self.accent)
                    } else {
                        StatBadge(label: "Turn", value: name(game.currentPlayer), accent: Self.accent)
                        StatBadge(label: "Shots", value: "\(game.moveCount)", accent: Self.accent)
                    }
                }

                if setup.isDeploymentPhase {
                    deploymentSection
                } else {
                    targetSection

                    ownSection
                }

                bottomRail
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(Self.accent)
        .navigationTitle("Sea Battle")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: game.isGameOver) { _, over in
            guard over else { return }
            let iWon: Bool
            if isOnline { iWon = game.winner == mySide }
            else if usesBot { iWon = game.winner == .host }
            else { iWon = true }
            FeedbackCoordinator.fire(iWon ? .win : .lose)
        }
        .task(id: burstShot?.id) {
            guard burstShot != nil else { return }
            try? await Task.sleep(nanoseconds: 800_000_000)
            burstShot = nil
        }
        .task(id: sunkFlash?.id) {
            guard sunkFlash != nil else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.3)) { sunkFlash = nil }
        }
        .onChange(of: game.currentPlayer) { _, _ in
            aim = nil
            scheduleAIIfNeeded()
        }
        .onAppear {
            if isOnline {
                applyRemoteIfNeeded()
            } else {
                persistence.configure(accountID: accountID, cloudStore: .shared) { snapshot in
                    restore(snapshot)
                    scheduleAIIfNeeded()
                }
                scheduleAIIfNeeded()
            }
        }
        .onChange(of: difficultyRaw) { _, _ in if !isOnline { save() } }
        .onChange(of: online.match?.moveCount) { _, _ in applyRemoteIfNeeded() }
        .onDisappear { if !isOnline { save(forceCloud: true) } }
    }

    // MARK: - Sections

    private var deploymentSection: some View {
        let ready = setup.isReady(mySide)
        let placedLengths = deployment.placements.map(\.length)
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("DEPLOY FLEET")
                    .font(.caption.weight(.bold)).tracking(1.1)
                    .foregroundStyle(PrismetDesign.ink3)
                Spacer()
                Text(ready ? "LOCKED" : "STANDARD 5 SHIPS")
                    .font(.caption2.weight(.bold)).tracking(0.8)
                    .foregroundStyle(PrismetDesign.ink3)
            }

            oceanPanel {
                deploymentCoordinateBoard(interactive: !ready)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(Array(SeaBattleGame.fleet.enumerated()), id: \.offset) { index, length in
                        let requiredRank = SeaBattleGame.fleet.prefix(index + 1).filter { $0 == length }.count
                        let isPlaced = placedLengths.filter { $0 == length }.count >= requiredRank
                        Capsule()
                            .fill(isPlaced ? SeaTheme.hull : Color.primary.opacity(0.14))
                            .frame(width: CGFloat(length) * 11, height: 8)
                            .accessibilityLabel("\(Self.shipName(forLength: length)) \(isPlaced ? "placed" : "not placed")")
                    }
                    Spacer(minLength: 0)
                    Text(deployment.nextLength.map { "Next: \($0)" } ?? "Fleet complete")
                        .font(.footnote.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(PrismetDesign.ink2)
                }

                Picker("Ship direction", selection: $placementOrientation) {
                    Label("Horizontal", systemImage: "arrow.left.and.right").tag(SeaBattleOrientation.horizontal)
                    Label("Vertical", systemImage: "arrow.up.and.down").tag(SeaBattleOrientation.vertical)
                }
                .pickerStyle(.segmented)
                .disabled(ready)

                HStack(spacing: 10) {
                    Button {
                        autoDeployFleet()
                    } label: {
                        Label("Auto", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(NavalChipStyle(tint: SeaTheme.sonar))
                    .disabled(ready)

                    Button {
                        clearDeployment()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(NavalChipStyle(tint: SeaTheme.hitRed))
                    .disabled(ready || deployment.placements.isEmpty)

                    Spacer(minLength: 0)

                    Button {
                        commitDeployment()
                    } label: {
                        Label(ready ? "Ready" : (usesBot ? "Begin" : "Ready"), systemImage: ready ? "checkmark.seal.fill" : "flag.checkered")
                    }
                    .buttonStyle(NavalChipStyle(tint: Self.accent))
                    .disabled(ready || !deployment.isComplete)
                }
            }

            Text(ready ? "Your fleet is locked." : "Drag placed ships to move them. Tap open water to place the next ship; tap a ship to remove it.")
                .font(.caption)
                .foregroundStyle(PrismetDesign.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var targetSection: some View {
        let derived = derived(for: game.board(for: targetPlayer))
        let flags = sunkFlags(for: derived)
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("TARGET WATERS")
                    .font(.caption.weight(.bold)).tracking(1.1)
                    .foregroundStyle(PrismetDesign.ink3)
                Spacer()
                HStack(spacing: 6) {
                    Text("ENEMY FLEET")
                        .font(.caption2.weight(.bold)).tracking(0.8)
                        .foregroundStyle(PrismetDesign.ink3)
                    fleetPips(sunk: flags, height: 6, unit: 5)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Enemy fleet: \(flags.filter { !$0 }.count) of \(SeaBattleGame.fleet.count) ships afloat")
            }
            oceanPanel {
                // Enemy hulls must NEVER show before they're sunk — in any mode.
                // Hits/misses/sunk silhouettes carry all the information.
                coordinateBoard(for: targetPlayer, reveal: .hidden, interactive: true)
            }
            .modifier(ShakeEffect(animatableData: hitShake))
            .overlay { if game.isGameOver { victoryOverlay } }
            .overlay(alignment: .top) { sunkBanner }
            if canFire { aimRail }
        }
    }

    /// The target grid, framed with column numbers across the top and row letters
    /// down the side — the classic battleship look, and it reads as a real board.
    private func coordinateBoard(for player: SeaBattlePlayer, reveal: RevealStyle, interactive: Bool) -> some View {
        let gap: CGFloat = 3
        let railW: CGFloat = 15
        let labelFont = Font.system(size: 11, weight: .heavy, design: .rounded)
        return VStack(spacing: 5) {
            HStack(spacing: gap) {
                Color.clear.frame(width: railW, height: 12)
                ForEach(0..<SeaBattleGame.size, id: \.self) { c in
                    Text("\(c + 1)")
                        .font(labelFont)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(0..<SeaBattleGame.size, id: \.self) { r in
                        Text(Self.rowLetter(r))
                            .font(labelFont)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: railW)
                            .frame(maxHeight: .infinity)
                    }
                }
                boardGrid(for: player, reveal: reveal, interactive: interactive)
            }
        }
    }

    @ViewBuilder
    private var sunkBanner: some View {
        if let sunkFlash {
            Label("\(sunkFlash.name) sunk!", systemImage: "flame.fill")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [SeaTheme.hitRed, SeaTheme.emberHi], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(SeaTheme.sunkStamp.opacity(0.9), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                )
                .rotationEffect(.degrees(-3))
                .padding(.top, 12)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .id(sunkFlash.id)
        }
    }

    static func rowLetter(_ r: Int) -> String {
        String(UnicodeScalar(UInt8(65 + min(max(r, 0), 25))))
    }

    private var ownSection: some View {
        let derived = derived(for: game.board(for: ownPlayer))
        let flags = sunkFlags(for: derived)
        let afloat = flags.filter { !$0 }.count
        return HStack(alignment: .center, spacing: 14) {
            oceanPanel(padding: 7) {
                boardGrid(for: ownPlayer, reveal: .full, interactive: false)
            }
            .frame(maxWidth: 250)
            VStack(alignment: .leading, spacing: 9) {
                Text("YOUR FLEET")
                    .font(.caption.weight(.bold)).tracking(1.1)
                    .foregroundStyle(PrismetDesign.ink3)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(SeaBattleGame.fleet.enumerated()), id: \.offset) { index, length in
                        Capsule()
                            .fill(flags[index] ? Color.primary.opacity(0.14) : SeaTheme.hull)
                            .frame(width: CGFloat(length) * 9, height: 7)
                    }
                }
                Text("\(afloat) of \(SeaBattleGame.fleet.count) afloat")
                    .font(.footnote.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(PrismetDesign.ink2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your fleet: \(afloat) of \(SeaBattleGame.fleet.count) ships afloat")
            Spacer(minLength: 0)
        }
    }

    private var aimRail: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.footnote.weight(.bold))
                .foregroundStyle(SeaTheme.hitGlow)
            if let aim {
                Text(coordLabel(aim))
                    .font(PrismetDesign.rounded(18)).monospacedDigit()
                    .foregroundStyle(PrismetDesign.ink)
                Text("locked")
                    .font(.caption)
                    .foregroundStyle(PrismetDesign.ink3)
            } else {
                Text("Take aim")
                    .font(.subheadline)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            Spacer()
            Button {
                if let aim { fire(aim) }
            } label: {
                Text("FIRE").tracking(1.5)
            }
            .buttonStyle(FireButtonStyle())
            .disabled(aim == nil)
            .opacity(aim == nil ? 0.35 : 1)
            .accessibilityLabel(aim.map { "Fire at \(coordLabel($0))" } ?? "Fire, aim first")
        }
        .padding(.horizontal, 4)
    }

    private var bottomRail: some View {
        HStack(spacing: 12) {
            if usesBot {
                Picker("AI", selection: $difficultyRaw) {
                    ForEach(SeaBattleAIDifficulty.allCases) { difficulty in
                        Text(difficulty.title).tag(difficulty.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .accessibilityLabel("AI difficulty")
            } else {
                Spacer()
            }
            if isOnline {
                Button(role: .destructive) {
                    Task { await online.resign() }
                } label: {
                    Label("Strike the colors", systemImage: "flag.fill")
                }
                .buttonStyle(NavalChipStyle(tint: SeaTheme.hitRed))
                .accessibilityLabel("Resign")
            } else {
                Button {
                    resetBattle()
                } label: {
                    Label("New Battle", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(NavalChipStyle(tint: Self.accent))
                .accessibilityLabel("New Battle: redeploy both fleets")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var victoryOverlay: some View {
        let iWon = game.winner == mySide
        let title: String
        let sub: String
        if isOnline {
            title = iWon ? "Victory at Sea" : "Fleet Destroyed"
            sub = iWon ? "The enemy fleet is on the bottom." : "\(online.opponentName ?? "Friend") holds the waters."
        } else if usesBot {
            title = game.winner == .host ? "Victory at Sea" : "Fleet Destroyed"
            sub = game.winner == .host ? "\(aiDifficulty.title) AI defeated in \(game.moveCount) shots." : "\(aiDifficulty.title) AI holds the waters."
        } else {
            title = "\(name(game.winner ?? .host)) Wins"
            sub = "\(game.moveCount) shots fired"
        }
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(SeaTheme.deep2.opacity(0.78))
            .overlay {
                VStack(spacing: 6) {
                    Text(title)
                        .font(PrismetDesign.title(28))
                        .foregroundStyle(.white)
                    Text(sub)
                        .font(.subheadline).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(16)
                .multilineTextAlignment(.center)
            }
            .transition(.opacity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title). \(sub)")
    }

    // MARK: - Board rendering

    private enum RevealStyle { case full, sonar, hidden }

    private struct DeploymentDragPreview: Equatable {
        var id: SeaBattlePlacement.ID
        var length: Int
        var origin: SeaBattlePoint
        var orientation: SeaBattleOrientation
        var valid: Bool

        var cells: [SeaBattlePoint] {
            SeaBattleFleetDeployment.cells(length: length, at: origin, orientation: orientation)
        }
    }

    private func oceanPanel<Content: View>(padding: CGFloat = 10, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [SeaTheme.deep, SeaTheme.deep2], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
    }

    private func deploymentCoordinateBoard(interactive: Bool) -> some View {
        let gap: CGFloat = 3
        let railW: CGFloat = 15
        let labelFont = Font.system(size: 11, weight: .heavy, design: .rounded)
        return VStack(spacing: 5) {
            HStack(spacing: gap) {
                Color.clear.frame(width: railW, height: 12)
                ForEach(0..<SeaBattleGame.size, id: \.self) { c in
                    Text("\(c + 1)")
                        .font(labelFont)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(0..<SeaBattleGame.size, id: \.self) { r in
                        Text(Self.rowLetter(r))
                            .font(labelFont)
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: railW)
                            .frame(maxHeight: .infinity)
                    }
                }
                deploymentBoardGrid(interactive: interactive)
            }
        }
    }

    private func deploymentBoardGrid(interactive: Bool) -> some View {
        let gap: CGFloat = 3
        return GeometryReader { geo in
            let cellSize = (geo.size.width - gap * CGFloat(SeaBattleGame.size - 1)) / CGFloat(SeaBattleGame.size)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: SeaBattleGame.size), spacing: gap) {
                ForEach(0..<(SeaBattleGame.size * SeaBattleGame.size), id: \.self) { index in
                    let point = SeaBattlePoint(row: index / SeaBattleGame.size, col: index % SeaBattleGame.size)
                    deploymentCell(point, interactive: interactive, cellSize: cellSize, gap: gap)
                        .aspectRatio(1, contentMode: .fit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if interactive { deploymentCellTapped(point) }
                        }
                        .gesture(deploymentDragGesture(from: point, interactive: interactive, cellStride: cellSize + gap))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func deploymentCell(_ point: SeaBattlePoint, interactive: Bool, cellSize: CGFloat, gap: CGFloat) -> some View {
        let placementIndex = deployment.placements.firstIndex { $0.cells.contains(point) }
        let placement = placementIndex.map { deployment.placements[$0] }
        let isDraggingSource = placement?.id == deploymentDrag?.id
        let previewCells = Set(deploymentDrag?.cells ?? [])
        let isPreview = previewCells.contains(point)
        let ship = placementIndex != nil
        let canPlaceNext = deployment.nextLength != nil
        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill((point.row + point.col).isMultiple(of: 2) ? SeaTheme.water : SeaTheme.waterAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(SeaTheme.gridLine, lineWidth: 0.5)
                )
            if let placementIndex {
                HullSegment(
                    up: deployedPlacementIndex(at: SeaBattlePoint(row: point.row - 1, col: point.col)) == placementIndex,
                    down: deployedPlacementIndex(at: SeaBattlePoint(row: point.row + 1, col: point.col)) == placementIndex,
                    left: deployedPlacementIndex(at: SeaBattlePoint(row: point.row, col: point.col - 1)) == placementIndex,
                    right: deployedPlacementIndex(at: SeaBattlePoint(row: point.row, col: point.col + 1)) == placementIndex,
                    style: .full,
                    cellSize: cellSize,
                    gap: gap
                )
                .opacity(isDraggingSource ? 0.22 : 1)
                .allowsHitTesting(false)
            } else if interactive && canPlaceNext {
                Image(systemName: placementOrientation == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down")
                    .font(.system(size: cellSize * 0.44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.34))
                    .allowsHitTesting(false)
            }
            if let deploymentDrag, isPreview {
                HullSegment(
                    up: previewCells.contains(SeaBattlePoint(row: point.row - 1, col: point.col)),
                    down: previewCells.contains(SeaBattlePoint(row: point.row + 1, col: point.col)),
                    left: previewCells.contains(SeaBattlePoint(row: point.row, col: point.col - 1)),
                    right: previewCells.contains(SeaBattlePoint(row: point.row, col: point.col + 1)),
                    style: .full,
                    cellSize: cellSize,
                    gap: gap
                )
                .opacity(deploymentDrag.valid ? 0.88 : 0.42)
                .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(deploymentDrag.valid ? SeaTheme.hitGlow : SeaTheme.hitRed, lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coordLabel(point)), \(ship ? "ship" : "open water")")
        .accessibilityAddTraits(interactive ? .isButton : [])
        .accessibilityHint(interactive ? Text(ship ? "Drag to move this ship, or tap to remove it" : "Tap to place the next ship") : Text(""))
    }

    private func deployedPlacementIndex(at point: SeaBattlePoint) -> Int? {
        deployment.placements.firstIndex { $0.cells.contains(point) }
    }

    private func boardGrid(for player: SeaBattlePlayer, reveal: RevealStyle, interactive: Bool) -> some View {
        let board = game.board(for: player)
        let derived = derived(for: board)
        let gap: CGFloat = 3
        return GeometryReader { geo in
            let cellSize = (geo.size.width - gap * CGFloat(SeaBattleGame.size - 1)) / CGFloat(SeaBattleGame.size)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: SeaBattleGame.size), spacing: gap) {
                ForEach(0..<(SeaBattleGame.size * SeaBattleGame.size), id: \.self) { index in
                    let point = SeaBattlePoint(row: index / SeaBattleGame.size, col: index % SeaBattleGame.size)
                    cell(point, board: board, derived: derived, owner: player, reveal: reveal,
                         interactive: interactive, cellSize: cellSize, gap: gap)
                        .aspectRatio(1, contentMode: .fit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if interactive { cellTapped(point) }
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cell(_ point: SeaBattlePoint, board: SeaBattleBoard, derived: BoardDerived,
                      owner: SeaBattlePlayer, reveal: RevealStyle, interactive: Bool,
                      cellSize: CGFloat, gap: CGFloat) -> some View {
        let shot = board.shots.contains(point)
        let ship = board.shipCells.contains(point)
        let segIndex = derived.segMap[point]
        let sunk = segIndex.map { derived.sunkSegments.contains($0) } ?? false
        let showHull = ship && (sunk || reveal == .full || (reveal == .sonar && true))
        let hullStyle: HullStyle = sunk ? .sunk : (reveal == .full ? .full : .sonar)
        let aimedHere = interactive && aim == point

        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill((point.row + point.col).isMultiple(of: 2) ? SeaTheme.water : SeaTheme.waterAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(SeaTheme.gridLine, lineWidth: 0.5)
                )
            if showHull, let segIndex {
                HullSegment(
                    up: derived.segMap[SeaBattlePoint(row: point.row - 1, col: point.col)] == segIndex,
                    down: derived.segMap[SeaBattlePoint(row: point.row + 1, col: point.col)] == segIndex,
                    left: derived.segMap[SeaBattlePoint(row: point.row, col: point.col - 1)] == segIndex,
                    right: derived.segMap[SeaBattlePoint(row: point.row, col: point.col + 1)] == segIndex,
                    style: hullStyle, cellSize: cellSize, gap: gap
                )
                .allowsHitTesting(false)
            }
            if shot {
                if ship {
                    PegView(ember: sunk, cellSize: cellSize)
                        .allowsHitTesting(false)
                } else {
                    SplashView(cellSize: cellSize)
                        .allowsHitTesting(false)
                }
            }
            if let lastShot, lastShot.point == point, lastShot.boardOwner == owner, !aimedHere {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.4)
                    .allowsHitTesting(false)
            }
            if aimedHere {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(SeaTheme.hitGlow, lineWidth: 1.6)
                    Image(systemName: "scope")
                        .font(.system(size: cellSize * 0.58, weight: .semibold))
                        .foregroundStyle(SeaTheme.hitGlow)
                }
                .allowsHitTesting(false)
            }
            if let burstShot, burstShot.point == point, burstShot.boardOwner == owner, !reduceMotion {
                ShotBurstView(hit: burstShot.hit)
                    .id(burstShot.id)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellAccessibilityLabel(point, shot: shot, ship: ship, sunk: sunk, reveal: reveal, aimedHere: aimedHere))
        .accessibilityAddTraits(interactive ? .isButton : [])
        .accessibilityHint(interactive && !shot && canFire ? Text("Tap to aim, tap again to fire") : Text(""))
    }

    private func cellAccessibilityLabel(_ point: SeaBattlePoint, shot: Bool, ship: Bool, sunk: Bool,
                                        reveal: RevealStyle, aimedHere: Bool) -> String {
        var state: String
        if shot {
            state = ship ? (sunk ? "ship sunk" : "hit") : "miss"
        } else if ship && reveal == .full {
            state = "your ship"
        } else if ship && reveal == .sonar {
            state = "enemy ship sighted"
        } else {
            state = "open water"
        }
        if aimedHere { state += ", aimed" }
        return "\(coordLabel(point)), \(state)"
    }

    private func coordLabel(_ point: SeaBattlePoint) -> String {
        let letter = String(UnicodeScalar(UInt8(65 + min(max(point.row, 0), 25))))
        return "\(letter)-\(point.col + 1)"
    }

    // MARK: - Interaction (fire semantics preserved; aim step is view-only)

    private func deploymentDragGesture(from point: SeaBattlePoint, interactive: Bool, cellStride: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                guard interactive else { return }
                deploymentDragChanged(from: point, translation: value.translation, cellStride: cellStride)
            }
            .onEnded { _ in
                guard interactive else { return }
                deploymentDragEnded()
            }
    }

    private func deploymentDragChanged(from point: SeaBattlePoint, translation: CGSize, cellStride: CGFloat) {
        guard setup.isDeploymentPhase, !setup.isReady(mySide), cellStride > 0 else { return }

        if deploymentDrag == nil {
            guard let placement = deployment.placement(containing: point) else { return }
            deploymentDragStart = placement.origin
            deploymentDrag = DeploymentDragPreview(
                id: placement.id,
                length: placement.length,
                origin: placement.origin,
                orientation: placement.orientation,
                valid: true
            )
        }

        guard let preview = deploymentDrag,
              let placement = deployment.placement(id: preview.id),
              let start = deploymentDragStart
        else {
            deploymentDrag = nil
            deploymentDragStart = nil
            return
        }

        let origin = draggedShipOrigin(from: start, translation: translation, cellStride: cellStride)
        deploymentDrag = DeploymentDragPreview(
            id: placement.id,
            length: placement.length,
            origin: origin,
            orientation: placement.orientation,
            valid: deployment.canMoveShip(id: placement.id, to: origin, orientation: placement.orientation)
        )
    }

    private func draggedShipOrigin(from start: SeaBattlePoint, translation: CGSize, cellStride: CGFloat) -> SeaBattlePoint {
        let rowOffset = Int((translation.height / cellStride).rounded())
        let colOffset = Int((translation.width / cellStride).rounded())
        return SeaBattlePoint(row: start.row + rowOffset, col: start.col + colOffset)
    }

    private func deploymentDragEnded() {
        defer {
            deploymentDrag = nil
            deploymentDragStart = nil
        }
        guard setup.isDeploymentPhase, !setup.isReady(mySide), let preview = deploymentDrag, preview.valid else { return }
        guard deployment.moveShip(id: preview.id, to: preview.origin, orientation: preview.orientation) else { return }
        syncDeployment(ready: false)
        save(forceCloud: false)
    }

    private func deploymentCellTapped(_ point: SeaBattlePoint) {
        guard setup.isDeploymentPhase, !setup.isReady(mySide) else { return }
        if deployment.removeShip(containing: point) {
            syncDeployment(ready: false)
            save(forceCloud: false)
            return
        }
        guard let length = deployment.nextLength else { return }
        if deployment.place(length: length, at: point, orientation: placementOrientation) {
            syncDeployment(ready: false)
            save(forceCloud: false)
        }
    }

    private func autoDeployFleet() {
        guard setup.isDeploymentPhase, !setup.isReady(mySide) else { return }
        deploymentDrag = nil
        deploymentDragStart = nil
        deployment = SeaBattleFleetDeployment.random(seed: UInt64.random(in: 1...UInt64.max))
        syncDeployment(ready: false)
        save(forceCloud: false)
    }

    private func clearDeployment() {
        guard setup.isDeploymentPhase, !setup.isReady(mySide) else { return }
        deploymentDrag = nil
        deploymentDragStart = nil
        deployment.reset()
        syncDeployment(ready: false)
        save(forceCloud: false)
    }

    private func commitDeployment() {
        guard setup.isDeploymentPhase, deployment.isComplete, !setup.isReady(mySide) else { return }
        deploymentDrag = nil
        deploymentDragStart = nil
        syncDeployment(ready: true)

        if usesBot {
            let botDeployment = SeaBattleFleetDeployment.random(seed: UInt64.random(in: 1...UInt64.max))
            setup.setDeployment(botDeployment, for: .guest, ready: true)
            _ = startBattleIfReady()
            save(forceCloud: true)
            scheduleAIIfNeeded()
            return
        }

        _ = startBattleIfReady()
        if isOnline {
            sendMove()
        } else {
            save(forceCloud: true)
        }
    }

    private func syncDeployment(ready: Bool) {
        setup.setDeployment(deployment, for: mySide, ready: ready)
    }

    @discardableResult
    private func startBattleIfReady() -> Bool {
        guard setup.hostReady, setup.guestReady,
              let hostDeployment = setup.hostDeployment,
              let guestDeployment = setup.guestDeployment,
              let deployedGame = SeaBattleGame.gameFromDeployments(host: hostDeployment, guest: guestDeployment)
        else { return false }
        let needsBoards = game.moveCount == 0
            && game.winner == nil
            && (game.board(for: .host).shipCells.isEmpty || game.board(for: .guest).shipCells.isEmpty)
        if needsBoards {
            game = deployedGame
            aim = nil
            lastShot = nil
            burstShot = nil
            sunkFlash = nil
            isAIThinking = false
        }
        return true
    }

    private func resetBattle() {
        aim = nil
        lastShot = nil
        burstShot = nil
        sunkFlash = nil
        isAIThinking = false
        game = .deploymentGame
        setup = .empty
        deployment = SeaBattleFleetDeployment()
        deploymentDrag = nil
        deploymentDragStart = nil
        placementOrientation = .horizontal
        save(forceCloud: true)
    }

    private func cellTapped(_ point: SeaBattlePoint) {
        guard canFire else { return }
        guard !game.board(for: targetPlayer).shots.contains(point) else { return }
        if aim == point {
            fire(point)
        } else {
            aim = point
        }
    }

    private func fire(_ point: SeaBattlePoint) {
        let owner = targetPlayer
        let willHit = game.board(for: owner).shipCells.contains(point)
        guard canFire, game.fire(at: point) != .alreadyTried else { return }
        markShot(point, owner: owner, hit: willHit, mine: true)
        aim = nil
        if isOnline {
            sendMove()
        } else {
            save(forceCloud: game.isGameOver)
            scheduleAIIfNeeded()
        }
    }

    private func performAIShot() {
        guard usesBot, game.currentPlayer == .guest, !game.isGameOver else {
            isAIThinking = false
            return
        }
        let ai = SeaBattleAI(difficulty: aiDifficulty, seed: UInt64(game.moveCount + 97))
        guard let point = ai.shot(for: .guest, in: game) else {
            isAIThinking = false
            return
        }
        let owner = SeaBattlePlayer.host
        let willHit = game.board(for: owner).shipCells.contains(point)
        guard game.fire(at: point) != .alreadyTried else {
            isAIThinking = false
            return
        }
        markShot(point, owner: owner, hit: willHit)
        save(forceCloud: game.isGameOver)
        isAIThinking = false
        scheduleAIIfNeeded()
    }

    private func scheduleAIIfNeeded() {
        guard !setup.isDeploymentPhase else { return }
        guard usesBot, !isAIThinking, game.currentPlayer == .guest, !game.isGameOver else { return }
        isAIThinking = true
        Task {
            try? await Task.sleep(nanoseconds: reduceMotion ? 220_000_000 : 650_000_000)
            await MainActor.run { performAIShot() }
        }
    }

    /// `mine` = the local player pulled this trigger (vs the AI/opponent). Only my
    /// own hits earn the board jolt and the "SUNK!" banner.
    private func markShot(_ point: SeaBattlePoint, owner: SeaBattlePlayer, hit: Bool, mine: Bool = false) {
        let mark = ShotMark(id: UUID(), point: point, boardOwner: owner, hit: hit)
        lastShot = mark
        if !reduceMotion { burstShot = mark }
        shotTick += 1

        // Sound + haptic for every shot (mine or the opponent's): sink > hit > miss.
        // The just-fired cell completes a run exactly when it sinks that ship.
        let d = derived(for: game.board(for: owner))
        let sunkSeg = hit ? d.segMap[point].flatMap { d.sunkSegments.contains($0) ? $0 : nil } : nil
        FeedbackCoordinator.fire(sunkSeg != nil ? .sink : (hit ? .hit : .miss))

        guard mine, hit else { return }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.45)) { hitShake += 1 }
        }
        if let seg = sunkSeg {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                sunkFlash = SunkFlash(id: UUID(), name: Self.shipName(forLength: d.segments[seg].count))
            }
        }
    }

    private func sendMove() {
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(SeaBattleSnapshot(game: game, difficulty: aiDifficulty, setup: setup)) else { return }
        appliedMoveCount = (online.match?.moveCount ?? appliedMoveCount) + 1
        let inSetup = setup.isDeploymentPhase
        let winnerIsMe = inSetup ? nil : game.winner.map { $0 == mySide }
        Task {
            await online.sendMove(
                stateJSON: stateJSON,
                nextTurnIsMine: inSetup ? false : game.currentPlayer == mySide,
                finished: !inSetup && game.isGameOver,
                winnerIsMe: winnerIsMe
            )
        }
    }

    private func applyRemoteIfNeeded() {
        guard isOnline, let match = online.match, match.moveCount > appliedMoveCount else { return }
        guard let snapshot = try? GameSaveCodec.decodeSnapshot(SeaBattleSnapshot.self, from: match.stateJSON) else { return }
        let previousGame = game
        restore(snapshot)
        if let mark = newShotMark(from: previousGame, to: game) {
            lastShot = mark
            if !reduceMotion { burstShot = mark }
            shotTick += 1
        }
        appliedMoveCount = match.moveCount
        aim = nil
    }

    private func newShotMark(from old: SeaBattleGame, to new: SeaBattleGame) -> ShotMark? {
        guard new.moveCount == old.moveCount + 1 else { return nil }
        for player in [SeaBattlePlayer.host, .guest] {
            let fresh = new.board(for: player).shots.subtracting(old.board(for: player).shots)
            if let point = fresh.first {
                return ShotMark(id: UUID(), point: point, boardOwner: player,
                                hit: new.board(for: player).shipCells.contains(point))
            }
        }
        return nil
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: SeaBattleSnapshot(game: game, difficulty: aiDifficulty, setup: setup), score: game.moveCount, forceCloud: forceCloud)
    }

    private func restore(_ snapshot: SeaBattleSnapshot) {
        game = snapshot.game
        setup = snapshot.setup
        difficultyRaw = snapshot.difficulty.rawValue
        deployment = setup.deployment(for: mySide) ?? SeaBattleFleetDeployment()
        deploymentDrag = nil
        deploymentDragStart = nil
        _ = startBattleIfReady()
    }

    private func name(_ player: SeaBattlePlayer) -> String {
        if usesBot { return player == .host ? "You" : "\(aiDifficulty.title) AI" }
        return player == .host ? "Player 1" : "Player 2"
    }

    static func shipName(forLength length: Int) -> String {
        switch length {
        case 5: return "Carrier"
        case 4: return "Battleship"
        case 3: return "Destroyer"
        case 2: return "Patrol Boat"
        default: return "Ship"
        }
    }

    // MARK: - Derived ship segments (visual only; never reveals un-shot enemy cells online)

    private struct BoardDerived {
        var segMap: [SeaBattlePoint: Int]
        var segments: [[SeaBattlePoint]]
        var sunkSegments: Set<Int>
    }

    private func derived(for board: SeaBattleBoard) -> BoardDerived {
        let segments = Self.shipSegments(in: board.shipCells)
        var map: [SeaBattlePoint: Int] = [:]
        var sunk = Set<Int>()
        for (index, segment) in segments.enumerated() {
            for point in segment { map[point] = index }
            if segment.allSatisfy({ board.shots.contains($0) }) { sunk.insert(index) }
        }
        return BoardDerived(segMap: map, segments: segments, sunkSegments: sunk)
    }

    /// Greedy partition of the flat ship-cell set into straight runs. Ships may touch
    /// (the generator only prevents overlap), so this is best-effort — purely cosmetic.
    private static func shipSegments(in cells: Set<SeaBattlePoint>) -> [[SeaBattlePoint]] {
        var visited = Set<SeaBattlePoint>()
        var segments: [[SeaBattlePoint]] = []
        for cell in cells.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard !visited.contains(cell) else { continue }
            var run = [cell]
            let right = SeaBattlePoint(row: cell.row, col: cell.col + 1)
            if cells.contains(right) && !visited.contains(right) {
                var next = right
                while cells.contains(next) && !visited.contains(next) {
                    run.append(next)
                    next = SeaBattlePoint(row: next.row, col: next.col + 1)
                }
            } else {
                var next = SeaBattlePoint(row: cell.row + 1, col: cell.col)
                while cells.contains(next) && !visited.contains(next) {
                    run.append(next)
                    next = SeaBattlePoint(row: next.row + 1, col: next.col)
                }
            }
            visited.formUnion(run)
            segments.append(run)
        }
        return segments
    }

    private func sunkFlags(for derived: BoardDerived) -> [Bool] {
        var flags = [Bool](repeating: false, count: SeaBattleGame.fleet.count)
        let sunkLengths = derived.segments.enumerated()
            .filter { derived.sunkSegments.contains($0.offset) }
            .map { $0.element.count }
            .sorted(by: >)
        for length in sunkLengths {
            if let index = SeaBattleGame.fleet.indices.first(where: { !flags[$0] && SeaBattleGame.fleet[$0] == length }) {
                flags[index] = true
            } else if let index = flags.firstIndex(of: false) {
                flags[index] = true
            }
        }
        return flags
    }

    private func fleetPips(sunk: [Bool], height: CGFloat, unit: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(SeaBattleGame.fleet.enumerated()), id: \.offset) { index, length in
                Capsule()
                    .fill(sunk[index] ? Color.primary.opacity(0.14) : SeaTheme.hull)
                    .frame(width: CGFloat(length) * unit, height: height)
            }
        }
    }

    private struct ShotMark: Equatable {
        let id: UUID
        let point: SeaBattlePoint
        let boardOwner: SeaBattlePlayer
        let hit: Bool
    }

    struct SunkFlash: Equatable {
        let id: UUID
        let name: String
    }
}

// MARK: - Hull silhouette (the signature: continuous rounded top-down ship hulls)

private enum HullStyle { case full, sonar, sunk }

private struct HullSegment: View {
    var up: Bool
    var down: Bool
    var left: Bool
    var right: Bool
    var style: HullStyle
    var cellSize: CGFloat
    var gap: CGFloat

    var body: some View {
        let horizontal = left || right
        let nose = cellSize * 0.42
        let tight: CGFloat = 2
        let inset = cellSize * 0.13
        let endInset: CGFloat = 1.5
        let bridge = gap / 2 + 0.3
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: (left || up) ? tight : nose,
            bottomLeadingRadius: (left || down) ? tight : nose,
            bottomTrailingRadius: (right || down) ? tight : nose,
            topTrailingRadius: (right || up) ? tight : nose,
            style: .continuous
        )
        let isMiddle = (left && right) || (up && down)

        ZStack {
            switch style {
            case .full:
                shape.fill(
                    LinearGradient(colors: [SeaTheme.hullHi, SeaTheme.hull],
                                   startPoint: horizontal ? .top : .leading,
                                   endPoint: horizontal ? .bottom : .trailing)
                )
                .overlay(shape.strokeBorder(SeaTheme.hullShadow.opacity(0.85), lineWidth: 1))
                if isMiddle {
                    Circle()
                        .fill(SeaTheme.hullDeck)
                        .frame(width: cellSize * 0.20, height: cellSize * 0.20)
                }
            case .sunk:
                shape.fill(
                    LinearGradient(colors: [SeaTheme.hullSunkHi, SeaTheme.hullSunk],
                                   startPoint: horizontal ? .top : .leading,
                                   endPoint: horizontal ? .bottom : .trailing)
                )
                .overlay(shape.strokeBorder(Color.black.opacity(0.45), lineWidth: 1))
            case .sonar:
                shape.fill(SeaTheme.sonar.opacity(0.28))
                    .overlay(
                        shape.inset(by: 0.6)
                            .stroke(SeaTheme.sonar.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
                    )
            }
        }
        .padding(.top, up ? -bridge : (horizontal ? inset : endInset))
        .padding(.bottom, down ? -bridge : (horizontal ? inset : endInset))
        .padding(.leading, left ? -bridge : (horizontal ? endInset : inset))
        .padding(.trailing, right ? -bridge : (horizontal ? endInset : inset))
    }
}

// MARK: - Pegs, splashes, bursts

private struct PegView: View {
    var ember: Bool
    var cellSize: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: ember ? [SeaTheme.emberHi, SeaTheme.ember] : [SeaTheme.hitGlow, SeaTheme.hitRed],
                    center: UnitPoint(x: 0.35, y: 0.32),
                    startRadius: 0,
                    endRadius: cellSize * 0.34
                )
            )
            .overlay(Circle().strokeBorder(Color.black.opacity(0.28), lineWidth: 0.8))
            .padding(cellSize * (ember ? 0.30 : 0.24))
    }
}

private struct SplashView: View {
    var cellSize: CGFloat

    var body: some View {
        ZStack {
            // Concentric ripple rings settle into a bright droplet — a real splash.
            Circle()
                .strokeBorder(SeaTheme.splash.opacity(0.45), lineWidth: 1.1)
                .padding(cellSize * 0.13)
            Circle()
                .strokeBorder(SeaTheme.splash.opacity(0.70), lineWidth: 1.4)
                .padding(cellSize * 0.27)
            Circle()
                .fill(SeaTheme.splash.opacity(0.92))
                .padding(cellSize * 0.40)
        }
    }
}

private struct ShotBurstView: View {
    let hit: Bool
    @State private var live = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Expanding shockwave ring, both hit and miss.
                Circle()
                    .stroke(hit ? SeaTheme.hitGlow : SeaTheme.splash, lineWidth: live ? 0.8 : 4)
                    .scaleEffect(live ? 2.4 : 0.4)
                    .opacity(live ? 0 : 0.95)

                if hit {
                    // Bright fireball flash core.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, SeaTheme.hitGlow, SeaTheme.hitRed.opacity(0)],
                                center: .center, startRadius: 0, endRadius: s * 0.55
                            )
                        )
                        .scaleEffect(live ? 1.8 : 0.3)
                        .opacity(live ? 0 : 0.95)
                    // Embers flung outward.
                    ForEach(0..<8, id: \.self) { i in
                        let a = Double(i) / 8 * 2 * .pi
                        Circle()
                            .fill(i.isMultiple(of: 2) ? SeaTheme.hitGlow : SeaTheme.hitRed)
                            .frame(width: s * 0.13, height: s * 0.13)
                            .offset(x: live ? CGFloat(cos(a)) * s * 0.66 : 0,
                                    y: live ? CGFloat(sin(a)) * s * 0.66 : 0)
                            .opacity(live ? 0 : 1)
                    }
                } else {
                    // A second ripple + droplets for a satisfying miss.
                    Circle()
                        .stroke(SeaTheme.splash, lineWidth: live ? 0.6 : 2.4)
                        .scaleEffect(live ? 1.5 : 0.25)
                        .opacity(live ? 0 : 0.8)
                    ForEach(0..<6, id: \.self) { i in
                        let a = Double(i) / 6 * 2 * .pi
                        Circle()
                            .fill(SeaTheme.splash)
                            .frame(width: s * 0.09, height: s * 0.09)
                            .offset(x: live ? CGFloat(cos(a)) * s * 0.52 : 0,
                                    y: live ? CGFloat(sin(a)) * s * 0.52 : 0)
                            .opacity(live ? 0 : 0.9)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: hit ? 0.6 : 0.5)) { live = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A quick horizontal jolt driven by an incrementing counter — the board lurches
/// when your salvo connects. Settles exactly back to center (sin(nπ) == 0).
private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * CGFloat(sin(Double(animatableData) * .pi * Double(shakes)))
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

// MARK: - Button styles (no naked capsules on the play surface)

private struct FireButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.33, blue: 0.24), SeaTheme.hitRed],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(red: 0.55, green: 0.10, blue: 0.08).opacity(0.8), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
            .shadow(color: SeaTheme.hitRed.opacity(0.35), radius: 5, y: 2)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private struct NavalChipStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(SeaTheme.deep)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(tint.opacity(0.65), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white.opacity(0.92))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

#Preview {
    NavigationStack { SeaBattleView() }
}
