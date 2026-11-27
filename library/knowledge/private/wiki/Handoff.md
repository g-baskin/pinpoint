---
type: entity
title: "Handoff"
entity: Handoff
kind: enum
entity_type: module
target: PinpointCore
path: "Sources/PinpointCore/Handoff.swift"
lines: "4-67"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Annotation]]"
  - "[[Analysis]]"
  - "[[CaptureMeta]]"
  - "[[Renderer]]"
used_by:
  - "[[EditorModel]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:175 HandoffTests"
tags:
  - entity
  - pinpointcore
  - handoff
related:
  - "[[EditorModel]]"
  - "[[Renderer]]"
  - "[[Annotation]]"
---

# Handoff

## Purpose

The **handoff**: turns a capture and its noted markup into text a coding agent or a teammate can act on (`Sources/PinpointCore/Handoff.swift:4`).

## API

```swift
public enum Handoff {
    public static func describe(_ a: Annotation, ocr: [OCRLine]) -> String
    public static func nearbyText(_ target: CGRect, ocr: [OCRLine]) -> [String]
    public static func markdown(meta: CaptureMeta, annotations: [Annotation], imagePath: String?, ocr: [OCRLine]) -> String
}
```

## Behaviour

- `describe` gives a plain-English phrase per [[AnnotationKind]] ("Arrow pointing at", "Pin at", "Outlined area around" and so on), the item's `target` position and size, nearby on-screen text, and the label for callouts and text (`Handoff.swift:7-28`).
- `nearbyText` returns up to three OCR lines inside a box, or the single closest line within about 120 px of a point (`Handoff.swift:31-43`).
- `markdown` writes a `## Screenshot:` header with image path, size and app, then the numbered notes in badge order (numbers from `Renderer.noteNumbers`), then other markup except blur and redact, then the capture summary if any (`Handoff.swift:45-66`).

## Called by

- [[EditorModel]] `handoffMarkdown`, `copyHandoff()` and `exportHandoff()` (`Sources/Pinpoint/EditorModel.swift:92-126`), reached from the Handoff menu in [[MainView]] and the "Copy for AI" button in [[PropertiesPanel]].

## Related

[[EditorModel]] · [[Renderer]] · [[Annotation]] · [[Analysis]] · [[CaptureMeta]]

## Tested by

- `HandoffTests` (`Tests/PinpointCoreTests/ProviderTests.swift:175-206`).

## Sources

- `Sources/PinpointCore/Handoff.swift` (lines 4-67)
