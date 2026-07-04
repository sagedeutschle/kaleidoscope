import Foundation

enum MinesweeperInteractionMode: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case choose
    case flag

    static let `default`: MinesweeperInteractionMode = .choose

    static func mode(forMouseButton buttonNumber: Int) -> MinesweeperInteractionMode {
        buttonNumber == 1 ? .flag : .choose
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .choose: return "Choose"
        case .flag: return "Flag"
        }
    }

    var systemImage: String {
        switch self {
        case .choose: return "cursorarrow.click"
        case .flag: return "flag.fill"
        }
    }
}
