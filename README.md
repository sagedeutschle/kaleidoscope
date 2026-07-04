# Kaleidoscope

A cross-platform games app — a "fidget shell" of ~18 games plus live "lenses" (an Oracle
of daily decrees, a live U.S. Debt Clock) — shipping on **iOS** and **macOS**, backed by a
small Python decree service.

This is the shared home for all Kaleidoscope work. Sage and his dad Ben both develop here,
each with their own AI agents.

## Layout

```
kaleidoscope/
├── ios/        Shipping iOS app        (SwiftUI · iOS 17 · XcodeGen + SPM)
├── macos/      Desktop app             (SwiftUI · XcodeGen)  — parity with iOS is a release gate
├── shared/     KaleidoscopeShared      (local Swift package both apps depend on)
├── oracle/     Wizard King's Decree    (Python · daily job → public gist both apps read)
├── docs/       Coordination ledger · handoff · release gates
├── AGENTS.md   ← the contract every agent reads first
├── CLAUDE.md   ← Claude Code entry point (points to AGENTS.md)
└── scripts/    sync helpers (git through GitHub)
```

## Getting started (new collaborator or agent)

```bash
git clone git@github.com:sagedeutschle/kaleidoscope.git
cd kaleidoscope

# iOS
cd ios && xcodegen generate      # .xcodeproj is generated, not committed
open Kaleidoscope.xcodeproj      # then build to a simulator

# macOS
cd ../macos && xcodegen generate && ./scripts/deploy-mac.sh
```

You'll need **Xcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen)** (`brew install xcodegen`).
The iOS app needs `ios/Sources/Backend/Secrets.swift` (Supabase config) — copy
`ios/docs/Secrets.example.swift` and get real values from Sage. It's gitignored so keys
never land in git.

## How we work together

- **Sync is git.** `git pull --rebase` before you work, `git push` after. The NAS shared
  folder and both desktops are clones that meet at GitHub. See `scripts/sync.sh`.
- **Build locally, never on the NAS mount** (SMB + Xcode = signing failures).
- **Coordinate in `docs/AGENT-COORDINATION.md`** — claim your lane, log your changes.

Full rules for humans and agents: **[`AGENTS.md`](AGENTS.md)**.
Current state: **[`docs/HANDOFF.md`](docs/HANDOFF.md)** · Open blockers: **[`docs/RELEASE-GATES.md`](docs/RELEASE-GATES.md)**.
