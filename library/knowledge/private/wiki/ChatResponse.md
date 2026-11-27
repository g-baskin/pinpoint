---
type: entity
title: "ChatResponse"
entity: ChatResponse
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "34-43"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ChatMessage]]"
  - "[[ToolSpec]]"
used_by:
  - "[[LLMClient]]"
  - "[[EditAgent]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:203 ProviderWireTests"
tags:
  - entity
  - pinpointcore
  - llm
related:
  - "[[LLMClient]]"
  - "[[ToolSpec]]"
---

# ChatResponse

## Purpose

A model reply in provider-neutral form: the reply parts plus an optional stop reason.

## API

```swift
public struct ChatResponse: Sendable {
    public var parts: [ChatPart]
    public var stopReason: String?
    public var text: String
    public var toolCalls: [ToolCall]
}
```

## Behaviour

- `text` joins all text parts with newlines; `toolCalls` maps tool-use parts to [[ToolSpec]] `ToolCall`s (`Sources/PinpointCore/LLM.swift:37-42`).

## Called by

- Returned by every [[LLMClient]]: `AnthropicClient.parse`, `OpenAICompatibleClient.parse`, `ChatGPTPlanClient.collect`, `CodexClient.parse`.
- [[EditAgent]] reads `toolCalls` and `text` each step (`Agent.swift:240-242`).

## Related

[[LLMClient]] · [[ChatMessage]] · [[ToolSpec]] · [[EditAgent]]

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 34-43)
