import Foundation
import Combine

/// One line in the chat transcript (UI-facing).
struct ChatMessage: Identifiable, Equatable {
    enum Kind { case user, assistant, tool, error }
    let id = UUID()
    let kind: Kind
    var text: String
}

/// Drives the agentic loop: send the conversation to Claude, run any file tools
/// it requests against the project, feed the results back, and repeat until the
/// model stops asking for tools. Keeps a UI transcript (`messages`) alongside the
/// raw API history (`history`).
@MainActor
final class AgentSession: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isWorking = false

    private let projects: ProjectStore
    private let settings: CiceroSettings
    private var history: [AnthropicMessage] = []

    /// Hard cap on tool round-trips per user message, so a confused model can't
    /// loop forever (and rack up cost) on one request.
    private let maxTurns = 8

    init(projects: ProjectStore, settings: CiceroSettings) {
        self.projects = projects
        self.settings = settings
    }

    func reset() {
        history.removeAll()
        messages.removeAll()
    }

    func send(_ input: String) async {
        guard !isWorking else { return }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let key = settings.apiKey(), !key.isEmpty else {
            messages.append(ChatMessage(kind: .error,
                                        text: AnthropicError.missingKey.errorDescription ?? "No API key."))
            return
        }

        messages.append(ChatMessage(kind: .user, text: trimmed))
        history.append(.user(trimmed))

        isWorking = true
        defer { isWorking = false }

        let client = AnthropicClient(apiKey: key)
        var turns = 0
        do {
            while turns < maxTurns {
                turns += 1
                let response = try await client.createMessage(
                    model: settings.modelID,
                    effort: settings.effort,
                    system: AgentTools.systemPrompt(projectSummary: projectSummary()),
                    tools: AgentTools.all,
                    messages: history)

                // Record the assistant turn verbatim so tool_use ids line up with
                // the tool_result blocks we send next.
                history.append(AnthropicMessage(role: "assistant", content: response.content))

                let text = response.joinedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    messages.append(ChatMessage(kind: .assistant, text: text))
                }

                guard response.stopReason == "tool_use", !response.toolUses.isEmpty else { break }

                var results: [ContentBlock] = []
                for use in response.toolUses {
                    let outcome = executeTool(name: use.name, input: use.input)
                    messages.append(ChatMessage(kind: .tool, text: outcome.summary))
                    results.append(.toolResult(toolUseID: use.id,
                                               text: outcome.result,
                                               isError: outcome.isError))
                }
                history.append(AnthropicMessage(role: "user", content: results))
            }

            if turns >= maxTurns {
                messages.append(ChatMessage(
                    kind: .error,
                    text: "Paused after \(maxTurns) tool steps to avoid a runaway loop. Say \"continue\" to keep going."))
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            messages.append(ChatMessage(kind: .error, text: message))
        }
    }

    // MARK: Tool execution

    private func executeTool(name: String, input: JSONValue) -> (summary: String, result: String, isError: Bool) {
        switch name {
        case AgentTools.listFiles:
            let paths = projects.allFilePaths()
            return ("Listed files", paths.isEmpty ? "(no files yet)" : paths.joined(separator: "\n"), false)

        case AgentTools.readFile:
            guard let path = input["path"]?.stringValue else {
                return ("read_file: missing path", "Error: 'path' is required.", true)
            }
            do {
                let contents = try projects.read(path)
                return ("Read \(path)", contents, false)
            } catch {
                return ("Read \(path) failed", "Error: \(error.localizedDescription)", true)
            }

        case AgentTools.writeFile:
            guard let path = input["path"]?.stringValue,
                  let contents = input["contents"]?.stringValue else {
                return ("write_file: missing args", "Error: 'path' and 'contents' are required.", true)
            }
            do {
                try projects.write(path, contents: contents)
                return ("Wrote \(path)", "Wrote \(contents.utf8.count) bytes to \(path).", false)
            } catch {
                return ("Write \(path) failed", "Error: \(error.localizedDescription)", true)
            }

        case AgentTools.deleteFile:
            guard let path = input["path"]?.stringValue else {
                return ("delete_file: missing path", "Error: 'path' is required.", true)
            }
            do {
                try projects.delete(path)
                return ("Deleted \(path)", "Deleted \(path).", false)
            } catch {
                return ("Delete \(path) failed", "Error: \(error.localizedDescription)", true)
            }

        default:
            return ("Unknown tool \(name)", "Error: unknown tool '\(name)'.", true)
        }
    }

    private func projectSummary() -> String {
        let paths = projects.allFilePaths()
        return paths.isEmpty ? "(empty project)" : paths.joined(separator: "\n")
    }
}
