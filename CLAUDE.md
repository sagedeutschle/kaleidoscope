# CLAUDE.md

You are working in the **Prismet monorepo** (iOS + macOS games app + Oracle backend),
collaboratively developed by Sage and his dad Ben, each with their own agents.

**→ Read [`AGENTS.md`](AGENTS.md) first.** It is the shared contract for every agent
(Claude, Fable, Codex) and covers: the repo map, the git-through-GitHub sync model, the
build rules (build locally not on the NAS mount; xcodegen owns `.xcodeproj`/`Info.plist`;
`SWIFT_COMPILATION_MODE=incremental` for archives; iOS device deploys go through codex),
and the PRISM coordination protocol.

Fast rules, so you don't clobber a collaborator:
1. `git pull --rebase` before you start; read the latest `docs/AGENT-COORDINATION.md` entries.
2. Claim your lane + files in that ledger; log what you changed when done.
3. Commit small and often; `git push` when a unit is complete.
4. Never commit secrets — `ios/Sources/Backend/Secrets.swift`, `*.p8`, etc. are gitignored.
5. Build on this local clone into `~/Library/Caches/…` derived data — never on the NAS mount.

Orientation docs: `docs/HANDOFF.md` (current state), `docs/RELEASE-GATES.md` (open blockers).
