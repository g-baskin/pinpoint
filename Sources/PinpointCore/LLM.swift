import Foundation

// MARK: - Provider-neutral chat types

public enum ChatRole: String, Sendable { case user, assistant }

public enum ChatPart: Equatable, Sendable {
    case text(String)
    case image(png: Data)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(id: String, content: String, isError: Bool)
}

public struct ChatMessage: Equatable, Sendable {
    public var role: ChatRole
    public var parts: [ChatPart]
    public init(role: ChatRole, parts: [ChatPart]) { self.role = role; self.parts = parts }
    public static func user(_ text: String, images: [Data] = []) -> ChatMessage {
        ChatMessage(role: .user, parts: images.map { .image(png: $0) } + [.text(text)])
    }
}

public struct ToolSpec: Sendable {
    public var name: String
    public var description: String
    public var parameters: JSONValue
    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name; self.description = description; self.parameters = parameters
    }
}

public struct ToolCall: Equatable, Sendable { public var id: String; public var name: String; public var input: JSONValue }

public struct ChatResponse: Sendable {
    public var parts: [ChatPart]
    public var stopReason: String?
    public var text: String {
        parts.compactMap { if case .text(let t) = $0 { return t }; return nil }.joined(separator: "\n")
    }
    public var toolCalls: [ToolCall] {
        parts.compactMap { if case .toolUse(let id, let n, let i) = $0 { return ToolCall(id: id, name: n, input: i) }; return nil }
    }
}

public struct LLMError: LocalizedError, Sendable {
    public var message: String
    public init(_ m: String) { message = m }
    public var errorDescription: String? { message }
}

public protocol LLMClient: Sendable {
    func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse
}

extension LLMClient {
    /// One-shot question with optional images; returns plain text.
    public func ask(system: String, prompt: String, images: [Data] = [], maxTokens: Int = 2048) async throws -> String {
        try await send(system: system, messages: [.user(prompt, images: images)], tools: [], maxTokens: maxTokens).text
    }
}

func perform(_ req: URLRequest, session: URLSession) async throws -> Data {
    let (data, resp) = try await session.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(code) else {
        var msg = String(decoding: data.prefix(600), as: UTF8.self)
        if let j = try? JSONValue.parse(data) {
            msg = j["error"]?["message"]?.stringValue ?? j["error"]?.stringValue ?? j["message"]?.stringValue ?? msg
        }
        throw LLMError("HTTP \(code): \(msg)")
    }
    return data
}

// MARK: - Anthropic Messages API

public struct AnthropicClient: LLMClient {
    public var apiKey: String
    public var model: String
    public var baseURL: URL
    public var session: URLSession = .shared

    public init(apiKey: String, model: String, baseURL: URL) { self.apiKey = apiKey; self.model = model; self.baseURL = baseURL }

    public func makeRequest(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        var body: [String: JSONValue] = [
            "model": .string(model), "max_tokens": .number(Double(maxTokens)),
            "messages": .array(messages.map(Self.encode)),
        ]
        if !system.isEmpty { body["system"] = .string(system) }
        if !tools.isEmpty {
            body["tools"] = .array(tools.map { ["name": .string($0.name), "description": .string($0.description), "input_schema": $0.parameters] })
        }
        req.httpBody = JSONValue.object(body).data()
        return req
    }

    static func encode(_ m: ChatMessage) -> JSONValue {
        let content: [JSONValue] = m.parts.map { p in
            switch p {
            case .text(let t): return ["type": "text", "text": .string(t)]
            case .image(let png):
                return ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": .string(png.base64EncodedString())]]
            case .toolUse(let id, let name, let input):
                return ["type": "tool_use", "id": .string(id), "name": .string(name), "input": input]
            case .toolResult(let id, let content, let isError):
                return ["type": "tool_result", "tool_use_id": .string(id), "content": .string(content), "is_error": .bool(isError)]
            }
        }
        return ["role": .string(m.role.rawValue), "content": .array(content)]
    }

