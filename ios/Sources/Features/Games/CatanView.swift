import SwiftUI

// PRISM: RELEASE Agent-Design/Claude 2026-07-12 — Catan (Settlers) touch view.
//
// Illuminated-manuscript styling to match the cabinet: FacetBackdrop + prismetCard
// surfaces, GameHeader, gilt accents. The board is drawn in a Canvas (hexes, number
// tokens, robber, roads, buildings) with a transparent tap overlay that surfaces only
// the currently-legal targets. Bots animate one placement / one turn at a time.

struct CatanView: View {
    private let accountID: UUID?
    @StateObject private var persistence = PersistedGameSession<CatanSnapshot>(gameID: .catan)

    @State private var game = CatanGame.newGame(seed: 1)
    @State private var buildMode: BuildMode = .none
    @State private var isBotWorking = false
    @State private var moveTick = 0
    @State private var didSetup = false
    @State private var showTrade = false
    @State private var tradeGive: CatanResource = .brick
    @State private var tradeGet: CatanResource = .grain

    // Customization (initialized from CatanPrefs; the customize sheet edits these live).
    @State private var showCustomize = false
    @State private var themeID = CatanPrefs.themeID
    @State private var pieceStyle = CatanPrefs.pieceStyle
    @State private var playerColorID = CatanPrefs.playerColorID
    @State private var boardStyle = CatanPrefs.boardStyle
    @State private var autoRotate = CatanPrefs.autoRotate
    @State private var reduceMotionPref = CatanPrefs.reduceMotionOverride
    @State private var difficulty = CatanPrefs.difficulty
    @State private var newGamePlayerCount = CatanPrefs.playerCount

    private let accent = Color(red: 0.80, green: 0.52, blue: 0.24)   // warm Catan amber

    private var theme: CatanTheme { CatanTheme.theme(id: themeID) }
    private var palette: [CatanRGB] {
        CatanPlayerColor.palette(humanColorID: playerColorID, playerCount: max(2, game.players.count))
    }
    private var boardReduceMotion: Bool { UIAccessibility.isReduceMotionEnabled || reduceMotionPref }

    enum BuildMode { case none, road, settlement, city }

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    // MARK: Body

    var body: some View {
        Group {
            if boardStyle == .threeD { threeDLayout } else { twoDLayout }
        }
        .navigationTitle("Catan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PrismetDesign.ground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCustomize = true } label: { Image(systemName: "paintpalette.fill") }
                    .accessibilityLabel("Customize")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { startNewGame() } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel("New game")
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: game.winner)
        .sheet(isPresented: $showTrade) { tradeSheet }
        .sheet(isPresented: $showCustomize) {
            CatanCustomizeSheet(
                themeID: $themeID, pieceStyle: $pieceStyle, playerColorID: $playerColorID,
                boardStyle: $boardStyle, autoRotate: $autoRotate, reduceMotion: $reduceMotionPref,
                difficulty: $difficulty, playerCount: $newGamePlayerCount,
                accent: accent, onStartNewGame: { startNewGame() }
            )
        }
        .onChange(of: themeID) { CatanPrefs.themeID = themeID }
        .onChange(of: pieceStyle) { CatanPrefs.pieceStyle = pieceStyle }
        .onChange(of: playerColorID) { CatanPrefs.playerColorID = playerColorID }
        .onChange(of: boardStyle) { CatanPrefs.boardStyle = boardStyle }
        .onChange(of: autoRotate) { CatanPrefs.autoRotate = autoRotate }
        .onChange(of: reduceMotionPref) { CatanPrefs.reduceMotionOverride = reduceMotionPref }
        .onChange(of: difficulty) { CatanPrefs.difficulty = difficulty }
        .onChange(of: newGamePlayerCount) { CatanPrefs.playerCount = newGamePlayerCount }
        .onAppear { setupOnce() }
        .onDisappear { save(forceCloud: true) }
    }

