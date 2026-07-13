import Foundation

public enum FieldDeckCatalog {
    /// Snapshot of verified local project state captured July 13, 2026 at 3:00 PM EDT.
    public static let july13 = FieldDeckSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_783_969_200),
        projects: [
            ProjectPulse(
                id: .prismet,
                title: "Prismet",
                state: .active,
                headline: "Catan playable; Watch lane green",
                detail: "The active Catan research branch is playable. Before Watch work, the full iPhone suite passed 315 of 315 tests. macOS Catan and the 1.2 store push remain in Claude/Fable's separate lane.",
                nextAction: "Keep Watch work isolated; let the Catan release lane merge on its own gate.",
                symbol: "circle.hexagongrid.fill",
                accentHex: "F4C95D"
            ),
            ProjectPulse(
                id: .longNow,
                title: "The Long Now",
                state: .active,
                headline: "All four strategy games can spectate",
                detail: "Ambient spectate is committed for Catan, Poker, Chess, and Reversi with the recorded 1589 of 1589 suite. Wizard Tokens, guest economy, Rune Slots, and Cicero are active uncommitted lanes today.",
                nextAction: "Treat today's economy and forum work as in flight until its owners commit it.",
                symbol: "castle.fill",
                accentHex: "A78BFA"
            ),
            ProjectPulse(
                id: .allhands,
                title: "Allhands",
                state: .ready,
                headline: "Opus Ultracode panel verified",
                detail: "The always-visible panel is hardened, pinned to Opus at xhigh effort, authenticated-smoke verified, resumable, and cleans up its child process on exit.",
                nextAction: "Use bare allhands when back at the laptop; no activation key is required.",
                symbol: "person.3.sequence.fill",
                accentHex: "60A5FA"
            ),
            ProjectPulse(
                id: .prismCode,
                title: "PrismCode",
                state: .queued,
                headline: "Quick Open and search landed locally",
                detail: "Quick Open and ripgrep-backed workspace search are merged in the local lane. The repo is ahead of its remote and still carries setup files in the working tree.",
                nextAction: "Run the GUI acceptance and packaging pass before calling the desktop app shipped.",
                symbol: "chevron.left.forwardslash.chevron.right",
                accentHex: "22D3EE"
            ),
            ProjectPulse(
                id: .protonOutlook,
                title: "Proton Outlook",
                state: .ready,
                headline: "VS Code opens the shared command helm",
                detail: "The live mod now folds its VS Code tab into the shared command helm while preserving account/session boundaries. The repo is clean on main.",
                nextAction: "Packaging and tab tear-off remain deliberate later architecture work.",
                symbol: "envelope.badge.shield.half.filled",
                accentHex: "C084FC"
            ),
            ProjectPulse(
                id: .minecraftMesh,
                title: "Minecraft Mesh",
                state: .guarded,
                headline: "Routing lane preserved",
                detail: "Player-facing routing and the control plane remain separate operational concerns. The standing iMac sleep boundary is still part of the topology.",
                nextAction: "Verify live topology before changing addresses, whitelist, or host sleep state.",
                symbol: "network",
                accentHex: "34D399"
            ),
            ProjectPulse(
                id: .mediaNAS,
                title: "Media / NAS",
                state: .guarded,
                headline: "Stage first; one writer at a time",
                detail: "Plex, Audiobookshelf, and media reorganization work continues to use live destination discovery, staging-first moves, and one-writer-at-a-time protection.",
                nextAction: "Do not delete or bulk-sort from the field; inspect live targets first.",
                symbol: "externaldrive.fill.badge.checkmark",
                accentHex: "FB923C"
            ),
            ProjectPulse(
                id: .macWorkflow,
                title: "Mac / iMac Workflow",
                state: .ready,
                headline: "Laptop stays home; field deck travels",
                detail: "Remote workflow restoration remains non-destructive. This Watch build is designed to work without moving, waking, or reformatting the laptop.",
                nextAction: "Use the phone and Watch today; leave machine changes for a verified live session.",
                symbol: "laptopcomputer.and.iphone",
                accentHex: "94A3B8"
            ),
        ]
    )
}
