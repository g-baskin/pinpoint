---
type: entity
title: "ChatMessage"
entity: ChatMessage
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "3-21"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[JSONValue]]"
used_by:
  - "[[LLMClient]]"
  - "[[EditAgent]]"
  - "[[AnthropicClient]]"
  - "[[OpenAICompatibleClient]]"
  - "[[ChatGPTPlanClient]]"
  - "[[CodexClient]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:203 ProviderWireTests"
tags:
  - entity
  - pinpointcore
  - llm
related:
  - "[[LLMClient]]"
  - "[[ChatResponse]]"
---

# ChatMessage (and ChatRole, ChatPart)

## Purpose

Provider-neutral chat types: a message is a role plus parts (text, PNG image, tool use, tool result). Each client translates these to its own wire format.

## API

```swift
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
    public init(role: ChatRole, parts: [ChatPart])
    public static func user(_ text: String, images: [Data] = []) -> ChatMessage
}
```

## Behaviour

- `user(_:images:)` puts the images before the text (`Sources/PinpointCore/LLM.swift:18-20`).

## Called by

- [[EditAgent]] builds the conversation (`Agent.swift:236`, `:240`, `:249`); `LLMClient.ask` uses `.user` (`LLM.swift:58`).
- Encoded by [[AnthropicClient]], [[OpenAICompatibleClient]], [[ChatGPTPlanClient]] and [[CodexClient]].

## Related

[[LLMClient]] · [[ChatResponse]] · [[ToolSpec]] · [[JSONValue]]

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 3-21)
