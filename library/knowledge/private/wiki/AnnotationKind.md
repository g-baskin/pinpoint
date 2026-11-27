---
type: entity
title: "AnnotationKind"
entity: AnnotationKind
kind: enum
entity_type: exported-symbol
symbol_kind: enum
target: PinpointCore
path: "Sources/PinpointCore/Annotation.swift"
lines: "35-41"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[Annotation]]"
  - "[[Tool]]"
  - "[[AgentToolbox]]"
  - "[[Analyzer]]"
  - "[[EditorModel]]"
  - "[[QuickStyle]]"
  - "[[PropertiesPanel]]"
  - "[[Handoff]]"
  - "[[Renderer]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:70 RenderTests.testAllKindsRenderWithoutCrashing"
tags:
  - entity
  - pinpointcore
  - markup
related:
  - "[[Annotation]]"
  - "[[Tool]]"
---

# AnnotationKind

## Purpose

The kind of a **markup item**: arrow, line, rectangle, ellipse, text, callout, highlight, blur, redact, step or note. The editor's [[Tool]] maps to it by raw value.

## API

```swift
public enum AnnotationKind: String, Codable, CaseIterable, Sendable {
    case arrow, line, rectangle, ellipse, text, callout, highlight, blur, redact, step, note

    public var isBox: Bool
    public var supportsFill: Bool
}
```

## Behaviour

- `isBox`: geometry is a box with start and end as opposite corners: rectangle, ellipse, callout, highlight, blur, redact (`Sources/PinpointCore/Annotation.swift:38-39`).
- `supportsFill`: rectangle, ellipse, callout (`Annotation.swift:40`).

## Called by

- [[Tool]] `kind` (`Sources/Pinpoint/EditorModel.swift:34`); [[EditorModel]] `newAnnotation(kind:at:)` and `autoRedact(style:)` (`EditorModel.swift:217`, `:286`).
- [[AgentToolbox]] parses the model's `kind` string (`Sources/PinpointCore/Agent.swift:126`).
- [[Analyzer]] `redactions(..., style:)` (`Sources/PinpointCore/Analyzer.swift:71`).
- [[QuickStyle]] `presets(for:)` and `preview(for:size:)`; [[PropertiesPanel]] picks controls per kind (`Sources/Pinpoint/QuickStyles.swift:13`, `:49`, `Sources/Pinpoint/MainWindow.swift:228`).
- [[Renderer]] and [[Handoff]] switch on it (`Sources/PinpointCore/Renderer.swift:84`, `Sources/PinpointCore/Handoff.swift:9`).

## Related

[[Annotation]] · [[Tool]] · [[Renderer]] · [[QuickStyle]]

## Sources

- `Sources/PinpointCore/Annotation.swift` (lines 35-41)