    public static func parse(_ data: Data) throws -> ChatResponse {
        let j = try JSONValue.parse(data)
        guard let blocks = j["content"]?.arrayValue else { throw LLMError("Unexpected response: \(j.jsonString.prefix(300))") }
        let parts: [ChatPart] = blocks.compactMap { b in
            switch b["type"]?.stringValue {
            case "text": return .text(b["text"]?.stringValue ?? "")
            case "tool_use": return .toolUse(id: b["id"]?.stringValue ?? UUID().uuidString, name: b["name"]?.stringValue ?? "", input: b["input"] ?? [:])
            default: return nil
            }
        }
        return ChatResponse(parts: parts, stopReason: j["stop_reason"]?.stringValue)
    }

    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse {
        try Self.parse(try await perform(makeRequest(system: system, messages: messages, tools: tools, maxTokens: maxTokens), session: session))
    }
}

// MARK: - OpenAI-compatible Chat Completions (OpenAI, Gemini, Ollama, LM Studio, OpenRouter, ...)

public struct OpenAICompatibleClient: LLMClient {
    public var apiKey: String
    public var model: String
    public var baseURL: URL
    public var session: URLSession = .shared

    public init(apiKey: String, model: String, baseURL: URL) { self.apiKey = apiKey; self.model = model; self.baseURL = baseURL }

    public func makeRequest(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization") }
        if baseURL.host?.contains("openrouter.ai") == true {
            // Optional OpenRouter attribution headers.
            req.setValue("https://github.com/g-baskin/pinpoint", forHTTPHeaderField: "HTTP-Referer")
            req.setValue("Pinpoint", forHTTPHeaderField: "X-Title")
        }
        var msgs: [JSONValue] = []
        if !system.isEmpty { msgs.append(["role": "system", "content": .string(system)]) }
        for m in messages { msgs.append(contentsOf: Self.encode(m)) }
        var body: [String: JSONValue] = ["model": .string(model), "messages": .array(msgs), "max_tokens": .number(Double(maxTokens))]
        if !tools.isEmpty {
            body["tools"] = .array(tools.map { ["type": "function", "function": ["name": .string($0.name), "description": .string($0.description), "parameters": $0.parameters]] })
        }
        req.httpBody = JSONValue.object(body).data()
        return req
    }

    static func encode(_ m: ChatMessage) -> [JSONValue] {
        var out: [JSONValue] = []
        switch m.role {
        case .assistant:
            let text = m.parts.compactMap { if case .text(let t) = $0 { return t }; return nil }.joined(separator: "\n")
            let calls: [JSONValue] = m.parts.compactMap {
                if case .toolUse(let id, let name, let input) = $0 {
                    return ["id": .string(id), "type": "function", "function": ["name": .string(name), "arguments": .string(input.jsonString)]]
                }
                return nil
            }
            var msg: [String: JSONValue] = ["role": "assistant", "content": text.isEmpty ? .null : .string(text)]
            if !calls.isEmpty { msg["tool_calls"] = .array(calls) }
            out.append(.object(msg))
        case .user:
            // Tool results must directly follow the assistant turn, as role "tool" messages.
            for p in m.parts {
                if case .toolResult(let id, let content, _) = p {
                    out.append(["role": "tool", "tool_call_id": .string(id), "content": .string(content)])
                }
            }
            let content: [JSONValue] = m.parts.compactMap { p in
                switch p {
                case .text(let t): return ["type": "text", "text": .string(t)]
                case .image(let png): return ["type": "image_url", "image_url": ["url": .string("data:image/png;base64," + png.base64EncodedString())]]
                default: return nil
                }
            }
            if !content.isEmpty { out.append(["role": "user", "content": .array(content)]) }
        }
        return out
    }

    public static func parse(_ data: Data) throws -> ChatResponse {
        let j = try JSONValue.parse(data)
        guard let msg = j["choices"]?[0]?["message"] else { throw LLMError("Unexpected response: \(j.jsonString.prefix(300))") }
        var parts: [ChatPart] = []
        if let t = msg["content"]?.stringValue, !t.isEmpty { parts.append(.text(t)) }
        for c in msg["tool_calls"]?.arrayValue ?? [] {
            let argStr = c["function"]?["arguments"]?.stringValue ?? "{}"
            let input = (try? JSONValue.parse(argStr)) ?? c["function"]?["arguments"] ?? [:]
            parts.append(.toolUse(id: c["id"]?.stringValue ?? UUID().uuidString, name: c["function"]?["name"]?.stringValue ?? "", input: input))
        }
        return ChatResponse(parts: parts, stopReason: j["choices"]?[0]?["finish_reason"]?.stringValue)
    }

    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse {
        try Self.parse(try await perform(makeRequest(system: system, messages: messages, tools: tools, maxTokens: maxTokens), session: session))
    }
}

