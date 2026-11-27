---
type: entity
title: "LLMError"
entity: LLMError
kind: struct
entity_type: class
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "45-49"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[LLMClient]]"
  - "[[ProviderSettings]]"
  - "[[ChatGPTOAuth]]"
  - "[[ChatGPTAccount]]"
  - "[[LoopbackListener]]"
  - "[[ChatGPTPlanClient]]"
  - "[[CodexClient]]"
  - "[[Assistants]]"
  - "[[AppSettings]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - llm
related:
  - "[[LLMClient]]"
---

# LLMError

## Purpose

The single user-facing error type for AI and sign-in failures. Its message is shown directly in the editor log and in Settings.

## API

```swift
public struct LLMError: LocalizedError, Sendable {
    public var message: String
    public init(_ m: String)
    public var errorDescription: String?
}
```

## Behaviour

- `errorDescription` returns `message` (`Sources/PinpointCore/LLM.swift:48`).
- [[ChatGPTPlanClient]] inspects `message` for "HTTP 404" or "HTTP 400" to decide whether to try another model (`ChatGPTPlan.swift:453`).

## Called by

- Thrown across PinpointCore: `perform` in [[LLMClient]], [[ProviderSettings]], [[ChatGPTOAuth]], [[ChatGPTAccount]], [[LoopbackListener]], [[ChatGPTPlanClient]], [[CodexClient]], [[Assistants]]; and by [[AppSettings]] `makeClient(fast:)` (`Sources/Pinpoint/AppSettings.swift:82`).

## Related

[[LLMClient]] · [[ProviderSettings]] · [[ChatGPTAccount]]

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 45-49)
