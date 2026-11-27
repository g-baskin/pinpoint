---
type: entity
title: "AnthropicClient"
entity: AnthropicClient
kind: struct
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "75-135"
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
  - "Tests/PinpointCoreTests/CoreTests.swift:211 ProviderWireTests.testAnthropicRequestShape"
  - "Tests/PinpointCoreTests/CoreTests.swift:223 ProviderWireTests.testAnthropicParse"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[LLMClient]]"
  - "[[OpenAICompatibleClient]]"
---

# AnthropicClient

## Purpose

The [[LLMClient]] for the Anthropic (Claude) **provider**, using the Messages API.

## API

```swift
public struct AnthropicClient: LLMClient {
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

Internal: `static func encode(_ m: ChatMessage) -> JSONValue` (`Sources/PinpointCore/LLM.swift:104-117`).

## Behaviour

- `makeRequest` POSTs to `<baseURL>/v1/messages` with `x-api-key` and `anthropic-version: 2023-06-01`, 180 s timeout; tools become `input_schema` entries (`LLM.swift:85-102`).
- `encode` maps parts to `text`, base64 `image`, `tool_use` and `tool_result` blocks (`LLM.swift:104-117`).
- `parse` reads `content` blocks and `stop_reason` (`LLM.swift:119-130`).

## Called by

- [[ProviderSettings]] `makeClient(apiKey:)` for `.anthropic` (`Sources/PinpointCore/LLM.swift:290`).

## Related

[[LLMClient]] · [[OpenAICompatibleClient]] · [[ProviderSettings]] · [[ProviderKind]]

## Tested by

- `ProviderWireTests` Anthropic request shape and parse (`Tests/PinpointCoreTests/CoreTests.swift:211-228`).

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 75-135)
