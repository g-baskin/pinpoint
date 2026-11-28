---
type: entity
title: "JSONValue"
entity: JSONValue
kind: enum
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/JSONValue.swift"
lines: "3-125"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[ToolSpec]]"
  - "[[ChatMessage]]"
  - "[[AgentToolbox]]"
  - "[[AnthropicClient]]"
  - "[[OpenAICompatibleClient]]"
  - "[[ChatGPTPlanClient]]"
  - "[[ChatGPTOAuth]]"
  - "[[CodexClient]]"
  - "[[Assistants]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:24 JSONTests"
tags:
  - entity
  - pinpointcore
  - llm
related:
  - "[[ToolSpec]]"
  - "[[LLMClient]]"
---

# JSONValue (and extractJSONObject)

## Purpose

A small, Sendable JSON tree used for LLM tool schemas, tool inputs and API payloads (`Sources/PinpointCore/JSONValue.swift:3`).

## API

```swift
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws
    public func encode(to encoder: Encoder) throws
    public subscript(key: String) -> JSONValue?
    public subscript(index: Int) -> JSONValue?
    public var stringValue: String?
    public var doubleValue: Double?
    public var boolValue: Bool?
    public var arrayValue: [JSONValue]?
    public static func parse(_ data: Data) throws -> JSONValue
    public static func parse(_ string: String) throws -> JSONValue
    public func data() -> Data
    public var jsonString: String
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral

public func extractJSONObject(from text: String) -> JSONValue?
```

## Behaviour

- Whole numbers below 1e15 encode as integers (`JSONValue.swift:28-29`).
- Accessors are lenient: `stringValue` formats numbers and bools, `doubleValue` parses strings, `boolValue` accepts "true", "yes", "1" (`JSONValue.swift:45-67`).
- `data()` uses sorted keys without escaping slashes and falls back to `null` (`JSONValue.swift:77-81`).
- `extractJSONObject` pulls the first balanced `{...}` object out of free text, since models often wrap JSON in prose or fences (`JSONValue.swift:98-125`).

## Called by

- [[ToolSpec]] `parameters` and every tool schema in [[AgentToolbox]].
- Request and response encoding in [[AnthropicClient]], [[OpenAICompatibleClient]], [[ChatGPTPlanClient]], [[ChatGPTOAuth]] and [[CodexClient]].
- `extractJSONObject`: [[Assistants]] `nameAndTags` and [[CodexClient]] `parse` (`Assistants.swift:30`, `CodexClient.swift:76`).

## Related

[[ToolSpec]] · [[ChatMessage]] · [[LLMClient]] · [[AgentToolbox]]

## Tested by

- `JSONTests` round trip and prose extraction (`Tests/PinpointCoreTests/CoreTests.swift:24-51`).

## Sources

- `Sources/PinpointCore/JSONValue.swift` (lines 3-125)
