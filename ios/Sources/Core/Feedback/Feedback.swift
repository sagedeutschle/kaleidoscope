import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Storage keys + reads for the two user toggles. Unset reads as ON.
enum FeedbackSettings {
    static let soundKey = "app.soundEnabled"
    static let hapticsKey = "app.hapticsEnabled"

    static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
    }
    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
}

/// Pure gate: given the two user settings, decides which channels fire. Isolated
/// so the on/off logic is testable without audio or haptic hardware.
struct FeedbackDecision {
    let playSound: Bool
    let playHaptic: Bool

    init(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.playSound = soundEnabled
        self.playHaptic = hapticsEnabled
    }
}

/// Central fan-out: reads the settings gate, then drives sound + haptics.
@MainActor
enum FeedbackCoordinator {
    static func prewarm() {
        SoundEngine.shared.prewarm()
    }

    static func fire(_ cue: SoundCue) {
        let decision = FeedbackDecision(soundEnabled: FeedbackSettings.soundEnabled,
                                        hapticsEnabled: FeedbackSettings.hapticsEnabled)
        if decision.playSound { SoundEngine.shared.play(cue) }
        if decision.playHaptic { Haptics.fire(cue.haptic) }
    }
}

/// Maps a cue's `HapticKind` to the platform generators. No-op off-device.
enum Haptics {
    static func fire(_ kind: HapticKind) {
        #if canImport(UIKit)
        switch kind {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }
}

extension View {
    /// Fire a cue's sound + haptic whenever `trigger` changes. Replaces scattered
    /// `.sensoryFeedback`, so both channels share the single settings gate.
    func gameFeedback<T: Equatable>(_ cue: SoundCue, trigger: T) -> some View {
        onChange(of: trigger) { _, _ in FeedbackCoordinator.fire(cue) }
    }
}
