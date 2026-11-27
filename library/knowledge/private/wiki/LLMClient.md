---
type: entity
title: "LLMClient"
entity: LLMClient
kind: protocol
entity_type: exported-symbol
symbol_kind: protocol
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "51-73"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ChatMessage]]"
  - "[[ToolSpec]]"
  - "[[ChatResponse]]"
  - "[[LLMError]]"
used_by:
  - "[[EditAgent]]"
  - "[[Assistants]]"
  - "[[ProviderSettings]]"
  - "[[AppSettings]]"
  - "[[EditorModel]]"
  - "[[LibraryModel]]"
  - "[[SettingsView]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:172 ScriptedClient"
tags:
  - entity
  - pinpointcore
  - llm
  - provider
related:
  - "[[AnthropicClient]]"
  - "[[OpenAICompatibleClient]]"
  - "[[ChatGPTPlanClient]]"
  - "[[CodexClient]]"
---

# LLMClient

## Purpose

The provider-neutral interface every **provider** client implements. The **agent** and the **assistant** only see this protocol.

## API

```swift
public protocol LLMClient: Sendable {
    func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse
}

extension LLMClient {
    public func ask(system: String, prompt: String, images: [Data] = [], maxTokens: Int = 2048) async throws -> String
}
```

Grouped internal helper: `func perform(_ req: URLRequest, session: URLSession) async throws -> Data` (`Sources/PinpointCore/LLM.swift:62-73`) runs a request and throws [[LLMError]] `"HTTP <code>: <message>"` on non-2xx, pulling the message from common JSON error shapes.

## Behaviour

- `ask` is a one-shot question with optional images that returns plain text (`LLM.swift:56-59`).

## Implementations

- [[AnthropicClient]] (`LLM.swift:77`), [[OpenAICompatibleClient]] (`LLM.swift:139`), [[ChatGPTPlanClient]] (`ChatGPTPlan.swift:357`), [[CodexClient]] (`CodexClient.swift:6`).

## Called by

- [[EditAgent]] `send` (`Agent.swift:239`); [[Assistants]] `ask` (`Assistants.swift:12`, `:20`, `:41`).
- Created by [[ProviderSettings]] `makeClient(apiKey:)` and [[AppSettings]] `makeClient(fast:)`; obtained by [[EditorModel]], [[LibraryModel]], [[AppDelegate]] and [[SettingsView]] (`Test connection` uses `ask`, `Sources/Pinpoint/SettingsView.swift:207`).

## Related

[[ChatMessage]] · [[ToolSpec]] · [[ChatResponse]] · [[LLMError]] · [[ProviderSettings]] · [[EditAgent]] · [[Assistants]]

## Tested by

- `ScriptedClient` test double drives `AgentLoopTests` (`Tests/PinpointCoreTests/CoreTests.swift:172-200`).

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 51-73)
