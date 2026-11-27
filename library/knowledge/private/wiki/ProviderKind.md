---
type: entity
title: "ProviderKind"
entity: ProviderKind
kind: enum
entity_type: config-key
target: PinpointCore
path: "Sources/PinpointCore/LLM.swift"
lines: "220-264"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[ProviderSettings]]"
  - "[[AppSettings]]"
  - "[[SettingsView]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:80 OtherProviderTests"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[ProviderSettings]]"
  - "[[AppSettings]]"
---

# ProviderKind

## Purpose

The **provider** catalogue: the AI service in use (ChatGPT sign-in, Codex CLI, Anthropic, OpenAI, OpenRouter, Gemini, Ollama, custom), with display names, default base URLs and default models.

## API

```swift
public enum ProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case chatgpt, codex, anthropic, openai, openrouter, gemini, ollama, custom
    public var id: String
    public var displayName: String
    public var defaultBaseURL: String
    public var defaultModel: String
    public var needsKey: Bool
}
```

## Behaviour

- `.codex` stores the path to the codex executable in the base URL field; empty means auto-detect (`Sources/PinpointCore/LLM.swift:241`).
- `.chatgpt` defaults to model `"auto"` so [[ModelPicker]] chooses (`LLM.swift:253`); `.codex` defaults to empty, meaning the user's Codex default (`:254`).
- `needsKey` is true for anthropic, openai, openrouter and gemini (`LLM.swift:263`).
- The raw value is the [[Keychain]] account name for that provider's API key (`Sources/Pinpoint/AppSettings.swift:65`).

## Called by

- [[ProviderSettings]] (`LLM.swift:267-293`); [[AppSettings]] `provider`, `providers`, `apiKey(_:)` (`Sources/Pinpoint/AppSettings.swift:10-11`, `:36-41`, `:65-66`); [[SettingsView]] provider picker (`Sources/Pinpoint/SettingsView.swift:22-24`).

## Related

[[ProviderSettings]] · [[AppSettings]] · [[SettingsView]] · [[Keychain]] · [[ModelPicker]]

## Tested by

- `OtherProviderTests` (`Tests/PinpointCoreTests/ProviderTests.swift:80-104`).

## Sources

- `Sources/PinpointCore/LLM.swift` (lines 220-264)