// MARK: - Provider catalogue

public enum ProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case chatgpt, codex, anthropic, openai, openrouter, gemini, ollama, custom
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chatgpt: return "ChatGPT (sign in with your plan)"
        case .codex: return "ChatGPT via Codex CLI"
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI API"
        case .openrouter: return "OpenRouter"
        case .gemini: return "Google Gemini"
        case .ollama: return "Ollama (local, offline)"
        case .custom: return "Custom (OpenAI-compatible)"
        }
    }
    public var defaultBaseURL: String {
        switch self {
        case .chatgpt: return "https://api.openai.com/v1"
        case .codex: return ""   // path to the codex executable; empty = auto-detect
        case .anthropic: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return "http://localhost:1234/v1"
        }
    }
    /// Starting suggestions only — use "Fetch models" in Settings for the current list.
    public var defaultModel: String {
        switch self {
        case .chatgpt: return "auto"   // ModelPicker chooses from the plan's model list
        case .codex: return ""   // empty = your Codex default model
        case .anthropic: return "claude-sonnet-4-5"
        case .openai: return "gpt-4.1"
        case .openrouter: return "openai/gpt-4.1-mini"
        case .gemini: return "gemini-2.5-flash"
        case .ollama: return "qwen2.5vl"
        case .custom: return ""
        }
    }
    public var needsKey: Bool { [.anthropic, .openai, .openrouter, .gemini].contains(self) }
}

public struct ProviderSettings: Codable, Equatable, Sendable {
    public var kind: ProviderKind
    public var model: String
    public var baseURL: String
    public init(kind: ProviderKind, model: String? = nil, baseURL: String? = nil) {
        self.kind = kind; self.model = model ?? kind.defaultModel; self.baseURL = baseURL ?? kind.defaultBaseURL
    }

    public func makeClient(apiKey: String) throws -> LLMClient {
        if kind == .chatgpt {
            guard ChatGPTAccount.shared.isSignedIn else { throw LLMError("Click “Sign in with ChatGPT” in Pinpoint Settings first.") }
            let m = model.trimmingCharacters(in: .whitespaces)
            return ChatGPTPlanClient(model: ModelPicker.isAuto(m) ? ModelPicker.auto : m)
        }
        if kind == .codex {
            guard let exe = CodexClient.locate(baseURL) else {
                throw LLMError("Couldn't find the Codex CLI. Install it (npm i -g @openai/codex), run `codex login` and choose “Sign in with ChatGPT”, or set its path in Settings.")
            }
            return CodexClient(executable: exe, model: model.trimmingCharacters(in: .whitespaces))
        }
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)) else { throw LLMError("Invalid base URL") }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { throw LLMError("Choose a model in Settings") }
        if kind.needsKey && apiKey.isEmpty { throw LLMError("Add your \(kind.displayName) API key in Settings") }
        switch kind {
        case .anthropic: return AnthropicClient(apiKey: apiKey, model: model, baseURL: url)
        default: return OpenAICompatibleClient(apiKey: apiKey, model: model, baseURL: url)
        }
    }

    public func listModels(apiKey: String, session: URLSession = .shared) async throws -> [String] {
        if kind == .chatgpt { return try await ChatGPTAccount.shared.models() }
        if kind == .codex { return CodexClient.suggestedModels }
        guard let base = URL(string: baseURL) else { throw LLMError("Invalid base URL") }
        var req: URLRequest
        if kind == .anthropic {
            req = URLRequest(url: base.appendingPathComponent("v1/models"))
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            req = URLRequest(url: base.appendingPathComponent("models"))
            if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization") }
        }
        req.timeoutInterval = 20
        let j = try JSONValue.parse(try await perform(req, session: session))
        let ids = (j["data"]?.arrayValue ?? j["models"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue ?? $0["name"]?.stringValue }
        return ids.map { $0.hasPrefix("models/") ? String($0.dropFirst(7)) : $0 }.sorted()
    }
}
