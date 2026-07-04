import Foundation

/// A rebindable Brick Bench editing action.
enum BrickControlAction: String, CaseIterable, Identifiable, Hashable {
    case placeBrick, undo, redo
    case moveLeft, moveRight, moveForward, moveBack
    case rotateCW, rotateCCW
    case raise, lower

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .placeBrick:  return "Place brick"
        case .undo:        return "Undo"
        case .redo:        return "Redo"
        case .moveLeft:    return "Move left"
        case .moveRight:   return "Move right"
        case .moveForward: return "Move forward"
        case .moveBack:    return "Move back"
        case .rotateCW:    return "Rotate clockwise"
        case .rotateCCW:   return "Rotate counter-clockwise"
        case .raise:       return "Raise a level"
        case .lower:       return "Lower a level"
        }
    }
}

/// What an action does to the selected brick (with behavior toggles baked in).
enum ControlEffect: Equatable {
    case placeBrick
    case undo
    case redo
    case move(dx: Int, dy: Int, dLayer: Int)
    case rotate(quarters: Int)
}

/// User-customizable key bindings + behavior toggles for Brick Bench, with
/// sensible defaults matching what we build with.
struct BrickControls: Equatable, Hashable, Codable {
    var keyCodes: [BrickControlAction: Int]
    var invertForwardBack: Bool
    var invertVertical: Bool

    private enum CodingKeys: String, CodingKey {
        case keyBindings
        case invertForwardBack
        case invertVertical
    }

    private struct BindingEntry: Codable, Hashable {
        var action: String
        var keyCode: Int
    }

    init(keyCodes: [BrickControlAction: Int], invertForwardBack: Bool, invertVertical: Bool) {
        self.keyCodes = keyCodes
        self.invertForwardBack = invertForwardBack
        self.invertVertical = invertVertical
    }

    static let defaults = BrickControls(
        keyCodes: [
            .placeBrick: 14,  // E
            .undo: 53,        // Esc
            .redo: 121,       // Page Down
            .moveLeft: 123,    // ←
            .moveRight: 124,   // →
            .moveForward: 126, // ↑
            .moveBack: 125,    // ↓
            .rotateCCW: 12,    // Q
            .rotateCW: 15,     // R
            .raise: 49,        // Space
            .lower: 48         // Tab — lower a level
        ],
        invertForwardBack: false,
        invertVertical: false
    )

    /// The action bound to a macOS key code, if any.
    func action(for keyCode: Int) -> BrickControlAction? {
        keyCodes.first(where: { $0.value == keyCode })?.key
    }

    /// The world effect of an action, applying the invert toggles.
    func effect(of action: BrickControlAction) -> ControlEffect {
        switch action {
        case .placeBrick:  return .placeBrick
        case .undo:        return .undo
        case .redo:        return .redo
        case .moveLeft:    return .move(dx: -1, dy: 0, dLayer: 0)
        case .moveRight:   return .move(dx: 1, dy: 0, dLayer: 0)
        case .moveForward: return .move(dx: 0, dy: invertForwardBack ? 1 : -1, dLayer: 0)
        case .moveBack:    return .move(dx: 0, dy: invertForwardBack ? -1 : 1, dLayer: 0)
        case .raise:       return .move(dx: 0, dy: 0, dLayer: invertVertical ? -1 : 1)
        case .lower:       return .move(dx: 0, dy: 0, dLayer: invertVertical ? 1 : -1)
        case .rotateCW:    return .rotate(quarters: 1)
        case .rotateCCW:   return .rotate(quarters: -1)
        }
    }

    /// Bind `action` to `keyCode`, removing that code from any other action so a
    /// key never triggers two things at once.
    mutating func bind(_ action: BrickControlAction, to keyCode: Int) {
        for (other, code) in keyCodes where code == keyCode { keyCodes[other] = nil }
        keyCodes[action] = keyCode
    }

    /// A friendly label for a macOS key code (for the settings UI).
    static func keyName(forKeyCode code: Int) -> String {
        switch code {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 49:  return "Space"
        case 48:  return "Tab"
        case 36:  return "Return"
        case 53:  return "Esc"
        case 116: return "Page Up"
        case 121: return "Page Down"
        case 51:  return "Delete"
        default:
            if let letter = Self.letterKeyCodes[code] { return letter }
            return "Key \(code)"
        }
    }

    private static let letterKeyCodes: [Int: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z"
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([BindingEntry].self, forKey: .keyBindings)
        keyCodes = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            guard let action = BrickControlAction(rawValue: entry.action) else { return nil }
            return (action, entry.keyCode)
        })
        invertForwardBack = try container.decode(Bool.self, forKey: .invertForwardBack)
        invertVertical = try container.decode(Bool.self, forKey: .invertVertical)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let entries = keyCodes
            .map { BindingEntry(action: $0.key.rawValue, keyCode: $0.value) }
            .sorted { $0.action < $1.action }
        try container.encode(entries, forKey: .keyBindings)
        try container.encode(invertForwardBack, forKey: .invertForwardBack)
        try container.encode(invertVertical, forKey: .invertVertical)
    }
}
