---
type: entity
title: "Annotation"
entity: Annotation
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/Annotation.swift"
lines: "43-156"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[AnnotationKind]]"
  - "[[RGBA]]"
used_by:
  - "[[CaptureMeta]]"
  - "[[AgentState]]"
  - "[[AgentToolbox]]"
  - "[[Analyzer]]"
  - "[[Renderer]]"
  - "[[Handoff]]"
  - "[[EditorModel]]"
  - "[[CanvasView]]"
  - "[[QuickStyle]]"
  - "[[NotePromptView]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:76 RenderTests.testHitTesting"
  - "Tests/PinpointCoreTests/ProviderTests.swift:196 HandoffTests.testNotesRenderAndDecodeOldMeta"
tags:
  - entity
  - pinpointcore
  - markup
related:
  - "[[AnnotationKind]]"
  - "[[Renderer]]"
  - "[[CaptureMeta]]"
---

# Annotation

## Purpose

One **markup item** on a capture. Coordinates are image pixels with a top-left origin (`Sources/PinpointCore/Annotation.swift:43`). An item can carry a **note** (spoken or typed context shown as a numbered badge and exported in **handoffs**, `:57-58`).

## API

```swift
public struct Annotation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: AnnotationKind
    public var start: CGPoint
    public var end: CGPoint
    public var color: RGBA
    public var lineWidth: Double
    public var text: String?
    public var fontSize: Double
    public var fillColor: RGBA?
    public var shadow: Bool?
    public var note: String?

    public init(id: UUID = UUID(), kind: AnnotationKind, start: CGPoint, end: CGPoint, color: RGBA = .red,
                lineWidth: Double = 4, text: String? = nil, fontSize: Double = 28, fillColor: RGBA? = nil, shadow: Bool? = nil,
                note: String? = nil)

    public var hasNote: Bool
    public var badgeAnchor: CGPoint
    public var target: CGRect
    public var hasShadow: Bool
    public var rect: CGRect
    public var font: NSFont
    public var textSize: CGSize
    public var stepRadius: CGFloat
    public var bounds: CGRect
    public var arrowHeadLength: CGFloat
    public func hitTest(_ p: CGPoint, tolerance: CGFloat) -> Bool
    public func offset(by d: CGSize) -> Annotation
    public static func defaultLineWidth(for size: CGSize) -> Double
    public static func defaultFontSize(for size: CGSize) -> Double
}
```

Grouped helper (internal, file scope): `func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat` (`Annotation.swift:150-156`), used by `hitTest` for arrows and lines.

## Behaviour

- `fillColor` nil means no fill; `shadow` nil means the default (on), read through `hasShadow` (`Annotation.swift:53-56`, `:89`).
- `hasNote` is true for `.note` items or any item with a non-blank `note` (`:68`).
- `target` is the point or area the item is "about": the arrow head, the pin, or the box (`:81-87`); [[Handoff]] uses it.
- `bounds` includes stroke, text size, step radius, arrow head and the callout tail, for hit testing and selection (`:106-125`).
- Default line width and font size scale with the long edge so markup looks the same on 1x and Retina captures (`:145-147`).

## Called by

- Stored in [[CaptureMeta]] `annotations` and [[AgentState]] `annotations` (`Sources/PinpointCore/Library.swift:17`, `Sources/PinpointCore/Agent.swift:6`).
- Created by [[AgentToolbox]], [[Analyzer]] `redactions`, [[EditorModel]] `newAnnotation(kind:at:)` and [[QuickStyle]] previews.
- Drawn by [[Renderer]]; hit-tested and moved by [[CanvasView]] (`Sources/Pinpoint/CanvasView.swift:90`, `:150`).
- Described in text by [[Handoff]]; its note edited through [[NotePromptView]].

## Related

[[AnnotationKind]] · [[RGBA]] · [[Renderer]] · [[CaptureMeta]] · [[Handoff]] · [[CanvasView]]

## Tested by

- `RenderTests.testHitTesting` (`Tests/PinpointCoreTests/CoreTests.swift:76`).
- `HandoffTests.testNotesRenderAndDecodeOldMeta` (`Tests/PinpointCoreTests/ProviderTests.swift:196`).

## Sources

- `Sources/PinpointCore/Annotation.swift` (lines 43-156)
