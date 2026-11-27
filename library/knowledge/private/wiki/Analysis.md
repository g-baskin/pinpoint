---
type: entity
title: "Analysis"
entity: Analysis
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/Analyzer.swift"
lines: "5-16"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[SensitiveRegion]]"
used_by:
  - "[[Analyzer]]"
  - "[[AgentToolbox]]"
  - "[[EditAgent]]"
  - "[[EditorModel]]"
  - "[[AppDelegate]]"
  - "[[Handoff]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:83 AnalyzerTests"
tags:
  - entity
  - pinpointcore
  - analysis
related:
  - "[[Analyzer]]"
  - "[[SensitiveRegion]]"
---

# Analysis (and OCRLine)

## Purpose

The result of on-device **analysis** of a capture: OCR lines plus sensitive regions (including faces). `OCRLine` is one recognised line with its box in image pixels, top-left origin (`Sources/PinpointCore/Analyzer.swift:5-9`).

## API

```swift
public struct OCRLine: Codable, Equatable, Sendable {
    public var text: String
    public var rect: CGRect   // image pixels, top-left origin
    public init(text: String, rect: CGRect)
}

public struct Analysis: Sendable {
    public var lines: [OCRLine]
    public var sensitive: [SensitiveRegion]
    public var fullText: String
    public init(lines: [OCRLine], sensitive: [SensitiveRegion])
}
```

`fullText` joins line texts with newlines (`Analyzer.swift:14`).

## Called by

- Produced by `Analyzer.analyze` (`Sources/PinpointCore/Analyzer.swift:20`, `:53`).
- [[EditorModel]] stores it as `analysis` and uses `lines` for handoffs and `sensitive` for auto-redact (`Sources/Pinpoint/EditorModel.swift:93`, `:127`, `:286-293`).
- [[AppDelegate]] background post-processing uses `fullText` for the capture's OCR text (`Sources/Pinpoint/AppDelegate.swift:203-204`).
- [[AgentToolbox]] and [[EditAgent]] read `lines` and `sensitive` (`Sources/PinpointCore/Agent.swift:145`, `:196`, `:215-217`).
- [[Handoff]] takes `[OCRLine]` to describe what markup points at (`Sources/PinpointCore/Handoff.swift:7`, `:31`).

## Related

[[Analyzer]] · [[SensitiveRegion]] · [[Handoff]] · [[EditorModel]]

## Sources

- `Sources/PinpointCore/Analyzer.swift` (lines 5-16)
