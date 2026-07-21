# Cicero

**Vibe coding in your pocket.** A SwiftUI iPhone/iPad app that brings the
MacBook-in-VS-Code loop — edit, ask an AI agent, iterate — onto the phone, with
a small arcade of mini-games for the gaps between builds.

Cicero is a **new, standalone app** in the Prismet monorepo. It is deliberately
kept separate from the shipping SpocksClub "Prismet" games app: its own
`project.yml`, its own bundle id (`com.gtrktscrb.cicero`), and Sage's own team
(`YJR3ABV3H4`) — so this experiment never touches the App Store review lane.

> **Status: v0.1 — first slice.** Written to the repo's conventions but built in
> a headless CI container with no Xcode, so the Swift here is **unverified (not
> yet compiled)**. Build it on a Mac (steps below), then iterate. Treat the first
> compile as a shakedown.

---

## What's in this slice

Four tabs:

| Tab | What it does |
|-----|--------------|
| **Code** | Browse and edit files in an on-device project. Syntax-highlighted, code-friendly editor (no autocorrect/smart-quotes), file create/delete, Save. |
| **Agent** | Chat with Claude. It can `list`, `read`, `write`, and `delete` files in the same project — so "add a function and call it" actually edits your files. |
| **Arcade** | Self-contained mini-games (Tic-Tac-Toe vs a minimax bot, Lights Out). |
| **Settings** | Paste your Anthropic API key (stored in the Keychain), pick model + effort, and register remote dev hosts. |

The agent runs a real tool loop: send → the model requests file tools → Cicero
executes them against the sandboxed project → results go back → repeat until it's
done (capped at 8 tool steps per message).

---

## Build & run (on a Mac)

```bash
cd cicero
xcodegen generate          # regenerates Cicero.xcodeproj (gitignored)
open Cicero.xcodeproj
```

- Build into `~/Library/Caches` derived data, per the monorepo build rules
  (`AGENTS.md` §4) — never into an iCloud-synced project path.
- The `DEVELOPMENT_TEAM` in `project.yml` is `YJR3ABV3H4`; change it if you sign
  under a different team.
- No third-party SPM dependencies in this slice — it builds with the SDK alone.

### API key

There is **no committed secret and no `Secrets.swift` to create**. On first run,
open **Settings → paste your `sk-ant-…` key**. It's stored in the iOS Keychain.
Get a key at `console.anthropic.com`.

The agent talks to the Claude **Messages API** over raw HTTPS (Swift has no
official Anthropic SDK). Default model: `claude-opus-4-8`.

---

## Architecture

```
Sources/
  App/        CiceroApp (@main), RootView (tab shell; owns the shared stores)
  Design/     CiceroTheme (dark palette, type ramp, Color+hex)
  Backend/    Keychain, CiceroSettings, JSONValue,
              AnthropicModels (Codable wire types), AnthropicClient (URLSession)
  Features/
    Agent/    AgentTools (file tool schemas), AgentSession (the loop), AgentChatView
    Editor/   SyntaxHighlighter (pure/testable), CodeEditorView (UITextView), CodeScreen
    Files/    ProjectStore (sandboxed workspace + path safety; the agent's tool backend)
    Remote/   RemoteHost, RemoteSession (protocol + placeholder — the phase-2 seam)
    Games/    GamesHubView, TicTacToe (minimax), LightsOut
    Settings/ SettingsView
Tests/        CiceroTests (highlighter, JSON wire format, path safety, game logic)
```

Design choices worth knowing:

- **Non-streaming turns, long timeout.** v1 uses a single request per turn with a
  300s `URLSession` timeout — simple and robust. Token-by-token streaming is a
  clean next step (see roadmap).
- **Thinking intentionally off.** Omitting the `thinking` parameter keeps the
  multi-turn tool loop from having to replay thinking blocks. Enabling adaptive
  thinking (with proper block replay) is a roadmap item.
- **Highlight on load/blur, not per-keystroke.** Avoids UITextView cursor-jump
  bugs; colors refresh when editing ends.

---

## Roadmap → "everything I do on my MacBook"

The on-device agent is real but sandboxed to the app's own files. The headline
goal — do the *actual* vibe coding Sage does on his Mac — needs a machine that
can run a shell, a compiler, and `claude`/`codex`/`git`. iOS can't do that
on-device, so the plan is a **thin client to a real box**:

```
iPhone (Cicero) ──SSH / WebSocket relay──▶ archbox / topaz / iMac (Tailnet)
                                            └─ runs claude / codex / git / builds
```

`Features/Remote/RemoteSession.swift` defines that seam today (host model,
command/result types, provider protocol) behind a placeholder, so the transport
can drop in without reworking the UI. Two candidate transports: SSH directly
(swift-nio-ssh / Citadel over the Tailnet) or a small authenticated relay agent
on the Mac streaming a PTY over WebSocket.

Other next steps: streaming responses, an editor line-number gutter and
find/replace, reuse of Prismet games via `PrismetShared`, syncing the open
editor buffer when the agent edits the same file, and multi-project support.

---

## Coordination

Tracked in `docs/AGENT-COORDINATION.md` under the `cicero` lane. This app touches
**only** `cicero/**` (plus one repo-map row in `AGENTS.md`); it does not modify
`ios/`, `macos/`, `oracle/`, `shared/`, or any Prismet file.
