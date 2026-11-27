---
type: entity
title: "ModelPicker"
entity: ModelPicker
kind: enum
entity_type: module
target: PinpointCore
path: "Sources/PinpointCore/ChatGPTPlan.swift"
lines: "498-541"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[ChatGPTAccount]]"
  - "[[ChatGPTPlanClient]]"
  - "[[ProviderSettings]]"
  - "[[ProviderKind]]"
  - "[[AppSettings]]"
  - "[[SettingsView]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:107 ModelPickerTests"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[ChatGPTPlanClient]]"
  - "[[ChatGPTAccount]]"
---

# ModelPicker

## Purpose

Picks the best model for Pinpoint from a provider's list: it needs vision, reliable tool use and reasonable speed (`Sources/PinpointCore/ChatGPTPlan.swift:502`).

## API

```swift
public enum ModelPicker {
    public static let auto = "auto"
    public static let autoFast = "auto-fast"

    public static func isAuto(_ m: String) -> Bool
    public static func score(_ id: String, fast: Bool = false) -> Double?
    public static func ranked(_ ids: [String], fast: Bool = false) -> [String]
    public static func best(_ ids: [String], fast: Bool = false) -> String?
}
```

## Behaviour

- `isAuto`: empty, `auto`, `auto-fast` or anything starting with `auto ` (`ChatGPTPlan.swift:507-510`).
- `score`: nil for unsuitable ids (audio, realtime, embeddings, image, search and similar); otherwise a number from the `gpt-N.M` version or `oN` series, adjusted down for pro, nano, codex, preview and dated snapshots, and for mini up in fast mode or down otherwise (`ChatGPTPlan.swift:513-536`).
- `ranked` sorts by score, then shorter id; `best` is the first (`ChatGPTPlan.swift:538-544`).

## Called by

- [[ChatGPTAccount]] `autoModel` (`ChatGPTPlan.swift:566`); [[ChatGPTPlanClient]] `send` (`:450-452`).
- [[ProviderSettings]] `makeClient` (`Sources/PinpointCore/LLM.swift:278`); [[ProviderKind]] `.chatgpt` default model is `"auto"` (`LLM.swift:253`).
- [[AppSettings]] init migration and `makeClient(fast:)` (`Sources/Pinpoint/AppSettings.swift:44`, `:85-87`).
- [[SettingsView]] model picker and auto-pick labels (`Sources/Pinpoint/SettingsView.swift:122-144`).

## Related

[[ChatGPTPlanClient]] · [[ChatGPTAccount]] · [[ProviderSettings]] · [[SettingsView]]

## Tested by

- `ModelPickerTests` (`Tests/PinpointCoreTests/ProviderTests.swift:107-131`).

## Sources

- `Sources/PinpointCore/ChatGPTPlan.swift` (lines 498-541)
