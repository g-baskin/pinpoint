---
type: entity
title: "Renderer"
entity: Renderer
kind: enum
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Renderer.swift"
lines: "6-286"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Annotation]]"
  - "[[AnnotationKind]]"
  - "[[RGBA]]"
used_by:
  - "[[EditorModel]]"
  - "[[CanvasView]]"
  - "[[CaptureService]]"
  - "[[Handoff]]"
  - "[[QuickStyle]]"
  - "[[PropertiesPanel]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:53 RenderTests"
  - "Tests/PinpointCoreTests/ProviderTests.swift:208 NotesPanelTests"
tags:
  - entity
  - pinpointcore
  - markup
  - rendering
related:
  - "[[Annotation]]"
  - "[[CanvasView]]"
  - "[[EditorModel]]"
---

# Renderer

## Purpose

Draws markup items. All drawing assumes a flipped context (origin top-left) in image-pixel units, so the same code paints the live editor canvas and the exported image (`Sources/PinpointCore/Renderer.swift:6-7`).

## API

```swift
public enum Renderer {
    public static func drawImage(_ image: CGImage, in rect: CGRect, ctx: CGContext)
    public static func pixelated(_ image: CGImage) -> CGImage?
    public static func draw(_ annotations: [Annotation], in ctx: CGContext, imageSize: CGSize, pixelated: CGImage?)
    public static func noteNumbers(_ annotations: [Annotation]) -> [UUID: Int]
    public static func draw(_ a: Annotation, in ctx: CGContext, imageSize: CGSize, pixelated: CGImage?)
    public static func flatten(base: CGImage, annotations: [Annotation], crop: CGRect?, pixelated: CGImage? = nil) -> CGImage?
}

extension Renderer {
    public static func withNotesPanel(_ image: CGImage, annotations: [Annotation]) -> CGImage
}
```

Internal helpers: `drawBadge`, `setShadow`, `luminance`, `drawText`, `withNSContext` and a shared `CIContext` (`Renderer.swift:9`, `:59-71`, `:198-216`).

## Behaviour

- `drawImage` draws a CGImage upright inside a flipped context (`Renderer.swift:12-18`).
- `pixelated` makes a fully pixelated copy once per capture; **blur** items reveal it through a clip (`Renderer.swift:21-30`, `:150-157`).
- `draw(_ annotations:...)` draws each item, gives `.note` pins their number, then draws numbered badges for other items that carry a note, kept inside the image (`Renderer.swift:32-49`).
- `noteNumbers` numbers 1, 2, 3 in drawing order for every item with a note (`Renderer.swift:52-57`).
- `draw(_ a:...)` handles every [[AnnotationKind]]: arrow head geometry, rounded rectangles, callout bubble with tail and wrapped text, multiply-blended highlight, black **redact** fill, note pin, **step** circle and stroked text (`Renderer.swift:73-196`).
- `flatten` bakes markup and optional crop into a new image (`Renderer.swift:219-234`).
- `withNotesPanel` adds a "Notes" panel under the image listing each numbered note; returns the image unchanged when there are none (`Renderer.swift:238-285`).

## Called by

- [[EditorModel]] `init` (`pixelated`), `flattened()`, `copyImage`, `exportHandoff` (`Sources/Pinpoint/EditorModel.swift:119`, `:145`, `:225`, `:231`, `:243`).
- [[CanvasView]] `draw(_:)` (`Sources/Pinpoint/CanvasView.swift:50`, `:56`).
- [[CaptureService]] `captureAllScreens()` uses `drawImage` (`Sources/Pinpoint/CaptureService.swift:121`).
- [[Handoff]] `markdown` and `NotesList` in [[PropertiesPanel]] use `noteNumbers` (`Handoff.swift:46`, `Sources/Pinpoint/MainWindow.swift:450`).
- [[QuickStyle]] `preview(for:size:)` (`Sources/Pinpoint/QuickStyles.swift:65`).

## Related

[[Annotation]] · [[AnnotationKind]] · [[RGBA]] · [[CanvasView]] · [[EditorModel]] · [[Handoff]]

## Tested by

- `RenderTests` flatten, redaction, crop, all kinds (`Tests/PinpointCoreTests/CoreTests.swift:53-81`); `NotesPanelTests` (`Tests/PinpointCoreTests/ProviderTests.swift:208`).

## Sources

- `Sources/PinpointCore/Renderer.swift` (lines 6-286)
