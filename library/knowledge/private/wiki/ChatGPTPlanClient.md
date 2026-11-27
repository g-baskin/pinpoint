---
type: entity
title: "ChatGPTPlanClient"
entity: ChatGPTPlanClient
kind: struct
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/ChatGPTPlan.swift"
lines: "346-490"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LLMClient]]"
  - "[[ChatGPTAccount]]"
  - "[[ChatGPTOAuth]]"
  - "[[ModelPicker]]"
  - "[[ChatMessage]]"
  - "[[ToolSpec]]"
  - "[[ChatResponse]]"
  - "[[JSONValue]]"
  - "[[LLMError]]"
used_by:
  - "[[ProviderSettings]]"
  - "[[AppSettings]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:41 ChatGPTPlanTests.testResponsesBodyShape"
  - "Tests/PinpointCoreTests/ProviderTests.swift:63 ChatGPTPlanTests.testCollectStreamEvents"
  - "Tests/PinpointCoreTests/ProviderTests.swift:75 ChatGPTPlanTests.testCollectThrowsOnFailure"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[LLMClient]]"
  - "[[ChatGPTAccount]]"
  - "[[ModelPicker]]"
---

# ChatGPTPlanClient

## Purpose

The [[LLMClient]] for the "ChatGPT (sign in with your plan)" **provider**: talks to the OpenAI Responses API with the ChatGPT-plan access token, streaming, with tools in a namespace (`Sources/PinpointCore/ChatGPTPlan.swift:346`).

## API

```swift
public struct ChatGPTPlanClient: LLMClient {
    public var model: String
    public var account: ChatGPTAccount
    public static let toolNamespace = "pinpoint"

    public init(model: String, account: ChatGPTAccount = .shared)
    public static func makeBody(model: String, system: String, messages: [ChatMessage], tools: [ToolSpec]) -> JSONValue
    public static func collect(events: [JSONValue]) throws -> ChatResponse
    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse
}
```

Internal: `static func usesLite(_ m: String) -> Bool` and `func send(model: String, system: String, messages: [ChatMessage], tools: [ToolSpec]) async throws -> ChatResponse` (`ChatGPTPlan.swift:354`, `:460`).

## Behaviour

- `makeBody` maps [[ChatMessage]] parts to Responses API input items (`input_text`, `input_image`, `function_call`, `function_call_output`), sets `store: false`, `stream: true`, and wraps tools in a `namespace` tool named `pinpoint`. "Lite" models get low reasoning effort and low verbosity (`ChatGPTPlan.swift:356-399`).
- `collect` folds stream events into a [[ChatResponse]], de-duplicating calls by id and stripping the `pinpoint.` prefix; `response.failed` or `error` events throw (`ChatGPTPlan.swift:402-441`).
- `send` with an "auto" model asks [[ChatGPTAccount]] `autoModel` and retries up to 3 models when the plan rejects one with HTTP 404, or HTTP 400 mentioning the model (`ChatGPTPlan.swift:443-458`).
- The HTTP path reads SSE `data:` lines; 404 and 429 errors get friendlier messages (`ChatGPTPlan.swift:460-489`).

## Called by

- [[ProviderSettings]] `makeClient(apiKey:)` for `.chatgpt` (`Sources/PinpointCore/LLM.swift:278`).
- [[AppSettings]] `makeClient(fast:)` with `ModelPicker.autoFast` (`Sources/Pinpoint/AppSettings.swift:83`).

## Related

[[LLMClient]] · [[ChatGPTAccount]] · [[ChatGPTOAuth]] · [[ModelPicker]] · [[ProviderSettings]] · [[ProviderKind]]

## Tested by

- `ChatGPTPlanTests` body shape and stream collection (`Tests/PinpointCoreTests/ProviderTests.swift:41-78`).

## Sources

- `Sources/PinpointCore/ChatGPTPlan.swift` (lines 346-490)
