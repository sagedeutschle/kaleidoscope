import SwiftUI
import UniformTypeIdentifiers

// PRISM: RELEASE Agent-A 2026-06-27 — rustic top bar: parchment toolbar background + centered gilt serif facet title-plate.
// PRISM: RELEASE Agent-B 2026-06-27 — persistence lifecycle hooks for arcade puzzle sessions.

struct ContentView: View {
    @StateObject private var game = GameState()
    @StateObject private var wordSession = WordPuzzleSession()
    @StateObject private var legoSession = LegoBuilderSession()
    @StateObject private var game2048Session = Game2048Session()
    @StateObject private var lightsOutSession = LightsOutSession()
    @StateObject private var rubiksCubeSession = RubiksCubeSession()
    @StateObject private var minesweeperSession = MinesweeperSession()
    @StateObject private var snakeSession = SnakeSession()
    @StateObject private var sudokuSession = SudokuSession()
    @StateObject private var slidingPuzzleSession = SlidingPuzzleSession()
    @StateObject private var nonogramSession = NonogramSession()
    @StateObject private var reversiSession = ReversiSession()
    @StateObject private var connectFourSession = ConnectFourSession()
    @StateObject private var checkersSession = CheckersSession()
    @StateObject private var gomokuSession = GomokuSession()
    @StateObject private var seaBattleSession = SeaBattleSession()
    @StateObject private var crazyEightSession = CrazyEightSession()
    @StateObject private var spiderSession = SpiderSession()
    @StateObject private var gameCenter = GameCenterAuthenticationController()
    @StateObject private var auth = AuthManager()
    @StateObject private var profiles = ProfileStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: String? = "chess"
    @State private var showAccount = false
    @AppStorage("kaleido.paper") private var paperRaw = KaleidoPaper.contrast.rawValue
    @State private var style: BoardStyle = .iso
    // Board theme is a user preference and persists across launches (defaults to
    // the chess.com green). Stored as the theme id; `theme` resolves it back.
    @AppStorage("chess.boardThemeID") private var boardThemeID: String = Theme.green.id
    private var theme: Theme { Theme.all.first { $0.id == boardThemeID } ?? .green }
    @State private var dragPlacement: Board3DDragPlacement = .loose
    @SceneStorage("window.session.id") private var windowSessionID = UUID().uuidString
    @State private var isChessExporting = false
    @State private var isChessImporting = false
    @State private var chessExportDocument = ChessGameFileDocument(snapshot: .placeholder)

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 700)
        .id(paperRaw)
        .preferredColorScheme(Kaleido.isDark ? .dark : .light)
        .tint(Kaleido.gold)
        .toolbar { toolbarContent }
        .toolbarBackground(Kaleido.ground, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarColorScheme(Kaleido.isDark ? .dark : .light, for: .windowToolbar)
        .task {
            bootstrapPersistence()
            gameCenter.startAuthentication()
            await auth.restore()
        }
        .onChange(of: auth.state) { _, state in
            if case .signedIn(let userID) = state {
                Task { await profiles.loadMine(userID: userID) }
            } else {
                profiles.reset()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { persistWindowState() }
        }
        .onChange(of: selection) { oldValue, newValue in
            saveSession(for: oldValue)
            reloadSession(for: newValue)
        }
        .onDisappear { persistWindowState() }
        .onChange(of: windowSessionID) { _, _ in bootstrapPersistence() }
        .fileExporter(isPresented: $isChessExporting,
                      document: chessExportDocument,
                      contentType: .json,
                      defaultFilename: "chess-save") { _ in }
        .fileImporter(isPresented: $isChessImporting,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handleChessImport(result)
        }
        .sheet(isPresented: $showAccount) {
            AccountPanelView(auth: auth, profiles: profiles)
        }
    }

    // MARK: - Sidebar (the persistent lens index)

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(FacetCategory.allCases) { category in
                let facets = FacetRegistry.all.filter { $0.category == category }
                if !facets.isEmpty {
                    Section {
                        ForEach(facets) { facet in
                            sidebarRow(facet)
                                .tag(facet.id)
                                .selectionDisabled(facet.status == .comingSoon)
                        }
                    } header: {
                        Text(category.rawValue.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(Kaleido.gold)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(sidebarParchment)
        .tint(Kaleido.gold)
        .navigationSplitViewColumnWidth(min: 212, ideal: 244, max: 300)
        .safeAreaInset(edge: .top, spacing: 0) { sidebarBrand }
    }

    private var sidebarParchment: some View {
        ZStack {
            Kaleido.ground
            Image("oracle_parchment")
                .resizable()
                .scaledToFill()
                .opacity(0.45)
                .blendMode(.multiply)
            // a faint gilt seam down the binding edge of the scroll
            HStack {
                Spacer()
                LinearGradient(colors: [.clear, Kaleido.gold.opacity(0.18)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
            }
        }
        .ignoresSafeArea()
    }

    private var sidebarBrand: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().strokeBorder(
                    AngularGradient(gradient: Gradient(colors: Kaleido.wheel), center: .center),
                    lineWidth: 3)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AngularGradient(gradient: Gradient(colors: Kaleido.wheel), center: .center))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text("Kaleidoscope")
                    .font(Kaleido.title(20))
                    .foregroundStyle(Kaleido.ink)
                Text("turn the lens.")
                    .font(.caption.italic())
                    .foregroundStyle(Kaleido.ink2)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Kaleido.ground)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, Kaleido.gold.opacity(0.7), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1.5)
        }
    }

    private func sidebarRow(_ facet: FacetDescriptor) -> some View {
        let ready = facet.status == .ready
        return HStack(spacing: 11) {
            Image(systemName: facet.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ready ? facet.accent : Kaleido.ink3)
                .frame(width: 22)
            Text(facet.title)
                .font(.body)
                .foregroundStyle(ready ? Kaleido.ink : Kaleido.ink3)
            Spacer()
            if !ready {
                Text("soon")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Kaleido.ink3)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail (the active facet)

    @ViewBuilder
    private var detailPane: some View {
        Group {
            switch selection {
            case "chess": chessDetail
            case "brick-bench": LegoBuilderView(session: legoSession)
            case "wordle": WordPuzzleView(session: wordSession)
            case "oracle": DecreeView()
            case "debt-clock": DebtClockStatsView()
            case "steam-rewind": SteamRewindLensView()
            case "2048": Game2048View(session: game2048Session)
            case "lights-out": LightsOutView(session: lightsOutSession)
            case "rubiks-cube": RubiksCubeView(session: rubiksCubeSession)
            case "minesweeper": MinesweeperView(session: minesweeperSession)
            case "snake": SnakeView(session: snakeSession)
            case "sudoku": SudokuView(session: sudokuSession)
            case "sliding-15": SlidingPuzzleView(session: slidingPuzzleSession)
            case "nonogram": NonogramView(session: nonogramSession)
            case "reversi": ReversiView(session: reversiSession)
            case "connect-four": ConnectFourView(session: connectFourSession)
            case "checkers": CheckersView(session: checkersSession)
            case "solitaire": SolitaireView()
            case "gomoku": GomokuView(session: gomokuSession)
            case "sea-battle": SeaBattleView(session: seaBattleSession)
            case "crazy-8": CrazyEightView(session: crazyEightSession)
            case "spider": SpiderView(session: spiderSession)
            default: welcomeDetail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kaleido.ground)
    }

    private var welcomeDetail: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().strokeBorder(
                    AngularGradient(gradient: Gradient(colors: Kaleido.wheel), center: .center),
                    lineWidth: 5)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AngularGradient(gradient: Gradient(colors: Kaleido.wheel), center: .center))
            }
            .frame(width: 86, height: 86)
            .shadow(color: Kaleido.gold.opacity(0.4), radius: 12)

            Text("Kaleidoscope")
                .font(Kaleido.title(34))
                .foregroundStyle(Kaleido.ink)
            Text("Turn the lens — choose a facet from the scroll.")
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(Kaleido.ink2)
        }
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Kaleido.panel.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Kaleido.gold.opacity(0.55), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Kaleido.gold.opacity(0.30), lineWidth: 1)
                        .padding(6)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FacetBackdrop(accent: Kaleido.gold, multiHue: true))
    }

    private var chessDetail: some View {
        VStack(spacing: 0) {
            chessArea
            Divider()
            chessStatusBar
        }
    }

    private var chessArea: some View {
        ZStack {
            // PRISM: Agent-Mac 2026-07-03 — Chess "study table" felt ground (mirrors iOS v10). Chrome only.
            ChessStudyGround(theme: theme)
                .ignoresSafeArea()
            boardArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.30), value: style)
    }

    @ViewBuilder
    private var boardArea: some View {
        switch style {
        case .flat:
            // The flat board sits in a turned-wood frame on the felt table.
            ChessStudyFrame(theme: theme) {
                Board2DView(game: game, theme: theme)
            }
            .padding(24)
            .transition(.opacity)
        case .iso:
            Board3DView(game: game, theme: theme, dragPlacement: dragPlacement)
                .transition(.opacity)
        }
    }

    private var chessStatusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(game.position.sideToMove == .white ? Color.white : Color.black)
                .frame(width: 13, height: 13)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.5)))
            Text(statusText)
                .font(.headline)
            if game.isThinking {
                ProgressView().controlSize(.small).padding(.leading, 4)
                Text("thinking…").foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(GameState.levelName(game.aiLevel)) · \(style.label)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Kaleido.ground)
    }

    // MARK: - Toolbar (chess only)

    private var aiLevelBinding: Binding<Double> {
        Binding(
            get: { Double(game.aiLevel) },
            set: { game.aiLevel = Int($0.rounded()) }
        )
    }

    private var facetTitlePlate: some View {
        HStack(spacing: 8) {
            if let id = selection, let facet = FacetRegistry.descriptor(for: id) {
                Image(systemName: facet.systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(facet.accent)
                Text(facet.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Kaleido.ink)
            } else {
                Text("Kaleidoscope")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Kaleido.ink)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Kaleido.panel.opacity(0.7))
                .overlay(Capsule().strokeBorder(Kaleido.gold.opacity(0.45), lineWidth: 1))
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            facetTitlePlate
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Picker("Reading", selection: $paperRaw) {
                    ForEach(KaleidoPaper.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            } label: {
                Label("Reading", systemImage: "circle.lefthalf.filled")
            }
            .help("Reading contrast — High Contrast, Parchment, or Dark")
        }

        ToolbarItem(placement: .automatic) {
            GameCenterStatusControl(controller: gameCenter)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showAccount = true
            } label: {
                Label(accountLabel, systemImage: accountIcon)
            }
            .help("Kaleidoscope account shared with the mobile app")
        }

        if selection == "chess" {
            ToolbarItemGroup(placement: .automatic) {
                Picker("View", selection: $style.animation(.easeInOut)) {
                    ForEach(BoardStyle.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Hot-swap between the flat 2D board and the isometric 3D board")
                Menu {
                    Picker("Theme", selection: $boardThemeID) {
                        ForEach(Theme.all) { t in Text(t.name).tag(t.id) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(theme.name, systemImage: "paintpalette")
                }
                .help("Board theme — your choice is remembered")

                Menu {
                    Picker("3D Drag", selection: $dragPlacement) {
                        ForEach(Board3DDragPlacement.allCases) { placement in
                            Text(placement.rawValue).tag(placement)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("3D Drag: \(dragPlacement.rawValue)", systemImage: "hand.draw")
                }
                .help(dragPlacement.help)

                HStack(spacing: 7) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.secondary)
                    Slider(value: aiLevelBinding, in: 1...10, step: 1)
                        .frame(width: 120)
                    Text("\(game.aiLevel)")
                        .monospacedDigit()
                        .frame(width: 16, alignment: .trailing)
                }
                .help("AI strength: \(GameState.levelName(game.aiLevel)) (\(game.aiLevel)/10)")

                Button {
                    game.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(game.isThinking)
                .help("Take back your last move")

                Button {
                    game.newGame()
                } label: {
                    Label("New Game", systemImage: "arrow.clockwise")
                }
                .help("Start a new game")

                Menu {
                    Button("Save Chess") { game.saveNow() }
                    Button("Load Chess") { game.reloadSavedState() }
                    Button("Export Chess...") {
                        chessExportDocument = ChessGameFileDocument(snapshot: game.snapshot())
                        isChessExporting = true
                    }
                    Button("Import Chess...") {
                        isChessImporting = true
                    }
                } label: {
                    Label("State", systemImage: "externaldrive")
                }
                .help("Save, load, export, or import this chess window")
            }
        }
    }

    private var accountLabel: String {
        switch auth.state {
        case .loading:
            return "Account"
        case .signedOut:
            return "Sign In"
        case .signedIn:
            return profiles.me?.displayName ?? "Account"
        }
    }

    private var accountIcon: String {
        switch auth.state {
        case .loading:
            return "person.crop.circle"
        case .signedOut:
            return "person.crop.circle.badge.plus"
        case .signedIn:
            return "person.crop.circle.fill"
        }
    }

    // MARK: - Status text

    private var statusText: String {
        switch game.status {
        case .ongoing:
            return game.position.sideToMove == .white ? "White to move" : "Black to move"
        case .check(let c):
            return "\(c == .white ? "White" : "Black") — Check!"
        case .checkmate(let winner):
            return "Checkmate — \(winner == .white ? "White" : "Black") wins"
        case .stalemate:
            return "Stalemate — draw"
        case .draw:
            return "Draw"
        }
    }

    // MARK: - Persistence

    private func bootstrapPersistence() {
        game.configurePersistence(windowSessionID: windowSessionID)
        wordSession.configurePersistence(windowSessionID: windowSessionID)
        legoSession.configurePersistence(windowSessionID: windowSessionID)
        minesweeperSession.configurePersistence(windowSessionID: windowSessionID)
        game2048Session.configurePersistence(windowSessionID: windowSessionID)
        lightsOutSession.configurePersistence(windowSessionID: windowSessionID)
        snakeSession.configurePersistence(windowSessionID: windowSessionID)
        rubiksCubeSession.configurePersistence(windowSessionID: windowSessionID)
        sudokuSession.configurePersistence(windowSessionID: windowSessionID)
        slidingPuzzleSession.configurePersistence(windowSessionID: windowSessionID)
        nonogramSession.configurePersistence(windowSessionID: windowSessionID)
        reversiSession.configurePersistence(windowSessionID: windowSessionID)
        connectFourSession.configurePersistence(windowSessionID: windowSessionID)
        checkersSession.configurePersistence(windowSessionID: windowSessionID)
        gomokuSession.configurePersistence(windowSessionID: windowSessionID)
        seaBattleSession.configurePersistence(windowSessionID: windowSessionID)
        crazyEightSession.configurePersistence(windowSessionID: windowSessionID)
        spiderSession.configurePersistence(windowSessionID: windowSessionID)
    }

    private func persistWindowState() {
        game.saveNow()
        wordSession.saveNow()
        legoSession.saveNow()
        minesweeperSession.saveNow()
        game2048Session.saveNow()
        lightsOutSession.saveNow()
        snakeSession.saveNow()
        rubiksCubeSession.saveNow()
        sudokuSession.saveNow()
        slidingPuzzleSession.saveNow()
        nonogramSession.saveNow()
        reversiSession.saveNow()
        connectFourSession.saveNow()
        checkersSession.saveNow()
    }

    private func saveSession(for facetID: String?) {
        switch facetID {
        case "wordle": wordSession.saveNow()
        case "brick-bench": legoSession.saveNow()
        case "minesweeper": minesweeperSession.saveNow()
        case "2048": game2048Session.saveNow()
        case "lights-out": lightsOutSession.saveNow()
        case "snake": snakeSession.saveNow()
        case "rubiks-cube": rubiksCubeSession.saveNow()
        case "sudoku": sudokuSession.saveNow()
        case "sliding-15": slidingPuzzleSession.saveNow()
        case "nonogram": nonogramSession.saveNow()
        case "reversi": reversiSession.saveNow()
        case "connect-four": connectFourSession.saveNow()
        case "checkers": checkersSession.saveNow()
        case "gomoku": gomokuSession.saveNow()
        case "sea-battle": seaBattleSession.saveNow()
        case "crazy-8": crazyEightSession.saveNow()
        case "spider": spiderSession.saveNow()
        default: break
        }
    }

    private func reloadSession(for facetID: String?) {
        switch facetID {
        case "wordle": wordSession.reloadSavedState()
        case "brick-bench": legoSession.reloadSavedState()
        case "minesweeper": minesweeperSession.reloadSavedState()
        case "2048": game2048Session.reloadSavedState()
        case "lights-out": lightsOutSession.reloadSavedState()
        case "snake": snakeSession.reloadSavedState()
        case "rubiks-cube": rubiksCubeSession.reloadSavedState()
        case "sudoku": sudokuSession.reloadSavedState()
        case "sliding-15": slidingPuzzleSession.reloadSavedState()
        case "nonogram": nonogramSession.reloadSavedState()
        case "reversi": reversiSession.reloadSavedState()
        case "connect-four": connectFourSession.reloadSavedState()
        case "checkers": checkersSession.reloadSavedState()
        case "gomoku": gomokuSession.reloadSavedState()
        case "sea-battle": seaBattleSession.reloadSavedState()
        case "crazy-8": crazyEightSession.reloadSavedState()
        case "spider": spiderSession.reloadSavedState()
        default: break
        }
    }

    private func handleChessImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let snapshot = try GamePersistenceStore.shared.importChess(from: url)
            game.restore(from: snapshot)
        } catch {
            // Leave the current game intact if the import fails.
        }
    }
}
