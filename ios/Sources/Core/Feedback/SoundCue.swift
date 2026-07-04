import Foundation

/// Waveform used to synthesize a cue's notes.
enum SoundWaveform {
    case sine
    case triangle
}

/// The tactile flavor a cue maps to.
enum HapticKind {
    case light, medium, heavy, selection, success, warning, error
}

/// Semantic feedback events shared across every game — decoupled from any one
/// game's vocabulary. Pure descriptors only (no audio / UIKit dependency).
enum SoundCue: CaseIterable {
    case move, select, capture, hit, miss, sink, win, lose, invalid
    // Sampled (CC0 files): shared piece sounds for chess/checkers/go, and 2048 tiles.
    case pieceMove, pieceCapture, tileSlide, tileMerge

    /// A bundled CC0 sample name (without extension) when this cue is backed by an
    /// audio file; nil for purely-synthesized cues. `notes` still act as fallback.
    var soundFile: String? {
        switch self {
        case .pieceMove:    return "piece_move"
        case .pieceCapture: return "piece_capture"
        case .tileSlide:    return "tile_slide"
        case .tileMerge:    return "tile_merge"
        default:            return nil
        }
    }

    /// Note frequencies (Hz), played in sequence. A warm pentatonic-ish palette.
    /// For sampled cues these are only a synthesis fallback if the file is missing.
    var notes: [Double] {
        switch self {
        case .move:    return [Note.c5]
        case .select:  return [Note.e5]
        case .capture: return [Note.a3]
        case .hit:     return [Note.d4]
        case .miss:    return [Note.g4]
        case .sink:    return [Note.a4, Note.e4, Note.a3]        // descending
        case .win:     return [Note.c5, Note.e5, Note.g5, Note.c6] // rising arpeggio
        case .lose:    return [Note.g4, Note.e4, Note.c4]        // descending
        case .invalid: return [Note.a3, Note.a3]                 // dull double tick
        case .pieceMove:    return [Note.a3]
        case .pieceCapture: return [Note.a3, Note.e4]
        case .tileSlide:    return [Note.g4]
        case .tileMerge:    return [Note.c5]
        }
    }

    /// Seconds per note; total sound length is `notes.count * noteDuration`.
    var noteDuration: Double {
        switch self {
        case .select:  return 0.04
        case .invalid: return 0.045
        case .move, .miss: return 0.065
        case .sink:    return 0.10
        case .win:     return 0.11
        case .capture, .hit: return 0.13
        case .lose:    return 0.13
        case .pieceMove, .tileSlide, .tileMerge: return 0.06
        case .pieceCapture: return 0.09
        }
    }

    var waveform: SoundWaveform {
        switch self {
        case .select, .miss, .lose, .tileSlide: return .sine
        default: return .triangle
        }
    }

    var haptic: HapticKind {
        switch self {
        case .move, .miss, .tileSlide: return .light
        case .select:      return .selection
        case .capture, .tileMerge: return .medium
        case .hit, .pieceCapture: return .heavy
        case .pieceMove:   return .light
        case .sink:        return .warning
        case .win:         return .success
        case .lose, .invalid: return .error
        }
    }
}

/// Equal-tempered note frequencies used by the cue palette.
private enum Note {
    static let c4 = 261.63, d4 = 293.66, e4 = 329.63, g4 = 392.00, a3 = 220.00
    static let a4 = 440.00, c5 = 523.25, e5 = 659.25, g5 = 783.99, c6 = 1046.50
}
