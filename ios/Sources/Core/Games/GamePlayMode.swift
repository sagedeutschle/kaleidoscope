import Foundation

enum GamePlayMode: String, CaseIterable, Codable, Hashable, Identifiable {
    case soloBot
    case localTwoPlayer
    case onlineFriend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soloBot: return "Solo"
        case .localTwoPlayer: return "Local 2-player"
        case .onlineFriend: return "Online friend"
        }
    }

    var subtitle: String {
        switch self {
        case .soloBot: return "Play this game on this phone."
        case .localTwoPlayer: return "Two people share this phone."
        case .onlineFriend: return "Two phones over the internet."
        }
    }

    var systemImage: String {
        switch self {
        case .soloBot: return "person.fill"
        case .localTwoPlayer: return "person.2.fill"
        case .onlineFriend: return "network"
        }
    }
}

enum GameModeStatus: String, Codable, Hashable {
    case playable
    case planned
}

struct GameModeOption: Codable, Hashable, Identifiable {
    var mode: GamePlayMode
    var status: GameModeStatus

    var id: GamePlayMode { mode }
    var isPlayable: Bool { status == .playable }

    static func playable(_ mode: GamePlayMode) -> GameModeOption {
        GameModeOption(mode: mode, status: .playable)
    }

    static func planned(_ mode: GamePlayMode) -> GameModeOption {
        GameModeOption(mode: mode, status: .planned)
    }
}

struct GameModeSupport: Codable, Hashable, Identifiable {
    var gameID: CanonicalGameID
    var options: [GameModeOption]

    var id: CanonicalGameID { gameID }
}

enum GameModeCatalog {
    private static let botAndHotSeatOptions: [GameModeOption] = [
        .playable(.soloBot),
        .playable(.localTwoPlayer),
        .playable(.onlineFriend)
    ]

    private static let botAndOnlineOptions: [GameModeOption] = [
        .playable(.soloBot),
        .playable(.onlineFriend)
    ]

    static let all: [GameModeSupport] = CanonicalGameID.allCases.map { gameID in
        GameModeSupport(gameID: gameID, options: optionsForCatalog(gameID))
    }

    static func support(for gameID: CanonicalGameID) -> GameModeSupport {
        GameModeSupport(gameID: gameID, options: optionsForCatalog(gameID))
    }

    static func options(for gameID: CanonicalGameID) -> [GameModeOption] {
        optionsForCatalog(gameID)
    }

    static func option(for gameID: CanonicalGameID, mode: GamePlayMode) -> GameModeOption? {
        options(for: gameID).first { $0.mode == mode }
    }

    static func playableModes(for gameID: CanonicalGameID) -> [GamePlayMode] {
        options(for: gameID).filter(\.isPlayable).map(\.mode)
    }

    static func requiresLaunchModeSelection(for gameID: CanonicalGameID) -> Bool {
        options(for: gameID).contains { $0.mode != .soloBot }
    }

    private static func optionsForCatalog(_ gameID: CanonicalGameID) -> [GameModeOption] {
        switch gameID {
        case .chess, .checkers, .reversi, .connectFour, .gomoku, .crazyEight:
            return botAndHotSeatOptions
        case .seaBattle:
            return botAndOnlineOptions
        case .game2048, .snake, .minesweeper, .sudoku, .rubiks, .lightsOut,
             .slidingPuzzle, .nonogram, .wordle, .solitaire, .spider, .brickBench, .oracle, .catan:
            return [.playable(.soloBot)]
        }
    }
}
