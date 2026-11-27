---
type: entity
title: "Tool"
entity: Tool
kind: enum
entity_type: exported-symbol
symbol_kind: enum
target: Pinpoint
path: "Sources/Pinpoint/EditorModel.swift"
lines: "6-35"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[AnnotationKind]]"
used_by:
  - "[[EditorModel]]"
  - "[[CanvasView]]"
  - "[[MainView]]"
  - "[[PropertiesPanel]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
related:
  - "[[AnnotationKind]]"
  - "[[CanvasView]]"
---

# Tool

## Purpose

An editor **tool** the user picks: each markup kind, plus select and crop.

## API (internal)

```swift
enum Tool: String, CaseIterable, Identifiable {
    case select, arrow, line, rectangle, ellipse, text, callout, highlight, step, note, blur, redact, crop
    var id: String
    var symbol: String
    var key: Character
    var title: String
    var kind: AnnotationKind?
}
```

## Behaviour

- `symbol` is the SF Symbol name; `key` is the single-letter shortcut: V select, A arrow, L line, R rectangle, E ellipse, T text, O callout, H highlight, N step, M note, B blur, X redact, C crop (`Sources/Pinpoint/EditorModel.swift:9-32`).
- `title` shows "Voice note" for `.note`, else the capitalised name, with the key (`EditorModel.swift:33`).
- `kind` maps by raw value to [[AnnotationKind]]; select and crop map to nil (`EditorModel.swift:34`).

## Called by

- [[EditorModel]] `tool` (`EditorModel.swift:54`); [[CanvasView]] `mouseDown` and `keyDown` (`Sources/Pinpoint/CanvasView.swift:105`, `:258-259`); `ToolStrip` in [[MainView]] (`Sources/Pinpoint/MainWindow.swift:122`); [[PropertiesPanel]] (`MainWindow.swift:231`).

## Related

[[AnnotationKind]] · [[EditorModel]] · [[CanvasView]] · [[MainView]]

## Sources

- `Sources/Pinpoint/EditorModel.swift` (lines 6-35)
