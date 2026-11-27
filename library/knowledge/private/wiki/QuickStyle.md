---
type: entity
title: "QuickStyle"
entity: QuickStyle
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/QuickStyles.swift"
lines: "4-69"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[RGBA]]"
  - "[[AnnotationKind]]"
  - "[[Annotation]]"
  - "[[Renderer]]"
used_by:
  - "[[PropertiesPanel]]"
  - "[[EditorModel]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
  - style
related:
  - "[[PropertiesPanel]]"
  - "[[EditorModel]]"
  - "[[Renderer]]"
---

# QuickStyle

## Purpose

A one-click style preset for a **markup item** (colour, fill, line-width scale, shadow, font scale), shown as a rendered thumbnail in the Properties panel.

## API (internal)

```swift
struct QuickStyle: Hashable, Identifiable {
    var color: RGBA
    var fill: RGBA? = nil
    var widthScale: Double = 1
    var shadow: Bool = true
    var fontScale: Double? = nil
    var id: Int { hashValue }

    static func presets(for kind: AnnotationKind) -> [QuickStyle]

    @MainActor
    func preview(for kind: AnnotationKind, size: CGSize = CGSize(width: 64, height: 44)) -> NSImage
}
```

## Behaviour

- `presets(for:)` returns a per-kind list: colours plus thicker and thinner variants for arrow and line; outlines plus translucent fills for rectangle and ellipse; filled and borderless callouts; larger and smaller text and steps; highlighter and note colours; and no presets for blur and redact (`QuickStyles.swift:13-45`).
- `preview(for:size:)` draws a sample [[Annotation]] of that kind (an arrow corner to corner, "Aa" text, step "1", a "Hi" callout) with [[Renderer]] `draw` on a light background, at line width `3 * widthScale` and font size `13 * (fontScale ?? 1)` (`QuickStyles.swift:48-68`).

## Called by

- [[PropertiesPanel]] lists `QuickStyle.presets(for:)` for the current kind (`Sources/Pinpoint/MainWindow.swift:239`).
- [[EditorModel]] `apply(_:)` sets the current style from a preset (`Sources/Pinpoint/EditorModel.swift:192`).

## Related

[[PropertiesPanel]] · [[EditorModel]] · [[Renderer]] · [[RGBA]] · [[AnnotationKind]]

## Sources

- `Sources/Pinpoint/QuickStyles.swift` (lines 4-69)
