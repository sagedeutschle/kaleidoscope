import Foundation

// MARK: - Model / effort choices

struct AgentModel: Identifiable, Hashable {
    let id: String
    let name: String

    static let opus48 = AgentModel(id: "claude-opus-4-8", name: "Opus 4.8 · deepest")
    static let sonnet5 = AgentModel(id: "claude-sonnet-5", name: "Sonnet 5 · balanced")
    static let haiku45 = AgentModel(id: "claude-haiku-4-5", name: "Haiku 4.5 · fastest")

    static let all: [AgentModel] = [opus48, sonnet5, haiku45]
    static let `default` = opus48

    static func named(_ id: String) -> AgentModel {
        all.first { $0.id == id } ?? .default
    }
}

enum AgentEffort: String, CaseIterable, Identifiable {
    case low, medium, high, xhigh, max
    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .xhigh: return "Extra high"
        case .max: return "Max"
        }
    }
}

// MARK: - Content blocks (shared by request messages and decoded responses)

enum ContentBlock: Codable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseID: String, text: String, isError: Bool)

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
        case toolUseID = "tool_use_id"
        case content
        case isError = "is_error"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try c.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try c.decode(String.self, forKey: .id),
                name: try c.decode(String.self, forKey: .name),
                input: try c.decodeIfPresent(JSONValue.self, forKey: .input) ?? .object([:]))
        case "tool_result":
            let text = (try? c.decode(String.self, forKey: .content)) ?? ""
            self = .toolResult(
                toolUseID: try c.decode(String.self, forKey: .toolUseID),
                text: text,
                isError: (try? c.decode(Bool.self, forKey: .isError)) ?? false)
        default:
            // Unknown/thinking/etc. — represent as empty text so history stays valid.
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode("text", forKey: .type)
            try c.encode(s, forKey: .text)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(input, forKey: .input)
        case .toolResult(let toolUseID, let text, let isError):
            try c.encode("tool_result", forKey: .type)
            try c.encode(toolUseID, forKey: .toolUseID)
            try c.encode(text, forKey: .content)
            try c.encode(isError, forKey: .isError)
        }
    }
}

struct AnthropicMessage: Codable, Equatable {
    let role: String       // "user" | "assistant"
    let content: [ContentBlock]

    static func user(_ text: String) -> AnthropicMessage {
        AnthropicMessage(role: "user", content: [.text(text)])
    }
}

// MARK: - Tools

struct AnthropicTool: Encodable {
    let name: String
    let description: String
    let inputSchema: JSONValue

    private enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

// MARK: - Request

struct MessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]?
    let outputConfig: OutputConfig?

    struct OutputConfig: Encodable {
        let effort: String
    }

    private enum CodingKeys: String, CodingKey {
        case model, system, messages, tools
        case maxTokens = "max_tokens"
        case outputConfig = "output_config"
    }
}

// MARK: - Response

struct MessagesResponse: Decodable {
    let id: String?
    let model: String?
    let role: String?
    let content: [ContentBlock]
    let stopReason: String?
    let stopDetails: StopDetails?
    let usage: Usage?

    struct StopDetails: Decodable {
        let type: String?
        let category: String?
        let explanation: String?
    }

    struct Usage: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, model, role, content, usage
        case stopReason = "stop_reason"
        case stopDetails = "stop_details"
    }

    /// Concatenated text of all `text` blocks in the response.
    var joinedText: String {
        content.compactMap { if case .text(let s) = $0 { return s } else { return nil } }
            .joined()
    }

    var toolUses: [(id: String, name: String, input: JSONValue)] {
        content.compactMap {
            if case .toolUse(let id, let name, let input) = $0 { return (id, name, input) }
            return nil
        }
    }
}

// MARK: - Error envelope

struct APIErrorEnvelope: Decodable {
    struct Body: Decodable { let type: String?; let message: String? }
    let error: Body?
}
