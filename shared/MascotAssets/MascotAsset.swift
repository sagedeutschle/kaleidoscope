// Mascot asset keys for Mookie's Arcade. Authored in Phase 1; wired into a build
// target in Phase 3 (companion). Keep in sync with manifest.json.
public enum MascotCharacter: String, CaseIterable { case mookie, reynard }

public enum MascotPose: String, CaseIterable {
    case idle, wave, happy, thinking, sad, sleeping, pointing, playing
    case dealing            // reynard only
    case slyWink = "sly-wink" // reynard only
}

public struct MascotAsset {
    public let character: MascotCharacter
    public let pose: MascotPose
    /// Relative path under shared/MascotAssets, e.g. "mookie/happy@2x.png"
    public func assetPath(scale: String = "2x") -> String {
        "\(character.rawValue)/\(pose.rawValue)@\(scale).png"
    }
}
