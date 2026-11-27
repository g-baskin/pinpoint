---
type: entity
title: "SensitiveKind"
entity: SensitiveKind
kind: enum
entity_type: exported-symbol
symbol_kind: enum
target: PinpointCore
path: "Sources/PinpointCore/Sensitive.swift"
lines: "4-20"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[SensitiveRegion]]"
  - "[[SensitiveDetector]]"
  - "[[Analyzer]]"
  - "[[AgentToolbox]]"
  - "[[EditorModel]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:6 SensitiveTests"
tags:
  - entity
  - pinpointcore
  - auto-redact
related:
  - "[[SensitiveDetector]]"
  - "[[SensitiveRegion]]"
---

# SensitiveKind

## Purpose

The categories **auto-redact** detects: emails, API keys and secrets, account and ad IDs, phone and card numbers, IP addresses, SSNs, the user's custom words, and faces.

## API

```swift
public enum SensitiveKind: String, Codable, CaseIterable, Sendable {
    case email, apiKey, accountID, phone, creditCard, ipAddress, ssn, custom, face

    public var label: String
}
```

`label` is the on-screen name, for example "API key / secret", "Account / ad ID", "Your redact word" (`Sources/PinpointCore/Sensitive.swift:7-19`).

## Called by

- [[SensitiveDetector]] tags each match; [[SensitiveRegion]] holds it; [[Analyzer]] adds `.face` (`Sources/PinpointCore/Analyzer.swift:50`).
- [[AgentToolbox]] lists all raw values in the `redact_sensitive` schema and filters by kind (`Sources/PinpointCore/Agent.swift:65`, `:195`).
- [[EditorModel]] `autoRedact(style:)` and [[EditAgent]] summarise counts by `label` (`Sources/Pinpoint/EditorModel.swift:292`, `Agent.swift:217`).

## Related

[[SensitiveDetector]] · [[SensitiveRegion]] · [[Analyzer]] · [[AgentToolbox]]

## Sources

- `Sources/PinpointCore/Sensitive.swift` (lines 4-20)
