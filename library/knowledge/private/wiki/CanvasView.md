---
type: entity
title: "CanvasView"
entity: CanvasView
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/CanvasView.swift"
lines: "6-289, 325-369"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[EditorModel]]"
  - "[[Renderer]]"
  - "[[Annotation]]"
  - "[[Tool]]"
  - "[[NotePromptView]]"
  - "[[AppSettings]]"
  - "[[ZoomController]]"
used_by:
  - "[[EditorModel]]"
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
  - view
related:
  - "[[EditorModel]]"
  - "[[Renderer]]"
  - "[[ZoomController]]"
---

# CanvasView (and CenteringClipView, CanvasScrollView)

## Purpose

The drawing surface: shows the capture and handles all mouse and keyboard editing (`Sources/Pinpoint/CanvasView.swift:6`). Its coordinate space is image pixels; the enclosing scroll view does the zooming (`:23-24`).

## API (internal)

```swift
final class CanvasView: NSView {
    let model: EditorModel
    init(model: EditorModel)
    override func draw(_ dirtyRect: NSRect)
    override func mouseDown(with event: NSEvent)
    override func mouseDragged(with event: NSEvent)
    override func mouseUp(with event: NSEvent)
    func showNotePrompt(for id: UUID, autoListen: Bool)
    override func keyDown(with event: NSEvent)
    @objc func undo(_ sender: Any?)
    @objc func redo(_ sender: Any?)
    @objc func copy(_ sender: Any?)
    @objc func delete(_ sender: Any?)
    @objc override func selectAll(_ sender: Any?)
}

final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect
}

struct CanvasScrollView: NSViewRepresentable {
    let model: EditorModel
    let zoom: ZoomController
    func makeNSView(context: Context) -> NSScrollView
    func updateNSView(_ sv: NSScrollView, context: Context)
    func makeCoordinator() -> Coordinator
}
```

## Behaviour

- `draw` paints the image and all markup through [[Renderer]], substituting the in-progress drag preview, dims outside the crop and outlines the selection with end handles (`CanvasView.swift:44-83`).
- `mouseDown` gives the selected item's handles priority, then acts per [[Tool]]: crop drag, select and move (double-click edits text or opens the note prompt), text prompt, step placement, note pin with an immediate note prompt, or starting a new shape (`CanvasView.swift:93-139`).
- Shift-drag constrains boxes to squares and lines to 45 degrees (`CanvasView.swift:147`, `:226-232`).
- `mouseUp` commits: tiny arrows and shapes are dropped; a click with the callout tool makes a default-sized bubble; arrows and shapes may open "Add more context?" (`CanvasView.swift:163-198`).
- `showNotePrompt` opens [[NotePromptView]] in a popover anchored at the arrow head or the item's bounds (`CanvasView.swift:200-218`).
- Keys: Delete removes, Esc deselects, single letters switch tool, arrows nudge by 1 px or 10 px with Shift (`CanvasView.swift:254-270`).
- `CenteringClipView` keeps a small image centred; `CanvasScrollView` builds the scroll view (magnification 0.03 to 8), wires [[ZoomController]] and refits on resize (`CanvasView.swift:281-289`, `:325-369`).

## Called by

- `EditorBody` in [[MainView]] via `CanvasScrollView(model:zoom:)` (`Sources/Pinpoint/MainWindow.swift:186`); [[EditorModel]] holds a weak `canvas` and calls `showNotePrompt` from `promptNote` (`EditorModel.swift:70`, `:88`).

## Related

[[EditorModel]] · [[Renderer]] · [[Tool]] · [[NotePromptView]] · [[ZoomController]] · [[MainView]]

## Sources

- `Sources/Pinpoint/CanvasView.swift` (lines 6-289, 325-369)
