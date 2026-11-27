---
type: entity
title: "RGBA"
entity: RGBA
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/Annotation.swift"
lines: "5-33"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[Annotation]]"
  - "[[AgentToolbox]]"
  - "[[Renderer]]"
  - "[[EditorModel]]"
  - "[[QuickStyle]]"
  - "[[PropertiesPanel]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - markup
related:
  - "[[Annotation]]"
  - "[[QuickStyle]]"
---

# RGBA

## Purpose

The colour value used by every markup item: sRGB components plus named presets and a parser for colour names or hex strings.

## API

```swift
public struct RGBA: Codable, Equatable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1)

    public static let red = RGBA(0.93, 0.18, 0.20)
    public static let orange = RGBA(1.0, 0.55, 0.0)
    public static let yellow = RGBA(1.0, 0.86, 0.0)
    public static let green = RGBA(0.16, 0.72, 0.30)
    public static let blue = RGBA(0.10, 0.48, 1.0)
    public static let purple = RGBA(0.58, 0.30, 0.90)
    public static let black = RGBA(0, 0, 0)
    public static let white = RGBA(1, 1, 1)
    public static let presets: [RGBA] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]

    public var cgColor: CGColor
    public var nsColor: NSColor
    public func with(alpha: Double) -> RGBA
    public static func parse(_ s: String?) -> RGBA?
}
```

Named colours: `Sources/PinpointCore/Annotation.swift:9-16`; `presets`: `:17`.

## Behaviour

- `parse` accepts the eight names or a 6-digit hex with or without `#`; anything else returns nil (`Annotation.swift:24-32`).

## Called by

- [[AgentToolbox]] parses the model's `color` argument (`Sources/PinpointCore/Agent.swift:132`, `:151`).
- [[Renderer]] uses `cgColor`, `nsColor`, `with(alpha:)` and its own luminance helper (`Sources/PinpointCore/Renderer.swift:80-81`, `:144`, `:202`).
- [[EditorModel]] keeps the current `color` and `fillColor` (`Sources/Pinpoint/EditorModel.swift:55`, `:58`).
- [[QuickStyle]] presets and [[PropertiesPanel]] `ColorRow` (`Sources/Pinpoint/QuickStyles.swift:6-7`, `Sources/Pinpoint/MainWindow.swift:331-348`).

## Related

[[Annotation]] · [[Renderer]] · [[QuickStyle]] · [[PropertiesPanel]]

## Sources

- `Sources/PinpointCore/Annotation.swift` (lines 5-33)
