import SwiftUI

/// Lobby for "Online friend" play: host a match (share a 4-letter room code) or
/// join with a friend's code, then hand off to the game view once both players
/// are seated. One lobby serves every online-capable game.
struct OnlineGameLobbyView: View {
    let gameID: CanonicalGameID
    @ObservedObject var auth: AuthManager
    let playerName: String
    let playerEmoji: String

    @StateObject private var session = OnlineMatchSession()
    @State private var joinCode = ""
    @State private var retryingConnection = false
    @FocusState private var codeFieldFocused: Bool

    static let supportedGames: Set<CanonicalGameID> = [.chess, .checkers, .connectFour, .reversi, .gomoku, .crazyEight, .seaBattle]

    static func supports(_ gameID: CanonicalGameID) -> Bool {
        supportedGames.contains(gameID)
    }

    /// A fresh game snapshot, encoded exactly like the games' save files — the
    /// same codec both devices already use to persist state.
    static func initialStateJSON(for gameID: CanonicalGameID) throws -> String {
        switch gameID {
        case .chess:
            return try GameSaveCodec.encodeSnapshot(ChessSnapshot(
                position: .initial, selected: nil, targets: [], status: .ongoing, lastFrom: nil, lastTo: nil))
        case .checkers:
            return try GameSaveCodec.encodeSnapshot(CheckersSnapshot(game: CheckersGame(), selected: nil))
        case .connectFour:
            return try GameSaveCodec.encodeSnapshot(ConnectFourSnapshot(game: ConnectFourGame()))
        case .reversi:
            return try GameSaveCodec.encodeSnapshot(ReversiSnapshot(game: ReversiGame()))
        case .gomoku:
            return try GameSaveCodec.encodeSnapshot(GomokuSnapshot(game: GomokuGame()))
        case .crazyEight:
            return try GameSaveCodec.encodeSnapshot(CrazyEightSnapshot(game: CrazyEightGame.newGame(seed: 51), seed: 51))
        case .seaBattle:
            return try GameSaveCodec.encodeSnapshot(SeaBattleSnapshot(game: .deploymentGame, setup: .empty))
        default:
            throw OnlineMatchError.notConfigured
        }
    }

    private var card: GameCard? {
        GameCard.all.first { $0.canonicalGameID == gameID }
    }
    private var accent: Color { card?.accent ?? PrismetDesign.gold }
    private var gameTitle: String { card?.title ?? gameID.rawValue.capitalized }

