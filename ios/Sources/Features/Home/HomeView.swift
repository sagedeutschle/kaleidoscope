// PRISM: RELEASE Agent-Design(shell) 2026-07-03 — v10 design pass
// PRISM: RELEASE Codex 2026-07-03 — Spider/Crazy 8/Sea Battle registry routes added
// PRISM: RELEASE Agent-Design/Claude 2026-07-12 — Catan game registry route added (Board)
// PRISM: RELEASE Codex 2026-07-15 — Casino main-app release route
import SwiftUI

struct GameCard: Identifiable {
    static let debtClockID = "debtclock"
    static let casinoID = "casino"
    // PRISM: Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens)
    static let steamRewindID = "steamrewind"

    let id: String
    let title: String
    let icon: String
    let accent: Color
    let ready: Bool
    let category: String

    var canonicalGameID: CanonicalGameID? {
        CanonicalGameID(rawValue: id)
    }

    static let all: [GameCard] = {
        var cards: [GameCard] = [
            .init(id: "2048", title: "2048", icon: "square.grid.2x2.fill", accent: Color(red: 0.86, green: 0.55, blue: 0.18), ready: true, category: "Puzzles"),
            .init(id: "snake", title: "Snake", icon: "point.topleft.down.to.point.bottomright.curvepath", accent: Color(red: 0.24, green: 0.46, blue: 0.66), ready: true, category: "Puzzles"),
            .init(id: "minesweeper", title: "Minesweeper", icon: "flag.checkered", accent: Color(red: 0.30, green: 0.55, blue: 0.42), ready: true, category: "Puzzles"),
            .init(id: "sudoku", title: "Sudoku", icon: "square.grid.3x3.fill", accent: Color(red: 0.70, green: 0.35, blue: 0.35), ready: true, category: "Puzzles"),
            .init(id: "rubiks", title: "Rubik's Cube", icon: "cube.fill", accent: Color(red: 0.46, green: 0.34, blue: 0.62), ready: true, category: "Puzzles"),
            .init(id: "lightsout", title: "Lights Out", icon: "lightbulb.fill", accent: Color(red: 0.85, green: 0.70, blue: 0.20), ready: true, category: "Puzzles"),
            .init(id: "sliding", title: "Sliding Puzzle", icon: "square.grid.4x3.fill", accent: Color(red: 0.30, green: 0.50, blue: 0.70), ready: true, category: "Puzzles"),
            .init(id: "nonogram", title: "Nonogram", icon: "grid", accent: Color(red: 0.55, green: 0.35, blue: 0.55), ready: true, category: "Puzzles"),
            .init(id: "chess", title: "Chess", icon: "crown.fill", accent: Color(red: 0.55, green: 0.40, blue: 0.22), ready: true, category: "Board"),
            .init(id: "reversi", title: "Reversi", icon: "circle.righthalf.filled", accent: Color(red: 0.20, green: 0.55, blue: 0.40), ready: true, category: "Board"),
            .init(id: "checkers", title: "Checkers", icon: "circle.grid.cross.fill", accent: Color(red: 0.70, green: 0.30, blue: 0.25), ready: true, category: "Board"),
            .init(id: "connectfour", title: "Connect Four", icon: "circle.grid.3x3.fill", accent: Color(red: 0.85, green: 0.55, blue: 0.20), ready: true, category: "Board"),
            .init(id: "gomoku", title: "Gomoku", icon: "circle.grid.3x3.fill", accent: Color(red: 0.42, green: 0.48, blue: 0.34), ready: true, category: "Board"),
            .init(id: "seabattle", title: "Sea Battle", icon: "scope", accent: Color(red: 0.16, green: 0.42, blue: 0.68), ready: true, category: "Board"),
            .init(id: "catan", title: "Catan", icon: "hexagon.fill", accent: Color(red: 0.80, green: 0.52, blue: 0.24), ready: true, category: "Board"),
            .init(id: "solitaire", title: "Solitaire", icon: "suit.spade.fill", accent: Color(red: 0.20, green: 0.45, blue: 0.30), ready: true, category: "Cards"),
            .init(id: "spider", title: "Spider", icon: "suit.spade.fill", accent: Color(red: 0.42, green: 0.24, blue: 0.18), ready: true, category: "Cards"),
            .init(id: "crazyeight", title: "Crazy 8", icon: "8.circle.fill", accent: Color(red: 0.60, green: 0.28, blue: 0.42), ready: true, category: "Cards"),
            .init(id: casinoID, title: "Casino", icon: "suit.spade.fill", accent: Color(red: 0.18, green: 0.46, blue: 0.36), ready: true, category: "Casino"),
            .init(id: "brickbench", title: "Brick Bench", icon: "square.stack.3d.up.fill", accent: Color(red: 0.80, green: 0.20, blue: 0.20), ready: true, category: "Workshop"),
            .init(id: "oracle", title: "Oracle", icon: "sparkles", accent: Color(red: 0.72, green: 0.54, blue: 0.20), ready: true, category: "Lenses"),
            .init(id: debtClockID, title: "Debt Clock", icon: "chart.line.uptrend.xyaxis", accent: Color(red: 0.20, green: 0.62, blue: 0.42), ready: true, category: "Lenses"),
            .init(id: steamRewindID, title: "Steam Rewind", icon: "gamecontroller.fill", accent: Color(red: 0.26, green: 0.42, blue: 0.72), ready: true, category: "Lenses")
        ]

        if WordleLaunchConfiguration.isEnabledForLaunchReview {
            cards.append(.init(id: "wordle", title: "Wordgame", icon: "a.square.fill", accent: Color(red: 0.40, green: 0.60, blue: 0.35), ready: true, category: "Daily"))
        }
        return cards
    }()

