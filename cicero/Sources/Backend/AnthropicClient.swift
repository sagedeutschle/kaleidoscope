import Foundation

enum AnthropicError: LocalizedError {
    case missingKey
    case http(status: Int, message: String)
    case refusal(String)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No Anthropic API key set. Add one in Settings."
        case .http(let status, let message):
            return "API error \(status): \(message)"
        case .refusal(let why):
            return "The model declined this request. \(why)"
        case .transport(let m):
            return "Network error: \(m)"
        case .decoding(let m):
            return "Couldn't read the response: \(m)"
        }
    }
}

/// Thin async client over the Claude Messages API (`POST /v1/messages`).
///
/// Swift has no official Anthropic SDK, so this speaks the raw HTTP contract
/// directly. v1 uses non-streaming turns with a long request timeout, which is
/// simple and robust; token-by-token streaming is a documented next step
/// (`cicero/README.md`). Thinking is intentionally left off for now so the
/// multi-turn tool loop never has to replay thinking blocks.
struct AnthropicClient {
    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = AnthropicClient.makeSession()) {
        self.apiKey = apiKey
        self.session = session
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        // Non-streaming completions can run well past the 60s default.
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func createMessage(
        model: String,
        maxTokens: Int = 8192,
        effort: String?,
        system: String?,
        tools: [AnthropicTool]?,
        messages: [AnthropicMessage]
    ) async throws -> MessagesResponse {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = MessagesRequest(
            model: model,
            maxTokens: maxTokens,
            system: system,
            messages: messages,
            tools: tools,
            outputConfig: effort.map { MessagesRequest.OutputConfig(effort: $0) })

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AnthropicError.decoding("encode request: \(error.localizedDescription)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnthropicError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.transport("no HTTP response")
        }
        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error?.message
                ?? String(data: data, encoding: .utf8)
                ?? "unknown error"
            throw AnthropicError.http(status: http.statusCode, message: message)
        }

        let decoded: MessagesResponse
        do {
            decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        } catch {
            throw AnthropicError.decoding(error.localizedDescription)
        }
        if decoded.stopReason == "refusal" {
            throw AnthropicError.refusal(decoded.stopDetails?.explanation ?? "")
        }
        return decoded
    }
}