    var body: some View {
        Group {
            switch session.phase {
            case .active, .finished:
                gameContainer
            default:
                lobby
            }
        }
        .navigationTitle("\(gameTitle) Online")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Leaving the lobby while still waiting frees the room code; an
            // in-progress game just stops watching (the row stays for the friend).
            if session.phase == .waitingForOpponent {
                let s = session
                Task { await s.cancelHosting() }
            }
            session.stop()
        }
    }

    // MARK: - Lobby

    private var lobby: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "\(gameTitle) Online",
                systemImage: "network",
                accent: accent,
                subtitle: "Play a friend on their own device"
            )

            if !auth.isCloudBacked {
                offlineNotice
            } else {
                switch session.phase {
                case .working(let label):
                    workingCard(label)
                case .waitingForOpponent:
                    hostingCard
                case .failed(let message):
                    failedCard(message)
                default:
                    pickerCards
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
    }

    private var pickerCards: some View {
        VStack(spacing: 14) {
            // Host
            VStack(alignment: .leading, spacing: 10) {
                Label("Host a match", systemImage: "antenna.radiowaves.left.and.right")
                    .font(PrismetDesign.rounded(18, .bold))
                    .foregroundStyle(PrismetDesign.ink)
                Text("You get a \(OnlineMatchStore.roomCodeLength)-letter code. Your friend types it on their device to join you.")
                    .font(.subheadline)
                    .foregroundStyle(PrismetDesign.ink2)
                Button {
                    Task {
                        guard let stateJSON = try? Self.initialStateJSON(for: gameID) else { return }
                        await session.host(
                            game: gameID,
                            playerName: playerName,
                            playerEmoji: playerEmoji,
                            initialStateJSON: stateJSON
                        )
                    }
                } label: {
                    Label("Get a code", systemImage: "dice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: accent))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismetCard()

            // Join
            VStack(alignment: .leading, spacing: 10) {
                Label("Join a friend", systemImage: "person.badge.key")
                    .font(PrismetDesign.rounded(18, .bold))
                    .foregroundStyle(PrismetDesign.ink)
                Text("Type the code your friend is showing you.")
                    .font(.subheadline)
                    .foregroundStyle(PrismetDesign.ink2)
                HStack(spacing: 10) {
                    TextField("CODE", text: $joinCode)
                        .font(PrismetDesign.rounded(26, .bold))
                        .tracking(6)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($codeFieldFocused)
                        .onChange(of: joinCode) { _, newValue in
                            let cleaned = OnlineMatchStore.normalizedRoomCode(newValue)
                            joinCode = String(cleaned.prefix(OnlineMatchStore.roomCodeLength))
                        }
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(PrismetDesign.panel)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(codeFieldFocused ? accent : PrismetDesign.outline, lineWidth: codeFieldFocused ? 2 : 1))
                        )
                    Button {
                        codeFieldFocused = false
                        Task {
                            await session.join(
                                game: gameID,
                                code: joinCode,
                                playerName: playerName,
                                playerEmoji: playerEmoji
                            )
                        }
                    } label: {
                        Text("Join")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(AccentButtonStyle(accent: accent))
                    .disabled(joinCode.count < OnlineMatchStore.roomCodeLength)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismetCard()
        }
    }

    private var hostingCard: some View {
        VStack(spacing: 16) {
            Text("YOUR ROOM CODE")
                .font(.caption.weight(.heavy)).tracking(2.4)
                .foregroundStyle(PrismetDesign.ink3)
            Text(session.roomCode ?? "----")
                .font(PrismetDesign.rounded(58, .bold))
                .tracking(14)
                .foregroundStyle(accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accent.opacity(0.5), lineWidth: 2))
                )
            HStack(spacing: 8) {
                ProgressView()
                Text("Waiting for your friend…")
                    .font(.subheadline)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            Text("On their device: \(gameTitle) ▸ Online friend ▸ Join, then this code.")
                .font(.caption)
                .foregroundStyle(PrismetDesign.ink3)
                .multilineTextAlignment(.center)
            Button {
                Task { await session.cancelHosting() }
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: PrismetDesign.ink))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .prismetCard()
    }

    private func workingCard(_ label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text(label)
                .font(PrismetDesign.rounded(17))
                .foregroundStyle(PrismetDesign.ink2)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .prismetCard()
    }

    private func failedCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PrismetDesign.ink2)
                .multilineTextAlignment(.center)
            Button {
                session.retryFromFailure()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .prismetCard()
    }

    private var offlineNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(accent)
            Text("Online play needs an internet connection.")
                .font(PrismetDesign.rounded(17))
                .foregroundStyle(PrismetDesign.ink)
            Text("Connect to Wi-Fi or cellular, then try again.")
                .font(.subheadline)
                .foregroundStyle(PrismetDesign.ink2)
            Button {
                retryingConnection = true
                Task {
                    await auth.restore()
                    retryingConnection = false
                }
            } label: {
                if retryingConnection {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .prismetCard()
    }

    // MARK: - Game hand-off

    @ViewBuilder
    private var gameContainer: some View {
        switch gameID {
        case .chess:
            ChessView(accountID: nil, playMode: .onlineFriend, online: session)
        case .checkers:
            CheckersView(accountID: nil, playMode: .onlineFriend, online: session)
        case .connectFour:
            ConnectFourView(accountID: nil, playMode: .onlineFriend, online: session)
        case .reversi:
            ReversiView(accountID: nil, playMode: .onlineFriend, online: session)
        case .gomoku:
            GomokuView(accountID: nil, playMode: .onlineFriend, online: session)
        case .crazyEight:
            CrazyEightView(accountID: nil, playMode: .onlineFriend, online: session)
        case .seaBattle:
            SeaBattleView(accountID: nil, playMode: .onlineFriend, online: session)
        default:
            EmptyView()
        }
    }
}
