---
type: entity
title: "ZoomController"
entity: ZoomController
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/CanvasView.swift"
lines: "291-323"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[EditorModel]]"
  - "[[CanvasView]]"
  - "[[TrayView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
related:
  - "[[CanvasView]]"
  - "[[TrayView]]"
---

# ZoomController

## Purpose

Zoom commands from the UI, applied to the canvas scroll view (`Sources/Pinpoint/CanvasView.swift:291`).

## API (internal)

```swift
@MainActor
final class ZoomController: ObservableObject {
    weak var scrollView: NSScrollView?
    @Published var percent: Int = 100
    @Published var fitMode = true
    func fit()
    func actualSize()
    func zoom(by f: CGFloat)
    func update()
}
```

## Behaviour

- `fit()` fits the image with a 40-point margin, never above 100% magnification, and turns fit mode on (`CanvasView.swift:298-307`).
- `actualSize()` shows one image pixel per screen pixel (`CanvasView.swift:309-313`); `zoom(by:)` clamps to the scroll view's limits (`:314-318`).
- `percent` accounts for the window's backing scale (`CanvasView.swift:319-322`).

## Called by

- Owned by [[EditorModel]] as `zoom` (`Sources/Pinpoint/EditorModel.swift:68`); wired and refit by `CanvasScrollView` in [[CanvasView]] (`CanvasView.swift:346-365`); driven by `ZoomControls` in [[TrayView]] (`Sources/Pinpoint/MainWindow.swift:404-417`).

## Related

[[CanvasView]] · [[TrayView]] · [[EditorModel]]

## Sources

- `Sources/Pinpoint/CanvasView.swift` (lines 291-323)
