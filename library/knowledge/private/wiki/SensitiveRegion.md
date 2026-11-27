---
type: entity
title: "SensitiveRegion"
entity: SensitiveRegion
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/Sensitive.swift"
lines: "22-27"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[SensitiveKind]]"
used_by:
  - "[[Analysis]]"
  - "[[Analyzer]]"
  - "[[AgentToolbox]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:116 AgentToolboxTests"
tags:
  - entity
  - pinpointcore
  - auto-redact
related:
  - "[[Analysis]]"
  - "[[SensitiveKind]]"
---

# SensitiveRegion

## Purpose

One detected sensitive area on a capture: its [[SensitiveKind]], the matched text (nil for faces) and its box in image pixels, top-left origin (`Sources/PinpointCore/Sensitive.swift:22-26`).

## API

```swift
public struct SensitiveRegion: Codable, Equatable, Sendable {
    public var kind: SensitiveKind
    public var text: String?
    public var rect: CGRect   // image pixels, top-left origin
    public init(kind: SensitiveKind, text: String?, rect: CGRect)
}
```

## Called by

- Created by [[Analyzer]] `analyze` (`Sources/PinpointCore/Analyzer.swift:45`, `:50`); stored in [[Analysis]] `sensitive`.
- Turned into blur or redact markup by `Analyzer.redactions` (`Analyzer.swift:71-80`), which [[AgentToolbox]] and [[EditorModel]] call.

## Related

[[Analysis]] · [[SensitiveKind]] · [[Analyzer]] · [[SensitiveDetector]]

## Sources

- `Sources/PinpointCore/Sensitive.swift` (lines 22-27)
