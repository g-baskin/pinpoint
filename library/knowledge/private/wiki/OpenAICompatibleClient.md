---
type: entity
title: "OpenAICompatibleClient"
entity: OpenAICompatibleClient
kind: struct
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "137-218"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LLMClient]]"
  - "[[ChatMessage]]"
  - "[[ToolSpec]]"
  - "[[ChatResponse]]"
  - "[[JSONValue]]"
used_by:
  - "[[ProviderSettings]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:230 ProviderWireTests.testOpenAIRequestShape"
  - "Tests/PinpointCoreTests/CoreTests.swift:244 ProviderWireTests.testOpenAIParse"
  - "Tests/PinpointCoreTests/ProviderTests.swift:81 OtherProviderTests.testOpenRouterHeadersAndDefaults"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[LLMClient]]"
  - "[[AnthropicClient]]"
---

# OpenAICompatibleClient

## Purpose

The [[LLMClient]] for OpenAI-compatible Chat Completions: the OpenAI API, Gemini, Ollama, LM Studio, OpenRouter and custom endpoints (`Sources/PinpointCore/LLM.swift:137`).

## API

```swift
public struct OpenAICompatibleClient: LLMClient {
    public var apiKey: String
    public var model: String
    public var baseURL: URL
    public var session: URLSession = .shared

    public init(apiKey: String, model: String, baseURL: URL)
    public func makeRequest(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) -> URLRequest
    public static func parse(_ data: Data) throws -> ChatResponse
    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse
}
```

Internal: `static func encode(_ m: ChatMessage) -> [JSONValue]` (`LLM.swift:169-200`).

## Behaviour

- `makeRequest` POSTs to `<baseURL>/chat/completions`, sends a Bearer header only when `apiKey` is non-empty, adds OpenRouter attribution headers when the host is openrouter.ai, and puts the system prompt first (`LLM.swift:147-167`).
- `encode` turns assistant tool uses into `tool_calls` and emits user tool results as separate `role: "tool"` messages right after the assistant turn (`LLM.swift:169-200`).
- `parse` reads `choices[0].message` content and `tool_calls`, parsing string arguments as JSON (`LLM.swift:202-213`).

## Called by

- [[ProviderSettings]] `makeClient(apiKey:)` for every kind except chatgpt, codex and anthropic (`Sources/PinpointCore/LLM.swift:291`).

## Related

[[LLMClient]] · [[AnthropicClient]] · [[ProviderSettings]] · [[ProviderKind]]

## Tested by

- `ProviderWireTests` OpenAI request shape and parse (`Tests/PinpointCoreTests/CoreTests.swift:230-249`); `OtherProviderTests.testOpenRouterHeadersAndDefaults` (`Tests/PinpointCoreTests/ProviderTests.swift:81`).

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 137-218)
