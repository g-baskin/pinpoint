---
type: entity
title: "ToolSpec"
entity: ToolSpec
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "23-32"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[JSONValue]]"
used_by:
  - "[[AgentToolbox]]"
  - "[[LLMClient]]"
  - "[[ChatResponse]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - llm
related:
  - "[[AgentToolbox]]"
  - "[[ChatResponse]]"
---

# ToolSpec (and ToolCall)

## Purpose

`ToolSpec` describes one tool offered to the model (name, description, JSON-schema parameters). `ToolCall` is one call the model made, extracted from a [[ChatResponse]].

## API

```swift
public struct ToolSpec: Sendable {
    public var name: String
    public var description: String
    public var parameters: JSONValue
    public init(name: String, description: String, parameters: JSONValue)
}

public struct ToolCall: Equatable, Sendable { public var id: String; public var name: String; public var input: JSONValue }
```

## Called by

- [[AgentToolbox]] `tools` defines the seven agent tools (`Sources/PinpointCore/Agent.swift:44-80`).
- Every [[LLMClient]] `send` takes `[ToolSpec]`; `ChatResponse.toolCalls` returns `[ToolCall]` (`Sources/PinpointCore/LLM.swift:40-42`), which [[EditAgent]] executes.

## Related

[[AgentToolbox]] · [[ChatResponse]] · [[LLMClient]] · [[JSONValue]] · [[EditAgent]]

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 23-32)
