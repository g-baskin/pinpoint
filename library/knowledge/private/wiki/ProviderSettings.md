---
type: entity
title: "ProviderSettings"
entity: ProviderSettings
kind: struct
entity_type: config-key
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "266-313"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ProviderKind]]"
  - "[[LLMClient]]"
  - "[[ChatGPTAccount]]"
  - "[[ChatGPTPlanClient]]"
  - "[[ModelPicker]]"
  - "[[CodexClient]]"
  - "[[AnthropicClient]]"
  - "[[OpenAICompatibleClient]]"
  - "[[LLMError]]"
used_by:
  - "[[AppSettings]]"
  - "[[SettingsView]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:91 OtherProviderTests.testOpenRouterNeedsKey"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[ProviderKind]]"
  - "[[AppSettings]]"
  - "[[LLMClient]]"
---

# ProviderSettings

## Purpose

Per-provider settings (kind, model, base URL) and the factory that turns them into an [[LLMClient]].

## API

```swift
public struct ProviderSettings: Codable, Equatable, Sendable {
    public var kind: ProviderKind
    public var model: String
    public var baseURL: String
    public init(kind: ProviderKind, model: String? = nil, baseURL: String? = nil)

    public func makeClient(apiKey: String) throws -> LLMClient
    public func listModels(apiKey: String, session: URLSession = .shared) async throws -> [String]
}
```

## Behaviour

- `init` fills model and base URL from the [[ProviderKind]] defaults (`Sources/PinpointCore/LLM.swift:270-272`).
- `makeClient`: `.chatgpt` requires a signed-in [[ChatGPTAccount]] and returns a [[ChatGPTPlanClient]]; `.codex` requires `CodexClient.locate` and returns a [[CodexClient]]; others validate URL, model and key, then return [[AnthropicClient]] or [[OpenAICompatibleClient]]. Each failure throws an [[LLMError]] telling the user what to fix (`LLM.swift:274-293`).
- `listModels`: the ChatGPT plan list, Codex suggestions, or `GET /v1/models` (Anthropic) or `/models`, stripping a `models/` prefix (`LLM.swift:295-312`).

## Called by

- [[AppSettings]] stores one per kind in `providers` and calls `current.makeClient(apiKey:)` (`Sources/Pinpoint/AppSettings.swift:11`, `:63`, `:85`).
- [[SettingsView]] edits it through a binding and calls `listModels` for "Fetch models" (`Sources/Pinpoint/SettingsView.swift:15-17`, `:192`).

## Related

[[ProviderKind]] · [[AppSettings]] · [[SettingsView]] · [[LLMClient]] · [[ChatGPTPlanClient]] · [[CodexClient]]

## Tested by

- `OtherProviderTests.testOpenRouterNeedsKey` (`Tests/PinpointCoreTests/ProviderTests.swift:91`).

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 266-313)