    private var twoDLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                GameHeader(title: "Catan", systemImage: "hexagon.fill", accent: accent, subtitle: statusText) {
                    diceView
                }
                scoreboard
                boardView
                if game.currentPlayer == 0 && game.winner == nil { resourceBar }
                controls
                logView
            }
            .padding(18)
        }
        .facetBackground(accent, multiHue: true)
    }

    private var threeDLayout: some View {
        VStack(spacing: 10) {
            scoreboard
                .padding(.horizontal, 12)
                .padding(.top, 8)
            board3D
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PrismetDesign.outline, lineWidth: 1))
                .padding(.horizontal, 10)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text(statusText)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(PrismetDesign.ink2)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    diceView
                }
                if game.currentPlayer == 0 && game.winner == nil { resourceBar }
                controls
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(FacetBackdrop(accent: accent))
    }

    private var board3D: some View {
        CatanBoard3DView(
            game: game,
            theme: theme,
            pieceStyle: pieceStyle,
            playerColors: palette,
            autoRotate: autoRotate,
            reduceMotion: boardReduceMotion,
            legalVertices: activeVertexTargets,
            legalEdges: activeEdgeTargets,
            legalHexes: activeHexTargets,
            accent: CatanRGB(r: 0.98, g: 0.86, b: 0.30),
            onTap: { intent in handleBoardTap(intent) }
        )
    }

    private func handleBoardTap(_ intent: CatanTapIntent) {
        switch intent {
        case .vertex(let v): tapVertex(v)
        case .edge(let e): tapEdge(e)
        case .hex(let h): tapHex(h)
        }
    }

    // MARK: Header pieces

    private var statusText: String {
        if let w = game.winner { return "\(game.players[w].name) wins!" }
        let name = game.players[game.currentPlayer].name
        let mine = game.currentPlayer == 0
        switch game.phase {
        case .setupSettlement: return mine ? "Place a settlement" : "\(name) is settling…"
        case .setupRoad: return mine ? "Place a road" : "\(name) is settling…"
        case .roll: return mine ? "Your turn — roll the dice" : "\(name) to roll"
        case .build: return isBotWorking ? "\(name) is building…" : (mine ? "Build, trade, or end turn" : "\(name)'s turn")
        case .moveRobber: return mine ? "Move the robber — tap a hex" : "\(name) moves the robber"
        case .gameOver: return "Game over"
        }
    }

    @ViewBuilder private var diceView: some View {
        if let roll = game.lastRoll {
            HStack(spacing: 4) {
                Image(systemName: "die.face.\(roll.a).fill")
                Image(systemName: "die.face.\(roll.b).fill")
            }
            .font(.title3)
            .foregroundStyle(accent)
        }
    }

    private var scoreboard: some View {
        HStack(spacing: 8) {
            ForEach(game.players.indices, id: \.self) { p in scoreChip(p) }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreChip(_ p: Int) -> some View {
        let isCurrent = game.currentPlayer == p
        return HStack(spacing: 5) {
            Circle().fill(playerColor(p)).frame(width: 9, height: 9)
            Text(game.players[p].name).font(.caption.weight(.semibold)).foregroundStyle(PrismetDesign.ink)
            Text("\(game.publicScore(for: p))").font(PrismetDesign.rounded(15)).monospacedDigit().foregroundStyle(playerColor(p))
            if game.longestRoadOwner == p { miniBadge("LR") }
            if game.largestArmyOwner == p { miniBadge("LA") }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(isCurrent ? playerColor(p).opacity(0.18) : PrismetDesign.panelHi))
        .overlay(Capsule().strokeBorder(isCurrent ? playerColor(p) : PrismetDesign.outline, lineWidth: isCurrent ? 1.5 : 1))
    }

    private func miniBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy)).tracking(0.5)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Capsule().fill(PrismetDesign.gold))
            .foregroundStyle(Color.white)
    }

    private var resourceBar: some View {
        HStack(spacing: 6) {
            ForEach(CatanResource.allCases, id: \.self) { r in
                HStack(spacing: 3) {
                    Image(systemName: r.symbolName).font(.caption2)
                    Text("\(game.players[0].resources[r] ?? 0)").font(PrismetDesign.rounded(14)).monospacedDigit()
                }
                .padding(.horizontal, 7).padding(.vertical, 5)
                .background(Capsule().fill(resourceColor(r).opacity(0.22)))
                .overlay(Capsule().strokeBorder(resourceColor(r).opacity(0.6), lineWidth: 1))
                .foregroundStyle(PrismetDesign.ink)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(game.log.suffix(3).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2).foregroundStyle(PrismetDesign.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Board

    private var boardView: some View {
        GeometryReader { geo in
            let layout = boardLayout(size: geo.size)
            let board = CatanBoard.standard
            ZStack {
                Canvas { ctx, _ in drawBoard(ctx, layout) }
                ForEach(activeVertexTargets, id: \.self) { v in
                    targetDot(color: accent)
                        .position(layout.screen(board.vertices[v]))
                        .onTapGesture { tapVertex(v) }
                }
                ForEach(activeEdgeTargets, id: \.self) { e in
                    let (a, b) = board.endpoints(of: e)
                    targetDot(color: accent)
                        .position(midpoint(layout.screen(board.vertices[a]), layout.screen(board.vertices[b])))
                        .onTapGesture { tapEdge(e) }
                }
                ForEach(activeHexTargets, id: \.self) { h in
                    targetDot(color: Color.black.opacity(0.55), size: 30)
                        .position(layout.screen(board.hexCenters[h]))
                        .onTapGesture { tapHex(h) }
                }
            }
        }
        .frame(height: 344)
        .prismetCard()
    }

    private func targetDot(color: Color, size: CGFloat = 24) -> some View {
        Circle()
            .fill(color.opacity(0.9))
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    private func drawBoard(_ ctx: GraphicsContext, _ layout: BoardLayout) {
        let board = CatanBoard.standard

        for hi in board.hexes.indices {
            let corners = board.hexVertexIndices[hi].map { layout.screen(board.vertices[$0]) }
            var path = Path()
            if let first = corners.first {
                path.move(to: first)
                for c in corners.dropFirst() { path.addLine(to: c) }
                path.closeSubpath()
            }
            ctx.fill(path, with: .color(resourceColor(game.tiles[hi].resource)))
            ctx.stroke(path, with: .color(PrismetDesign.ground.opacity(0.75)), lineWidth: 2)

            if let n = game.tiles[hi].number {
                let c = layout.screen(board.hexCenters[hi])
                let r = 0.32 * layout.scale
                let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(circle, with: .color(Color(white: 0.95)))
                ctx.stroke(circle, with: .color(.black.opacity(0.25)), lineWidth: 1)
                let hot = (n == 6 || n == 8)
                let label = Text("\(n)")
                    .font(.system(size: max(10, r), weight: hot ? .heavy : .bold, design: .rounded))
                    .foregroundColor(hot ? .red : Color(white: 0.12))
                ctx.draw(label, at: c)
            }
        }

        for (e, owner) in game.roads {
            let (a, b) = board.endpoints(of: e)
            var seg = Path()
            seg.move(to: layout.screen(board.vertices[a]))
            seg.addLine(to: layout.screen(board.vertices[b]))
            ctx.stroke(seg, with: .color(Color.black.opacity(0.45)),
                       style: StrokeStyle(lineWidth: max(6, 0.17 * layout.scale), lineCap: .round))
            ctx.stroke(seg, with: .color(playerColor(owner)),
                       style: StrokeStyle(lineWidth: max(4, 0.11 * layout.scale), lineCap: .round))
        }

        let rb = layout.screen(board.hexCenters[game.robberHex])
        let rr = 0.2 * layout.scale
        let robRect = CGRect(x: rb.x - rr, y: rb.y - rr, width: 2 * rr, height: 2 * rr * 1.3)
        ctx.fill(Path(roundedRect: robRect, cornerRadius: rr * 0.6), with: .color(Color(white: 0.1)))
        ctx.stroke(Path(roundedRect: robRect, cornerRadius: rr * 0.6), with: .color(.white.opacity(0.5)), lineWidth: 1)

        for (v, b) in game.buildings {
            let c = layout.screen(board.vertices[v])
            let s = (b.kind == .city ? 0.34 : 0.26) * layout.scale
            let rect = CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)
            let shape = Path(roundedRect: rect, cornerRadius: s * 0.22)
            ctx.fill(shape, with: .color(playerColor(b.owner)))
            ctx.stroke(shape, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            if b.kind == .city {
                let ir = s * 0.16
                let inner = Path(ellipseIn: CGRect(x: c.x - ir, y: c.y - ir, width: 2 * ir, height: 2 * ir))
                ctx.fill(inner, with: .color(PrismetDesign.gold))
            }
        }
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        if game.winner != nil {
            gameOverControls
        } else if game.currentPlayer != 0 {
            HStack(spacing: 8) {
                ProgressView().tint(accent)
                Text("\(game.players[game.currentPlayer].name) is thinking…")
                    .font(.subheadline).foregroundStyle(PrismetDesign.ink2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } else {
            switch game.phase {
            case .roll:
                Button { humanAction { _ = game.roll() } } label: {
                    Label("Roll Dice", systemImage: "dice.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: accent))
            case .build:
                buildControls
            case .setupSettlement, .setupRoad, .moveRobber:
                Text(instructionText)
                    .font(.subheadline).foregroundStyle(PrismetDesign.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            case .gameOver:
                EmptyView()
            }
        }
    }

    private var instructionText: String {
        switch game.phase {
        case .setupSettlement: return "Tap a highlighted corner to place your settlement."
        case .setupRoad: return "Tap a highlighted edge to place your road."
        case .moveRobber: return "Tap a hex to move the robber and steal a card."
        default: return ""
        }
    }

    private var buildControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                buildChip("Road", "minus", enabled: canBuildRoad, active: buildMode == .road) {
                    buildMode = (buildMode == .road ? .none : .road)
                }
                buildChip("Settle", "house.fill", enabled: canBuildSettlement, active: buildMode == .settlement) {
                    buildMode = (buildMode == .settlement ? .none : .settlement)
                }
                buildChip("City", "building.2.fill", enabled: canBuildCity, active: buildMode == .city) {
                    buildMode = (buildMode == .city ? .none : .city)
                }
            }
            HStack(spacing: 8) {
                buildChip("Dev Card", "sparkles", enabled: canBuyDev, active: false) {
                    humanAction { _ = game.buyDevCard() }
                }
                buildChip("Knight", "shield.fill", enabled: canPlayKnight, active: false) {
                    humanAction { _ = game.playKnight() }
                }
            }
            if buildMode != .none {
                HStack {
                    Text(buildPrompt).font(.caption).foregroundStyle(accent)
                    Spacer()
                    Button("Cancel") { buildMode = .none }.font(.caption.weight(.semibold)).foregroundStyle(PrismetDesign.ink2)
                }
            }
            HStack(spacing: 10) {
                Button { showTrade = true } label: {
                    Label("Trade 4:1", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassButtonStyle())
                Button { buildMode = .none; humanAction { _ = game.endTurn() } } label: {
                    Label("End Turn", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: accent))
            }
        }
    }

    private var buildPrompt: String {
        switch buildMode {
        case .road: return "Tap an edge to build a road."
        case .settlement: return "Tap a corner to build a settlement."
        case .city: return "Tap one of your settlements to upgrade."
        case .none: return ""
        }
    }

    private func buildChip(_ title: String, _ icon: String, enabled: Bool, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(active ? accent.opacity(0.22) : PrismetDesign.panelHi))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(active ? accent : PrismetDesign.outline, lineWidth: active ? 1.5 : 1))
        .foregroundStyle(enabled ? PrismetDesign.ink : PrismetDesign.ink3)
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)
    }

    private var gameOverControls: some View {
        VStack(spacing: 12) {
            Text("🏆 \(game.players[game.winner ?? 0].name) wins!")
                .font(PrismetDesign.title(22)).foregroundStyle(PrismetDesign.ink)
            VStack(spacing: 4) {
                ForEach(game.players.indices, id: \.self) { p in
                    HStack {
                        Circle().fill(playerColor(p)).frame(width: 9, height: 9)
                        Text(game.players[p].name).font(.subheadline).foregroundStyle(PrismetDesign.ink2)
                        Spacer()
                        Text("\(game.victoryPoints(for: p, includeHidden: true)) VP")
                            .font(PrismetDesign.rounded(15)).monospacedDigit().foregroundStyle(playerColor(p))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PrismetDesign.panelHi))
            Button { startNewGame() } label: {
                Label("New Game", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
        }
    }

    // MARK: Trade sheet

    private var tradeSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Trade 4 of one resource for 1 of another with the bank.")
                    .font(.subheadline).foregroundStyle(PrismetDesign.ink2)
                    .multilineTextAlignment(.center)
                resourcePicker(title: "Give 4", selection: $tradeGive, requireFour: true)
                Image(systemName: "arrow.down").foregroundStyle(accent)
                resourcePicker(title: "Get 1", selection: $tradeGet, requireFour: false)
                Button {
                    humanAction { _ = game.bankTrade(give: tradeGive, get: tradeGet) }
                    showTrade = false
                } label: {
                    Label("Confirm Trade", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: accent))
                .disabled(tradeGive == tradeGet || (game.players[0].resources[tradeGive] ?? 0) < 4)
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .facetBackground(accent)
            .navigationTitle("Bank Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showTrade = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func resourcePicker(title: String, selection: Binding<CatanResource>, requireFour: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(PrismetDesign.ink3)
            HStack(spacing: 8) {
                ForEach(CatanResource.allCases, id: \.self) { r in
                    let count = game.players[0].resources[r] ?? 0
                    let disabled = requireFour && count < 4
                    let selected = selection.wrappedValue == r
                    Button { selection.wrappedValue = r } label: {
                        VStack(spacing: 2) {
                            Image(systemName: r.symbolName).font(.system(size: 14))
                            Text("\(count)").font(.caption2).monospacedDigit()
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? resourceColor(r).opacity(0.3) : PrismetDesign.panelHi))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected ? resourceColor(r) : PrismetDesign.outline, lineWidth: selected ? 1.5 : 1))
                    .foregroundStyle(PrismetDesign.ink)
                    .opacity(disabled ? 0.4 : 1)
                    .disabled(disabled)
                }
            }
        }
    }

    // MARK: Affordances

    private var canBuildRoad: Bool {
        game.canAfford(CatanGame.roadCost, player: 0) && !game.legalRoadEdges(for: 0, isSetup: false).isEmpty
    }
    private var canBuildSettlement: Bool {
        game.canAfford(CatanGame.settlementCost, player: 0) && !game.legalSettlementVertices(for: 0, isSetup: false).isEmpty
    }
    private var canBuildCity: Bool {
        game.canAfford(CatanGame.cityCost, player: 0) && !game.legalCityVertices(for: 0).isEmpty
    }
    private var canBuyDev: Bool {
        game.canAfford(CatanGame.devCardCost, player: 0) && !game.devDeck.isEmpty
    }
    private var canPlayKnight: Bool {
        !game.players[0].playedDevThisTurn && game.players[0].devCards.contains(.knight)
    }

    // MARK: Targets

    private var activeVertexTargets: [Int] {
        guard game.currentPlayer == 0, !isBotWorking else { return [] }
        switch game.phase {
        case .setupSettlement: return game.legalSettlementVertices(for: 0, isSetup: true)
        case .build:
            if buildMode == .settlement { return game.legalSettlementVertices(for: 0, isSetup: false) }
            if buildMode == .city { return game.legalCityVertices(for: 0) }
            return []
        default: return []
        }
    }
    private var activeEdgeTargets: [Int] {
        guard game.currentPlayer == 0, !isBotWorking else { return [] }
        switch game.phase {
        case .setupRoad: return game.legalRoadEdges(for: 0, isSetup: true)
        case .build: return buildMode == .road ? game.legalRoadEdges(for: 0, isSetup: false) : []
        default: return []
        }
    }
    private var activeHexTargets: [Int] {
        guard game.currentPlayer == 0, !isBotWorking, game.phase == .moveRobber else { return [] }
        return game.legalRobberHexes()
    }

    // MARK: Tap handlers

    private func tapVertex(_ v: Int) {
        guard game.currentPlayer == 0, !isBotWorking else { return }
        switch game.phase {
        case .setupSettlement:
            humanAction { _ = game.placeSettlement(vertex: v) }
        case .build:
            if buildMode == .settlement { buildMode = .none; humanAction { _ = game.placeSettlement(vertex: v) } }
            else if buildMode == .city { buildMode = .none; humanAction { _ = game.placeCity(vertex: v) } }
        default: break
        }
    }

    private func tapEdge(_ e: Int) {
        guard game.currentPlayer == 0, !isBotWorking else { return }
        switch game.phase {
        case .setupRoad:
            humanAction { _ = game.placeRoad(edge: e) }
        case .build:
            if buildMode == .road { buildMode = .none; humanAction { _ = game.placeRoad(edge: e) } }
        default: break
        }
    }

    private func tapHex(_ h: Int) {
        guard game.currentPlayer == 0, !isBotWorking, game.phase == .moveRobber else { return }
        humanAction { _ = game.moveRobber(to: h) }
    }

    // MARK: Turn flow

    private func humanAction(_ body: () -> Void) {
        withAnimation(.easeInOut(duration: 0.2)) { body() }
        moveTick &+= 1
        save()
        advanceBotsIfNeeded()
    }

    private func advanceBotsIfNeeded() {
        guard game.winner == nil, game.currentPlayerIsBot, !isBotWorking else { return }
        isBotWorking = true
        let snapshot = game
        let diff = difficulty
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            let next = await Task.detached(priority: .userInitiated) { () -> CatanGame in
                var g = snapshot
                CatanAI(difficulty: diff).act(in: &g)
                return g
            }.value
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) { game = next }
                moveTick &+= 1
                isBotWorking = false
                save()
                advanceBotsIfNeeded()
            }
        }
    }

    private func startNewGame() {
        let seed = UInt64.random(in: 1...UInt64.max)
        withAnimation(.easeInOut(duration: 0.3)) {
            game = CatanGame.newGame(playerCount: newGamePlayerCount, seed: seed)
            buildMode = .none
        }
        save(forceCloud: true)
        advanceBotsIfNeeded()
    }

    // MARK: Persistence

    private func setupOnce() {
        guard !didSetup else { advanceBotsIfNeeded(); return }
        didSetup = true
        var restored = false
        persistence.configure(accountID: accountID, cloudStore: .shared) { snap in
            restored = true
            game = snap.game
            difficulty = snap.difficulty
        }
        if restored {
            advanceBotsIfNeeded()
        } else {
            startNewGame()
        }
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: CatanSnapshot(game: game, difficulty: difficulty), score: game.publicScore(for: 0), forceCloud: forceCloud)
    }

    // MARK: Geometry

    struct BoardLayout {
        var scale: CGFloat
        var ox: CGFloat
        var oy: CGFloat
        func screen(_ p: CatanPoint) -> CGPoint {
            CGPoint(x: CGFloat(p.x) * scale + ox, y: CGFloat(p.y) * scale + oy)
        }
    }

    private func boardLayout(size: CGSize) -> BoardLayout {
        let board = CatanBoard.standard
        let pad = 0.85
        let bx0 = board.minX - pad, bx1 = board.maxX + pad
        let by0 = board.minY - pad, by1 = board.maxY + pad
        let bw = CGFloat(bx1 - bx0), bh = CGFloat(by1 - by0)
        guard bw > 0, bh > 0, size.width > 0, size.height > 0 else { return BoardLayout(scale: 1, ox: 0, oy: 0) }
        let scale = min(size.width / bw, size.height / bh)
        let ox = (size.width - bw * scale) / 2 - CGFloat(bx0) * scale
        let oy = (size.height - bh * scale) / 2 - CGFloat(by0) * scale
        return BoardLayout(scale: scale, ox: ox, oy: oy)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    // MARK: Colors

    private func playerColor(_ p: Int) -> Color {
        let pal = palette
        return pal[p % pal.count].color
    }

    private func resourceColor(_ r: CatanResource?) -> Color {
        switch r {
        case .brick: return Color(red: 0.78, green: 0.42, blue: 0.28)
        case .lumber: return Color(red: 0.24, green: 0.44, blue: 0.30)
        case .wool: return Color(red: 0.62, green: 0.74, blue: 0.44)
        case .grain: return Color(red: 0.86, green: 0.70, blue: 0.28)
        case .ore: return Color(red: 0.46, green: 0.50, blue: 0.58)
        case nil: return Color(red: 0.82, green: 0.74, blue: 0.54)   // desert
        }
    }
}
