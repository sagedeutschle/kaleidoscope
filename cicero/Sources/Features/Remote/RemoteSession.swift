import Foundation

// MARK: - Remote execution abstraction (phase 2)
//
// The on-device agent (AgentSession) is fully self-contained: it edits files in
// the app sandbox. The next slice is "real" vibe coding — driving one of Sage's
// actual dev machines from the phone, the way he does in VS Code on the MacBook.
//
// iOS App Store apps cannot run a shell or a compiler on-device, so the realistic
// architecture is a THIN CLIENT to a real box:
//
//   iPhone (Cicero)  ──SSH / WebSocket relay──▶  archbox / topaz / iMac
//                                                 └─ runs claude / codex / git / build
//
// Two workable transports, both deferred behind this protocol:
//   1. SSH directly (e.g. swift-nio-ssh or Citadel) over the Tailnet.
//   2. A tiny relay agent on the Mac exposing an authenticated WebSocket that
//      streams a PTY — avoids shipping an SSH stack in the app.
//
// Everything above the transport (host config, command model, streamed results,
// and the eventual "let the agent run commands there" tool) is defined here so
// the UI and agent can be built against a stable seam now.

struct RemoteCommand: Equatable {
    let line: String
}

struct RemoteResult: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum RemoteSessionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

protocol RemoteSessionProvider {
    func connect(to host: RemoteHost) async throws
    func run(_ command: RemoteCommand) async throws -> RemoteResult
    func disconnect() async
}

enum RemoteError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Remote execution isn't wired up yet. Add a transport (SSH over your Tailnet, or a relay agent on the Mac) — see RemoteSession.swift."
        }
    }
}

/// Placeholder provider until a transport lands. Lets the UI present the hosts
/// list and a clear "coming soon" state without shipping a broken button.
struct UnconfiguredRemoteProvider: RemoteSessionProvider {
    func connect(to host: RemoteHost) async throws { throw RemoteError.notConfigured }
    func run(_ command: RemoteCommand) async throws -> RemoteResult { throw RemoteError.notConfigured }
    func disconnect() async {}
}