    static let categoryOrder = ["Daily", "Puzzles", "Board", "Cards", "Casino", "Workshop", "Lenses"]
}

struct HomeView: View {
    @ObservedObject var auth: AuthManager
    @ObservedObject var profiles: ProfileStore
    @StateObject private var adEntitlement = AdEntitlementStore.shared
    @State private var showMe = false
    @State private var showLeaderboard = false
    @State private var showRemoveAds = false
    @State private var showGameCenterHint = false
    @State private var showSettings = false
    // Default mirrors PrismetDesign.paper's fallback (dark) so the Reading picker reflects
    // the true paper before a choice is ever stored.
    @AppStorage("kaleido.paper") private var paperRaw = PrismetPaper.dark.rawValue

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brandStrip
                    ForEach(GameCard.categoryOrder, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(18)
            }
            .id(paperRaw)
            .background(FacetBackdrop(accent: PrismetDesign.gold, multiHue: true))
            .navigationTitle("Prismet")
            // Own the bar: an opaque ground-colored background keyed to the paper, so
            // the collapsed bar never shows stock translucent material (or floating
            // pills) over scrolled content.
            .toolbarBackground(PrismetDesign.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                if id == GameCard.debtClockID {
                    DebtClockStatsView()
                } else if id == GameCard.casinoID {
                    CasinoHubView()
                } else if id == GameCard.steamRewindID {
                    SteamRewindView()
                } else if let card = GameCard.all.first(where: { $0.id == id }),
                   let gameID = card.canonicalGameID {
                    if GameModeCatalog.requiresLaunchModeSelection(for: gameID) {
                        GameLaunchView(card: card, gameID: gameID, accountID: signedInAccountID)
                    } else {
                        gameDestination(for: GamePlayRoute(gameID: gameID, mode: .soloBot))
                    }
                } else {
                    EmptyView()
                }
            }
            .navigationDestination(for: GamePlayRoute.self) { route in
                gameDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Reading", selection: $paperRaw) {
                            ForEach(PrismetPaper.allCases) { Text($0.rawValue).tag($0.rawValue) }
                        }
                    } label: {
                        Label("Reading", systemImage: "circle.lefthalf.filled")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    // One social menu instead of three loose icons — same actions.
                    Menu {
                        Button { showLeaderboard = true } label: {
                            Label("Leaderboards", systemImage: "trophy")
                        }
                        Button {
                            if GameCenterFriends.presentAddFriend() == .notSignedIn {
                                showGameCenterHint = true
                            }
                        } label: {
                            Label("Add Friend", systemImage: "person.badge.plus")
                        }
                        Button {
                            if GameCenterFriends.presentFriendsList() == .notSignedIn {
                                showGameCenterHint = true
                            }
                        } label: {
                            Label("Friends", systemImage: "person.2")
                        }
                    } label: {
                        Label("Social", systemImage: "person.2")
                    }
                    .accessibilityLabel("Social — leaderboards and friends")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        // Remove Ads hidden for v1 — no IAP product/banking yet, so the
                        // purchase would fail review (Guideline 2.1). Re-enable once the
                        // App Store Connect IAP product + Paid Apps agreement are live.
                        Button { showSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Button { showMe = true } label: {
                            HStack(spacing: 6) {
                                Text(profiles.me?.avatarEmoji ?? "🎴")
                                Text(profiles.me?.displayName ?? "Me").font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showMe) { MeView(auth: auth, profiles: profiles) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLeaderboard) { LeaderboardView(accountID: signedInAccountID, gcAccountID: auth.gcAccountID) }
            .sheet(isPresented: $showRemoveAds) { RemoveAdsView(entitlement: adEntitlement) }
            .alert("Sign in to Game Center", isPresented: $showGameCenterHint) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Open Settings ▸ Game Center to sign in, then you can add friends and compare scores.")
            }
            .safeAreaInset(edge: .bottom) {
                if AdConfig.shouldDisplayBanner(adsRemoved: adEntitlement.adsRemoved, liveReadiness: AdConfig.currentLiveReadiness) {
                    BannerAdBar(entitlement: adEntitlement)
                        .padding(.top, 4)
                }
            }
        }
        .tint(PrismetDesign.gold)
        .preferredColorScheme(PrismetDesign.isDark ? .dark : .light)
        .task {
            configureLeaderboard()
            await adEntitlement.refreshPurchasedEntitlement()
        }
        .onChange(of: auth.state) { _, _ in
            configureLeaderboard()
        }
        .onChange(of: profiles.me) { _, _ in configureLeaderboard() }
        .onChange(of: auth.gcAccountID) { _, _ in configureLeaderboard() }
    }

    private func configureLeaderboard() {
        LeaderboardCoordinator.shared.configure(
            accountID: signedInAccountID,
            gcAccountID: auth.gcAccountID,
            displayName: profiles.me?.displayName,
            avatarEmoji: profiles.me?.avatarEmoji,
            avatarColor: profiles.me?.avatarColor)
    }

    private var signedInAccountID: UUID? {
        guard case let .signedIn(userID) = auth.state else { return nil }
        return userID
    }

    @ViewBuilder
    private func gameDestination(for route: GamePlayRoute) -> some View {
        if route.mode == .onlineFriend, OnlineGameLobbyView.supports(route.gameID) {
            OnlineGameLobbyView(
                gameID: route.gameID,
                auth: auth,
                playerName: profiles.me?.displayName ?? auth.displayName ?? "Player",
                playerEmoji: profiles.me?.avatarEmoji ?? "🎴"
            )
        } else {
            soloOrLocalDestination(for: route)
        }
    }

    @ViewBuilder
    private func soloOrLocalDestination(for route: GamePlayRoute) -> some View {
        switch route.gameID {
        case .game2048: Game2048View(accountID: signedInAccountID)
        case .minesweeper: MinesweeperView(accountID: signedInAccountID)
        case .snake: SnakeView(accountID: signedInAccountID)
        case .rubiks: RubiksCubeView(accountID: signedInAccountID)
        case .chess: ChessView(accountID: signedInAccountID, playMode: route.mode)
        case .sudoku: SudokuView(accountID: signedInAccountID)
        case .lightsOut: LightsOutView(accountID: signedInAccountID)
        case .slidingPuzzle: SlidingPuzzleView(accountID: signedInAccountID)
        case .nonogram: NonogramView(accountID: signedInAccountID)
        case .wordle: WordleView(accountID: signedInAccountID)
        case .reversi: ReversiView(accountID: signedInAccountID, playMode: route.mode, online: nil)
        case .checkers: CheckersView(accountID: signedInAccountID, playMode: route.mode)
        case .connectFour: ConnectFourView(accountID: signedInAccountID, playMode: route.mode, online: nil)
        case .gomoku: GomokuView(accountID: signedInAccountID, playMode: route.mode)
        case .seaBattle: SeaBattleView(accountID: signedInAccountID, playMode: route.mode, online: nil)
        case .solitaire: SolitaireView(accountID: signedInAccountID)
        case .spider: SpiderView(accountID: signedInAccountID)
        case .crazyEight: CrazyEightView(accountID: signedInAccountID, playMode: route.mode, online: nil)
        case .brickBench: BrickBenchView(accountID: signedInAccountID)
        case .oracle: OracleView(accountID: signedInAccountID)
        case .catan: CatanView(accountID: signedInAccountID)
        }
    }

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let cards = GameCard.all.filter { $0.category == category }
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(LinearGradient(colors: [PrismetDesign.gold, PrismetDesign.gold.opacity(0.35)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 13)
                    Text(category.uppercased())
                        .font(.caption.weight(.heavy)).tracking(2.4)
                        .foregroundStyle(PrismetDesign.gold)
                }
                .padding(.horizontal, 4)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(cards) { card in tile(card) }
                }
            }
        }
    }

    // The gilt brand lockup at the top of the scroll — kaleidoscope iris, tagline,
    // and the one-sentence thesis that tells a first-time visitor what the box holds.
    private var brandStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AngularGradient(gradient: Gradient(colors: PrismetDesign.wheel), center: .center))
                        .frame(width: 42, height: 42)
                    Circle().strokeBorder(PrismetDesign.gold, lineWidth: 2).frame(width: 42, height: 42)
                    Circle().fill(PrismetDesign.ground).frame(width: 13, height: 13)
                }
                .shadow(color: Color.black.opacity(0.16), radius: 5, y: 2)
                Text("Turn the lens.")
                    .font(.system(size: 17, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(PrismetDesign.ink2)
                Spacer()
            }
            Text("Classic games, daily puzzles, and live data lenses — one beautiful box.")
                .font(.footnote)
                .foregroundStyle(PrismetDesign.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [PrismetDesign.gold.opacity(0.55), PrismetDesign.gold.opacity(0.04)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tile(_ card: GameCard) -> some View {
        if card.ready {
            NavigationLink(value: card.id) { GameTile(card: card) }
                .buttonStyle(TilePressStyle())
        } else {
            GameTile(card: card)
                .opacity(0.5)
                .overlay(alignment: .topTrailing) {
                    Text("SOON")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(PrismetDesign.outline))
                        .foregroundStyle(PrismetDesign.panel)
                        .padding(10)
                }
        }
    }
}

// Purely presentational press feedback for the game tiles — a gentle scale/opacity
// dip on touch. Behaves like `.plain` otherwise, so navigation is unchanged.
private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct GameTile: View {
    let card: GameCard
    var body: some View {
        VStack(spacing: 12) {
            icon
            .frame(width: 62, height: 62)
            .shadow(color: card.accent.opacity(0.30), radius: 6, y: 3)
            Text(card.title).font(PrismetDesign.title(20)).foregroundStyle(PrismetDesign.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .prismetCard()
    }

    private var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
    }

    @ViewBuilder
    private var icon: some View {
        if gameTileImageIDs.contains(card.id) {
            Image("tile_\(card.id)")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(iconShape)
                .overlay(iconShape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        } else {
            // Engraved-plate fallback for games without tile art yet: an accent
            // lacquer plate with a gilt inner keyline and a debossed emblem, so a
            // missing asset still looks deliberate.
            ZStack {
                iconShape
                    .fill(LinearGradient(colors: [card.accent, card.accent.opacity(0.62)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                iconShape
                    .fill(RadialGradient(colors: [Color.white.opacity(0.16), .clear],
                                         center: .topLeading, startRadius: 2, endRadius: 66))
                iconShape
                    .inset(by: 3.5)
                    .strokeBorder(PrismetDesign.gold.opacity(0.65), lineWidth: 1)
                iconShape
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                Image(systemName: card.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .shadow(color: Color.black.opacity(0.35), radius: 0.5, y: 1)
            }
        }
    }
}
